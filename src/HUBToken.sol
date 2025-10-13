/*
)                               )   (        )  (                  *     
 ( /(           (            (   ( /(   )\ )  ( /(  )\ )  *   )      (  `    
 )\())    (   ( )\    (      )\  )\()) (()/(  )\())(()/(` )  /( (    )\))(   
((_)\     )\  )((_)   )\   (((_)((_)\   /(_))((_)\  /(_))( )(_)))\  ((_)()\  
 _((_) _ ((_)((_)_   ((_)  )\___  ((_) (_)) __ ((_)(_)) (_(_())((_) (_()((_) 
| || || | | | | _ )  | __|  / __|/ _ \ / __|\ \ / // __||_   _|| __||  \/  | 
| __ || |_| | | _ \  | _|  | (__| (_) |\__ \ \ V / \__ \  | |  | _| | |\/| | 
|_||_| \___/  |___/  |___|  \___|\___/ |___/  |_|  |___/  |_|  |___||_|  |_| 
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC677Receiver {
    function onTokenTransfer(address sender, uint256 value, bytes calldata data) external;
}

/// @title HUB Ecosystem Token (HUB)
/// @author Mysticpol
/// @notice The main token for the HUB Ecosystem with fixed supply, role-based control and transferAndCall support.
/// @dev Structured for clarity and maintainability; includes MAX_SUPPLY and initial mint limit validation.
contract HUBToken is ERC20Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Maximum number of tokens that can ever exist (10 billion HUB)
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18;

    address public immutable REWARD_VAULT;
    address public immutable LIQUIDITY_POOL;
    address public immutable ADMIN_CONTRACT;
    address public immutable DEPLOYER;
    address public immutable DEV2;

    event CallbackSucceeded(address indexed to, address indexed sender, uint256 value, bytes data);
    event CallbackFailed(address indexed to, address indexed sender, uint256 value, bytes data, string reason);

    /**
     * @notice Constructor initializes the HUB token ecosystem allocations and roles.
     * @param _rewardVault Address of the reward vault
     * @param _liquidityPool Address of the liquidity pool
     * @param _adminContract Address that receives admin and operator roles
     * @param _deployer Initial deployer allocation address
     * @param _dev2 Secondary developer allocation address
     */
    constructor(
        address _rewardVault,
        address _liquidityPool,
        address _adminContract,
        address _deployer,
        address _dev2
    ) ERC20("HUB Ecosystem", "HUB") {
        require(_rewardVault != address(0), "Reward vault cannot be zero");
        require(_liquidityPool != address(0), "Liquidity pool cannot be zero");
        require(_adminContract != address(0), "Admin contract cannot be zero");
        require(_deployer != address(0), "Deployer cannot be zero");
        require(_dev2 != address(0), "Dev2 cannot be zero");

        REWARD_VAULT = _rewardVault;
        LIQUIDITY_POOL = _liquidityPool;
        ADMIN_CONTRACT = _adminContract;
        DEPLOYER = _deployer;
        DEV2 = _dev2;

        _grantRole(DEFAULT_ADMIN_ROLE, _adminContract);
        _grantRole(OPERATOR_ROLE, _adminContract);

        uint256 factor = 10 ** decimals();

        uint256 deployerMint = 750_000_000 * factor;
        uint256 dev2Mint = 750_000_000 * factor;
        uint256 liquidityMint = 500_000_000 * factor;
        uint256 rewardsMint = 8_000_000_000 * factor;

        uint256 initialTotal = deployerMint + dev2Mint + liquidityMint + rewardsMint;
        require(initialTotal <= MAX_SUPPLY, "Initial mint exceeds MAX_SUPPLY");

        _mint(_deployer, deployerMint);
        _mint(_dev2, dev2Mint);
        _mint(_liquidityPool, liquidityMint);
        _mint(_rewardVault, rewardsMint);
    }

    /// @notice Pause all token transfers (operator only)
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    /// @notice Resume token transfers (operator only)
    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    /// @notice Mint new tokens within MAX_SUPPLY limit (operator only)
    /// @param to Address to receive new tokens
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyRole(OPERATOR_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting would exceed MAX_SUPPLY");
        _mint(to, amount);
    }

    /// @notice Burn tokens from caller's balance
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Transfer tokens and call receiver if contract supports IERC677Receiver
    function transferAndCall(address to, uint256 value, bytes calldata data)
        external
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(msg.sender, to, value);

        if (_isContract(to)) {
            try IERC677Receiver(to).onTokenTransfer(msg.sender, value, data) {
                emit CallbackSucceeded(to, msg.sender, value, data);
            } catch Error(string memory reason) {
                emit CallbackFailed(to, msg.sender, value, data, reason);
            } catch {
                emit CallbackFailed(to, msg.sender, value, data, "callback-failed");
            }
        }

        return true;
    }

    /// @dev Overridden to integrate pausable extension
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Pausable)
    {
        super._update(from, to, value);
    }

    /// @dev Internal utility to check if address is a contract
    function _isContract(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }
}

/*
.----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
| | ____    ____ | || |  ____  ____  | || |    _______   | || |  _________   | || |     _____    | || |     ______   | || |   ______     | || |     ____     | || |   _____      | |
| ||_   \  /   _|| || | |_  _||_ _| | || |   /  ___  |  | || | |  _   _  |  | || |    |_   _|   | || |   .' ___  |  | || |  |_   __ \   | || |   .'    `.   | || |  |_   _|     | |
| |  |   \/   |  | || |   \ \  / /   | || |  |  (__ \_|  | || | |_/ | | \_|  | || |      | |     | || |  / .'   \_|  | || |    | |__) |  | || |  | |    | |  | || |    | |       | |
| |  | |\  /| |  | || |    \ \/ /    | || |   '.___`-.   | || |     | |      | || |      | |     | || |  | |         | || |    |  ___/   | || |  | |    | |  | || |    | |   _   | |
| | _| |_\/_| |_ | || |    _|  |_    | || |  |`\____) |  | || |    _| |_     | || |     _| |_    | || |  \ `.___.'\  | || |   _| |_      | || |  \  `--'  /  | || |   _| |__/ |  | |
| ||_____||_____|| || |   |______|   | || |  |_______.'  | || |   |_____|    | || |    |_____|   | || |   `._____.'  | || |  |_____|     | || |   `.____.'   | || |  |________|  | |
| |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------' 
*/

/*
    )                               )   (        )  (                  *     
 ( /(           (            (   ( /(   )\ )  ( /(  )\ )  *   )      (  `    
 )\())    (   ( )\    (      )\  )\()) (()/(  )\())(()/(` )  /( (    )\))(   
((_)\     )\  )((_)   )\   (((_)((_)\   /(_))((_)\  /(_))( )(_)))\  ((_)()\  
 _((_) _ ((_)((_)_   ((_)  )\___  ((_) (_)) __ ((_)(_)) (_(_())((_) (_()((_) 
| || || | | | | _ )  | __|((/ __|/ _ \ / __|\ \ / // __||_   _|| __||  \/  | 
| __ || |_| | | _ \  | _|  | (__| (_) |\__ \ \ V / \__ \  | |  | _| | |\/| | 
|_||_| \___/  |___/  |___|  \___|\___/ |___/  |_|  |___/  |_|  |___||_|  |_| 
*/
