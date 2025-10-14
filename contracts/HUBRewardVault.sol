// SPDX-License-Identifier: MIT
// Draft version for HUB Ecosystem community discussion
// Author: Mysticpol
// Contract: HUBRewardVault
// Purpose: Structural base for reward distribution vault logic (upgradeable UUPS draft)
//
// Notes:
// - This is a *structural draft* meant to be reviewed by the community.
// - Complex economics (auto-throttle, runway, oracle-based pricing, keeper reward, etc.)
//   are intentionally left as TODOs so contributors can propose implementations.
// - Before any production deployment: run unit tests, fork tests and formal audit.
//
// Usage:
// - Intended to be deployed as an upgradeable contract (UUPS).
// - ADMIN_CONTRACT in your HUBToken is expected to be the multisig (Gnosis Safe).
//
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract HUBRewardVault is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    /* ------------------------------------------------------------------------
       ROLES
       ------------------------------------------------------------------------ */
    bytes32 public constant ROLE_ENGINE   = keccak256("ROLE_ENGINE");    // LiquidityEngine: allowed to replenish vault (after transferring HUB)
    bytes32 public constant ROLE_ROUTER   = keccak256("ROLE_ROUTER");    // ActivityRouter: optional (if vault records actions directly)
    bytes32 public constant ROLE_KEEPER   = keccak256("ROLE_KEEPER");    // Keeper: trigger epoch release (optional)
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");  // Upgrade controller for UUPS

    /* ------------------------------------------------------------------------
       TOKEN + RECEIVER
       ------------------------------------------------------------------------ */
    IERC20Upgradeable public hubToken;             // HUB token (ERC20)
    address public rewardDistributor;              // Address that receives epoch budget and handles micro-distribution

    /* ------------------------------------------------------------------------
       EPOCH PARAMETERS (CONFIG)
       ------------------------------------------------------------------------ */
    uint256 public startTime;                       // timestamp of first epoch start (set in initializer)
    uint256 public currentEpoch;                    // number of releases already done (0..)
    uint256 public lastReleaseTimestamp;            // timestamp of last release

    // Constants (change here only if you intentionally redesign the concept)
    uint256 public constant EPOCH_DURATION = 365 days;
    uint256 public constant EPOCH_BUDGET   = 1_000_000_000 * 1e18; // 1,000,000,000 HUB, token decimals assumed 18
    uint256 public constant MAX_EPOCHS     = 8;

    /* ------------------------------------------------------------------------
       ACCOUNTING / SAFETY
       ------------------------------------------------------------------------ */
    // We keep a recordedHubBalance to assert replenish calls actually correspond to transferred tokens.
    // LiquidityEngine is expected to transfer HUB tokens to this contract first, then call replenish(amount).
    uint256 public recordedHubBalance;

    /* ------------------------------------------------------------------------
       EVENTS
       ------------------------------------------------------------------------ */
    event EpochReleased(uint256 indexed epochId, uint256 amount, uint256 timestamp);
    event Replenished(address indexed engine, uint256 amount, uint256 timestamp);
    event RewardDistributorUpdated(address indexed oldDistributor, address indexed newDistributor);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    /* ------------------------------------------------------------------------
       STORAGE GAP (for future upgrades)
       ------------------------------------------------------------------------ */
    uint256[45] private __gap;

    /* ------------------------------------------------------------------------
       INITIALIZER
       ------------------------------------------------------------------------ */

    /**
     * @notice Initialize the HUBRewardVault (upgradeable initializer)
     * @param hubTokenAddr Address of the HUB token (ERC20)
     * @param initialDistributor Address receiving epoch budgets (RewardDistributor)
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE and ROLE_UPGRADER (e.g. Gnosis Safe)
     * @param _startTime optional manual start timestamp; if zero, uses block.timestamp
     */
    function initialize(
        address hubTokenAddr,
        address initialDistributor,
        address admin,
        uint256 _startTime
    ) public initializer {
        require(hubTokenAddr != address(0), "HUB token zero");
        require(initialDistributor != address(0), "distributor zero");
        require(admin != address(0), "admin zero");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        hubToken = IERC20Upgradeable(hubTokenAddr);
        rewardDistributor = initialDistributor;

        startTime = _startTime == 0 ? block.timestamp : _startTime;
        lastReleaseTimestamp = startTime;
        currentEpoch = 0;

        recordedHubBalance = hubToken.balanceOf(address(this));

        // Grant admin roles to the given admin (multisig). Multisig should later grant/revoke roles via timelock.
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROLE_UPGRADER, admin);
        _grantRole(ROLE_KEEPER, admin);
    }

    /* ------------------------------------------------------------------------
       MODIFIERS
       ------------------------------------------------------------------------ */

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted: admin");
        _;
    }

    modifier onlyKeeperOrAdmin() {
        require(hasRole(ROLE_KEEPER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted: keeper/admin");
        _;
    }

    /* ------------------------------------------------------------------------
       CORE: EPOCH RELEASE
       ------------------------------------------------------------------------ */

    /**
     * @notice Release EPOCH_BUDGET HUB to rewardDistributor.
     * @dev Should be called after a full epoch elapsed. Can be restricted to keeper/admin as configured.
     *
     * Behaviour notes (community discussion):
     * - This function is intentionally simple: transfer EPOCH_BUDGET to rewardDistributor.
     * - More advanced flows (keeper reward, gas reimbursement, on-chain timelock check)
     *   can be proposed as separate PRs.
     */
    function triggerEpochRelease() external whenNotPaused nonReentrant onlyKeeperOrAdmin {
        require(currentEpoch < MAX_EPOCHS, "All epochs done");

        // require that a full epoch has passed since last release or since start
        uint256 eligibleTime = startTime + (currentEpoch * EPOCH_DURATION);
        require(block.timestamp >= eligibleTime + EPOCH_DURATION, "Epoch not completed");

        uint256 vaultBal = hubToken.balanceOf(address(this));
        require(vaultBal >= EPOCH_BUDGET, "Insufficient HUB in vault");

        // accounting update before transfer
        currentEpoch += 1;
        lastReleaseTimestamp = block.timestamp;

        // update recorded balance
        recordedHubBalance = vaultBal - EPOCH_BUDGET;

        // send EPOCH_BUDGET to distributor
        // NOTE: rewardDistributor MUST implement security checks on its side.
        bool ok = hubToken.transfer(rewardDistributor, EPOCH_BUDGET);
        require(ok, "HUB transfer failed");

        emit EpochReleased(currentEpoch, EPOCH_BUDGET, block.timestamp);
    }

    /* ------------------------------------------------------------------------
       REPLENISH HOOK
       ------------------------------------------------------------------------ */

    /**
     * @notice Called by LiquidityEngine after transferring HUB tokens to this contract.
     * LiquidityEngine MUST transfer HUB to this contract BEFORE calling replenish(amount).
     * This function validates the actual balance increased accordingly and updates recordedHubBalance.
     */
    function replenish(uint256 amount) external whenNotPaused nonReentrant {
        require(hasRole(ROLE_ENGINE, msg.sender), "Restricted: engine");
        require(amount > 0, "Zero amount");

        uint256 actualBal = hubToken.balanceOf(address(this));
        // basic sanity: ensure callers transferred tokens
        require(actualBal >= recordedHubBalance + amount, "Insufficient transferred HUB");

        recordedHubBalance = actualBal;

        emit Replenished(msg.sender, amount, block.timestamp);
    }

    /* ------------------------------------------------------------------------
       ADMIN FUNCTIONS
       ------------------------------------------------------------------------ */

    /**
     * @notice Update the reward distributor address (admin only).
     * @dev Use multisig / timelock to change this in production.
     */
    function updateRewardDistributor(address newDistributor) external onlyAdmin {
        require(newDistributor != address(0), "Zero address");
        address old = rewardDistributor;
        rewardDistributor = newDistributor;
        emit RewardDistributorUpdated(old, newDistributor);
    }

    /**
     * @notice Pause the contract (admin only).
     */
    function pause() external onlyAdmin {
        _pause();
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause the contract (admin only).
     */
    function unpause() external onlyAdmin {
        _unpause();
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Emergency withdraw of HUB tokens (admin only).
     * @dev Intended as a safety measure. In production, use timelock + multisig approvals.
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyAdmin nonReentrant {
        require(to != address(0), "Zero address");
        uint256 bal = hubToken.balanceOf(address(this));
        require(amount <= bal, "Amount exceeds balance");

        // update recorded balance
        recordedHubBalance = bal - amount;

        bool ok = hubToken.transfer(to, amount);
        require(ok, "Transfer failed");
        emit EmergencyWithdraw(to, amount);
    }

    /* ------------------------------------------------------------------------
       VIEW HELPERS
       ------------------------------------------------------------------------ */

    /**
     * @notice Get next eligible release timestamp.
     */
    function nextEligibleReleaseTime() external view returns (uint256) {
        // Next eligible = startTime + (currentEpoch * EPOCH_DURATION) + EPOCH_DURATION
        return startTime + (currentEpoch * EPOCH_DURATION) + EPOCH_DURATION;
    }

    /**
     * @notice How many epochs remain (0 when exhausted).
     */
    function epochsRemaining() external view returns (uint256) {
        if (currentEpoch >= MAX_EPOCHS) return 0;
        return MAX_EPOCHS - currentEpoch;
    }

    /* ------------------------------------------------------------------------
       UUPS UPGRADE AUTHORIZATION
       ------------------------------------------------------------------------ */

    /**
     * @dev UUPS upgrade authorization - only ROLE_UPGRADER can authorize upgrades.
     * In production, ROLE_UPGRADER should be the Timelock contract (or Gnosis Safe if you choose).
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ROLE_UPGRADER) {}

    /* ------------------------------------------------------------------------
       TOKEN / ETH RECOVERY (ADMIN)
       ------------------------------------------------------------------------ */

    /**
     * @notice Recover accidentally sent ERC20 tokens (except HUB).
     */
    function recoverERC20(address tokenAddress, address to, uint256 amount) external onlyAdmin nonReentrant {
        require(tokenAddress != address(hubToken), "Cannot recover HUB");
        require(to != address(0), "Zero address");
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        uint256 bal = token.balanceOf(address(this));
        require(amount <= bal, "Exceeds balance");
        bool ok = token.transfer(to, amount);
        require(ok, "Transfer failed");
    }

    /**
     * @notice Allow contract to receive ETH and let admin recover it (optional).
     */
    receive() external payable {}

    function recoverETH(address payable to, uint256 amount) external onlyAdmin nonReentrant {
        require(to != address(0), "Zero address");
        require(amount <= address(this).balance, "Insufficient ETH");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    /* ------------------------------------------------------------------------
       DEVELOPMENT / COMMUNITY TODOs (place for PR contributions)
       ------------------------------------------------------------------------ */

    // TODO: Add keeper reward mechanism (anyone-can-call trigger with small ETH/HUB reward).
    // TODO: Integrate TimelockController usage pattern example in comments/scripts.
    // TODO: Add events for role changes (or rely on AccessControl events).
    // TODO: Consider adding function to allow controlled extension of MAX_EPOCHS (DAO decision).
    // TODO: Add access control modifiers for read-only functions if needed.
    // TODO: Propose and implement off-chain monitoring hooks (emit events for external watchers).
}
