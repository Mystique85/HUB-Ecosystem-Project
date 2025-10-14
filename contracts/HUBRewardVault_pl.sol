// SPDX-License-Identifier: MIT
// Wersja robocza dla społeczności HUB Ecosystem
// Autor: Mysticpol
// Kontrakt: HUBRewardVault
// Cel: Strukturalna podstawa logiki sejfu dystrybucji nagród (wersja UUPS, możliwa do aktualizacji)
//
// Uwagi:
// - To jest *szkic strukturalny*, przeznaczony do dyskusji ze społecznością.
// - Złożone mechanizmy ekonomiczne (auto-throttle, runway, wycena oparta o oracle, nagroda dla keepera itd.)
//   zostały celowo oznaczone jako TODO, aby społeczność mogła zaproponować implementacje.
// - Przed jakimkolwiek wdrożeniem produkcyjnym: należy przeprowadzić testy jednostkowe, testy forków i audyt formalny.
//
// Zastosowanie:
// - Przeznaczony do wdrożenia jako kontrakt możliwy do aktualizacji (UUPS).
// - ADMIN_CONTRACT w HUBToken powinien być adresem multisig (np. Gnosis Safe).
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
       ROLE (UPRAWNIENIA)
       ------------------------------------------------------------------------ */
    bytes32 public constant ROLE_ENGINE   = keccak256("ROLE_ENGINE");    // LiquidityEngine: może doładowywać sejf (po przesłaniu HUB)
    bytes32 public constant ROLE_ROUTER   = keccak256("ROLE_ROUTER");    // ActivityRouter: opcjonalne (jeśli sejf rejestruje akcje bezpośrednio)
    bytes32 public constant ROLE_KEEPER   = keccak256("ROLE_KEEPER");    // Keeper: może uruchamiać uwolnienie epoki (opcjonalnie)
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");  // Kontroler aktualizacji (UUPS)

    /* ------------------------------------------------------------------------
       TOKEN + ODBIORCA
       ------------------------------------------------------------------------ */
    IERC20Upgradeable public hubToken;             // Token HUB (ERC20)
    address public rewardDistributor;              // Adres odbiorcy budżetów epok (zarządza mikrodystrybucją)

    /* ------------------------------------------------------------------------
       PARAMETRY EPOKI (KONFIGURACJA)
       ------------------------------------------------------------------------ */
    uint256 public startTime;                       // Znacznik czasu rozpoczęcia pierwszej epoki (ustalany w initializerze)
    uint256 public currentEpoch;                    // Liczba dotychczas uwolnionych epok (0..)
    uint256 public lastReleaseTimestamp;            // Znacznik czasu ostatniego uwolnienia

    // Stałe (zmieniaj tylko, jeśli celowo redefiniujesz logikę)
    uint256 public constant EPOCH_DURATION = 365 days;
    uint256 public constant EPOCH_BUDGET   = 1_000_000_000 * 1e18; // 1 000 000 000 HUB (18 miejsc po przecinku)
    uint256 public constant MAX_EPOCHS     = 8;

    /* ------------------------------------------------------------------------
       KSIĘGOWOŚĆ / BEZPIECZEŃSTWO
       ------------------------------------------------------------------------ */
    // Zmienna recordedHubBalance przechowuje zarejestrowany stan HUB, aby upewnić się,
    // że każde doładowanie faktycznie odpowiada przesłanym tokenom.
    // LiquidityEngine powinien najpierw przelać HUB do tego kontraktu, a następnie wywołać replenish(amount).
    uint256 public recordedHubBalance;

    /* ------------------------------------------------------------------------
       WYDARZENIA
       ------------------------------------------------------------------------ */
    event EpochReleased(uint256 indexed epochId, uint256 amount, uint256 timestamp);
    event Replenished(address indexed engine, uint256 amount, uint256 timestamp);
    event RewardDistributorUpdated(address indexed oldDistributor, address indexed newDistributor);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    /* ------------------------------------------------------------------------
       REZERWA PAMIĘCI (dla przyszłych aktualizacji)
       ------------------------------------------------------------------------ */
    uint256[45] private __gap;

    /* ------------------------------------------------------------------------
       INITIALIZER
       ------------------------------------------------------------------------ */

    /**
     * @notice Inicjalizuje kontrakt HUBRewardVault (inicjalizator UUPS)
     * @param hubTokenAddr Adres tokena HUB (ERC20)
     * @param initialDistributor Adres odbierający budżety epok (RewardDistributor)
     * @param admin Adres, który otrzyma role DEFAULT_ADMIN_ROLE i ROLE_UPGRADER (np. Gnosis Safe)
     * @param _startTime opcjonalny czas startu; jeśli zero, używany jest bieżący blok.timestamp
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

        // Nadanie ról administracyjnych przekazanemu adminowi (multisig).
        // Multisig powinien później nadawać/usuwać role poprzez timelock.
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROLE_UPGRADER, admin);
        _grantRole(ROLE_KEEPER, admin);
    }

    /* ------------------------------------------------------------------------
       MODYFIKATORY
       ------------------------------------------------------------------------ */

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Ograniczony: admin");
        _;
    }

    modifier onlyKeeperOrAdmin() {
        require(hasRole(ROLE_KEEPER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Ograniczony: keeper/admin");
        _;
    }

    /* ------------------------------------------------------------------------
       RDZEŃ: UWOLNIENIE EPOKI
       ------------------------------------------------------------------------ */

    /**
     * @notice Uwolnij EPOCH_BUDGET tokenów HUB do rewardDistributor.
     * @dev Powinno być wywołane po pełnym upływie jednej epoki. Dostępne dla keepera lub admina.
     *
     * Uwagi dotyczące działania:
     * - Funkcja jest celowo prosta: przesyła EPOCH_BUDGET do rewardDistributor.
     * - Bardziej złożone przepływy (nagroda dla keepera, zwrot gazu, timelock on-chain)
     *   mogą być zaproponowane w osobnych PR-ach.
     */
    function triggerEpochRelease() external whenNotPaused nonReentrant onlyKeeperOrAdmin {
        require(currentEpoch < MAX_EPOCHS, "Wszystkie epoki zakończone");

        // sprawdzenie, czy pełna epoka minęła od ostatniego uwolnienia
        uint256 eligibleTime = startTime + (currentEpoch * EPOCH_DURATION);
        require(block.timestamp >= eligibleTime + EPOCH_DURATION, "Epoka jeszcze trwa");

        uint256 vaultBal = hubToken.balanceOf(address(this));
        require(vaultBal >= EPOCH_BUDGET, "Za mało HUB w sejfie");

        // aktualizacja księgowa przed transferem
        currentEpoch += 1;
        lastReleaseTimestamp = block.timestamp;

        // aktualizacja zarejestrowanego salda
        recordedHubBalance = vaultBal - EPOCH_BUDGET;

        // wysyłka budżetu epoki do dystrybutora
        // UWAGA: rewardDistributor musi mieć własne zabezpieczenia po swojej stronie
        bool ok = hubToken.transfer(rewardDistributor, EPOCH_BUDGET);
        require(ok, "Transfer HUB nieudany");

        emit EpochReleased(currentEpoch, EPOCH_BUDGET, block.timestamp);
    }

    /* ------------------------------------------------------------------------
       DOŁADOWANIE (REPLENISH)
       ------------------------------------------------------------------------ */

    /**
     * @notice Wywoływane przez LiquidityEngine po przesłaniu HUB do tego kontraktu.
     * LiquidityEngine MUSI przesłać HUB do tego kontraktu PRZED wywołaniem replenish(amount).
     * Funkcja sprawdza, czy saldo rzeczywiście wzrosło o oczekiwaną ilość i aktualizuje stan.
     */
    function replenish(uint256 amount) external whenNotPaused nonReentrant {
        require(hasRole(ROLE_ENGINE, msg.sender), "Ograniczony: engine");
        require(amount > 0, "Kwota zero");

        uint256 actualBal = hubToken.balanceOf(address(this));
        // podstawowa kontrola: czy tokeny rzeczywiście zostały przesłane
        require(actualBal >= recordedHubBalance + amount, "Nieprawidłowy transfer HUB");

        recordedHubBalance = actualBal;

        emit Replenished(msg.sender, amount, block.timestamp);
    }

    /* ------------------------------------------------------------------------
       FUNKCJE ADMINISTRACYJNE
       ------------------------------------------------------------------------ */

    /**
     * @notice Aktualizacja adresu rewardDistributor (tylko admin).
     * @dev W środowisku produkcyjnym zmiana powinna być wykonywana przez multisig / timelock.
     */
    function updateRewardDistributor(address newDistributor) external onlyAdmin {
        require(newDistributor != address(0), "Adres zero");
        address old = rewardDistributor;
        rewardDistributor = newDistributor;
        emit RewardDistributorUpdated(old, newDistributor);
    }

    /**
     * @notice Wstrzymanie kontraktu (tylko admin).
     */
    function pause() external onlyAdmin {
        _pause();
        emit Paused(msg.sender);
    }

    /**
     * @notice Wznowienie działania kontraktu (tylko admin).
     */
    function unpause() external onlyAdmin {
        _unpause();
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Awaryjny wypłat tokenów HUB (tylko admin).
     * @dev Funkcja bezpieczeństwa. W produkcji powinna być chroniona przez timelock + multisig.
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyAdmin nonReentrant {
        require(to != address(0), "Adres zero");
        uint256 bal = hubToken.balanceOf(address(this));
        require(amount <= bal, "Kwota przekracza saldo");

        recordedHubBalance = bal - amount;

        bool ok = hubToken.transfer(to, amount);
        require(ok, "Transfer nieudany");
        emit EmergencyWithdraw(to, amount);
    }

    /* ------------------------------------------------------------------------
       WIDOKI / POMOCNICZE
       ------------------------------------------------------------------------ */

    /**
     * @notice Zwraca znacznik czasu następnego możliwego uwolnienia epoki.
     */
    function nextEligibleReleaseTime() external view returns (uint256) {
        return startTime + (currentEpoch * EPOCH_DURATION) + EPOCH_DURATION;
    }

    /**
     * @notice Zwraca liczbę pozostałych epok (0, gdy wszystkie zakończone).
     */
    function epochsRemaining() external view returns (uint256) {
        if (currentEpoch >= MAX_EPOCHS) return 0;
        return MAX_EPOCHS - currentEpoch;
    }

    /* ------------------------------------------------------------------------
       AUTORYZACJA AKTUALIZACJI (UUPS)
       ------------------------------------------------------------------------ */

    /**
     * @dev Autoryzacja aktualizacji UUPS — tylko ROLE_UPGRADER może zatwierdzić upgrade.
     * W produkcji ROLE_UPGRADER powinien być przypisany kontraktowi Timelock (lub Gnosis Safe).
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ROLE_UPGRADER) {}

    /* ------------------------------------------------------------------------
       ODZYSKIWANIE TOKENÓW / ETH (ADMIN)
       ------------------------------------------------------------------------ */

    /**
     * @notice Odzyskaj omyłkowo przesłane tokeny ERC20 (z wyjątkiem HUB).
     */
    function recoverERC20(address tokenAddress, address to, uint256 amount) external onlyAdmin nonReentrant {
        require(tokenAddress != address(hubToken), "Nie można odzyskać HUB");
        require(to != address(0), "Adres zero");
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        uint256 bal = token.balanceOf(address(this));
        require(amount <= bal, "Przekracza saldo");
        bool ok = token.transfer(to, amount);
        require(ok, "Transfer nieudany");
    }

    /**
     * @notice Pozwala kontraktowi przyjmować ETH i umożliwia adminowi jego wypłatę (opcjonalne).
     */
    receive() external payable {}

    function recoverETH(address payable to, uint256 amount) external onlyAdmin nonReentrant {
        require(to != address(0), "Adres zero");
        require(amount <= address(this).balance, "Za mało ETH");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Transfer ETH nieudany");
    }

    /* ------------------------------------------------------------------------
       ZADANIA SPOŁECZNOŚCIOWE / TODO
       ------------------------------------------------------------------------ */

    // TODO: Dodać mechanizm nagrody dla keepera (anyone-can-call z małą nagrodą ETH/HUB)
    // TODO: Zintegrować przykład użycia TimelockController w komentarzach/skryptach
    // TODO: Dodać eventy dla zmian ról (lub polegać na eventach AccessControl)
    // TODO: Rozważyć funkcję pozwalającą rozszerzyć MAX_EPOCHS (decyzja DAO)
    // TODO: Dodać kontrolę dostępu do funkcji tylko-do-odczytu, jeśli potrzebne
    // TODO: Zaproponować i zaimplementować zewnętrzne hooki monitorujące (emit eventów dla obserwatorów off-chain)
}
