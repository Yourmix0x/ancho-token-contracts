// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import OpenZeppelin contracts
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AnchoToken is ERC20, ERC20Pausable, Ownable {
    // constants
    uint256 public constant MAX_SUPPLY = 777_777_777 * 10 ** 18;
    // tax configuration
    uint256 public constant MAX_TAX = 300; // 3% in basis points (100 = 1%)
    uint256 public taxRate = 200; // 2% in basis point
    uint256 public reflectionRate = 50; // 0.5% reflection rate in basis points

    // tax destination
    address public treasuryWallet;
    address public drawVault;

    // reflection mechanism
    uint256 private _reflectionTotal;
    uint256 private _totalSupply;
    mapping(address => uint256) private _reflectionBalances;
    mapping(address => bool) public excludedFromReflection;

    // events for transparency
    event TaxRateUpdated(uint256 newTaxRate);
    event TaxDistributed(uint256 treasuryAmount, uint256 drawVaultAmount);
    event ReflectionDistributed(uint256 reflectionAmount);
    event ReflectionRateUpdated(uint256 newReflectionRate);

    // governance addresses
    address public timelock;
    address public emergencyAdmin;

    // safety features
    bool public circuitBreakerActive;
    mapping(address => bool) public blacklisted;

    // governance events
    event CircuitBreakerActivated(address indexed by);
    event CircuitBreakerDeactivated(address indexed by);
    event AddressBlacklisted(address indexed account);
    event AddressUnblacklisted(address indexed account);

    constructor(
        address initialOwner,
        address _treasuryWallet,
        address _drawVault,
        address _emergencyAdmin
    ) ERC20("AnchoToken", "ANCHO") Ownable(initialOwner) {
        // set tax destinations
        treasuryWallet = _treasuryWallet;
        drawVault = _drawVault;
        emergencyAdmin = _emergencyAdmin;

        // initialize reflection mechanism
        _totalSupply = MAX_SUPPLY;
        _reflectionTotal = (~uint256(0) - (~uint256(0) % _totalSupply));

        // exclude system addresses from reflection to prevent issues
        excludedFromReflection[_treasuryWallet] = true;
        excludedFromReflection[_drawVault] = true;
        excludedFromReflection[address(this)] = true;

        // mint the entire supply to the owner
        _mint(initialOwner, MAX_SUPPLY);
        _reflectionBalances[initialOwner] = _reflectionTotal;
    }

    // override the _update function to apply tax and reflection on transfers
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        // safety checks
        require(!circuitBreakerActive, "Circuit breaker active");
        require(!blacklisted[from] && !blacklisted[to], "Address blacklisted");

        // no tax/reflection applied in these cases:
        // - minting (from is zero address)
        // - burning (to is zero address)
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        // calculate fees
        uint256 taxAmount = (value * taxRate) / 10000; // 2% tax
        uint256 reflectionAmount = (value * reflectionRate) / 10000; // 0.5% reflection
        uint256 totalFees = taxAmount + reflectionAmount;
        uint256 transferAmount = value - totalFees;

        // apply reflection to all holders (burns from total reflection supply)
        if (reflectionAmount > 0 && _reflectionTotal > 0) {
            _reflectionTotal -=
                (_reflectionTotal * reflectionAmount) /
                _totalSupply;
            emit ReflectionDistributed(reflectionAmount);
        }

        // transfer the amount minus fees to recipient
        super._update(from, to, transferAmount);

        // distribute tax - 1% to each destination
        if (taxAmount > 0) {
            uint256 halfTax = taxAmount / 2;
            super._update(from, treasuryWallet, halfTax);
            super._update(from, drawVault, taxAmount - halfTax);
            emit TaxDistributed(halfTax, taxAmount - halfTax);
        }
    }

    // function to update tax rate - adjustable up to 3%
    // Enhanced with timelock requirement
    function setTaxRate(uint256 newTaxRate) external {
        require(
            msg.sender == owner() || msg.sender == timelock,
            "Only owner or timelock"
        );
        require(newTaxRate <= MAX_TAX, "Tax rate too high");
        taxRate = newTaxRate;
        emit TaxRateUpdated(newTaxRate);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // governance functions

    /**
     * @notice set the timelock contract address
     * @dev only owner can set this, timelock will then control sensitive functions
     */
    function setTimelock(address _timelock) external onlyOwner {
        timelock = _timelock;
    }

    /**
     * @notice emergency circuit breaker function
     * @dev can be activated by owner or emergency admin in case of emergency
     * pauses all transfers and activates circuit breaker mode
     */
    function activateCircuitBreaker() external {
        require(
            msg.sender == owner() || msg.sender == emergencyAdmin,
            "Only owner or emergency admin"
        );
        circuitBreakerActive = true;
        _pause(); // Also pause all transfers
        emit CircuitBreakerActivated(msg.sender);
    }

    /**
     * @notice deactivate circuit breaker
     * @dev only owner can deactivate circuit breaker
     */
    function deactivateCircuitBreaker() external onlyOwner {
        circuitBreakerActive = false;
        _unpause();
        emit CircuitBreakerDeactivated(msg.sender);
    }

    /**
     * @notice blacklist an address to prevent transfers
     * @dev only owner can blacklist addresses - for MEV/bot protection
     * @param account the address to blacklist
     */
    function blacklistAddress(address account) external onlyOwner {
        blacklisted[account] = true;
        emit AddressBlacklisted(account);
    }

    /**
     * @notice remove an address from blacklist
     * @dev only owner can unblacklist addresses
     * @param account the address to remove from blacklist
     */
    function unblacklistAddress(address account) external onlyOwner {
        blacklisted[account] = false;
        emit AddressUnblacklisted(account);
    }

    // ===== REFLECTION FUNCTIONS =====

    /**
     * @notice set reflection rate (0.5% default)
     * @dev only owner or timelock can change this
     */
    function setReflectionRate(uint256 newReflectionRate) external {
        require(
            msg.sender == owner() || msg.sender == timelock,
            "Only owner or timelock"
        );
        require(newReflectionRate <= 100, "Max 1% reflection rate"); // Max 1%
        reflectionRate = newReflectionRate;
        emit ReflectionRateUpdated(newReflectionRate);
    }

    /**
     * @notice exclude an address from receiving reflections
     * @dev useful for exchanges, contracts that shouldn't earn reflections
     */
    function excludeFromReflection(address account) external onlyOwner {
        excludedFromReflection[account] = true;
    }

    /**
     * @notice include an address in reflections again
     */
    function includeInReflection(address account) external onlyOwner {
        excludedFromReflection[account] = false;
    }

    /**
     * @notice get reflection balance for testing/display purposes
     * @dev in a full implementation, you'd override balanceOf to show reflected balance
     */
    function getReflectionBalance(
        address account
    ) external view returns (uint256) {
        if (excludedFromReflection[account] || _totalSupply == 0) {
            return super.balanceOf(account);
        }
        return (_reflectionBalances[account] * _totalSupply) / _reflectionTotal;
    }

    /**
     * @notice get current reflection rate for UI display
     */
    function getCurrentReflectionRate() external view returns (uint256) {
        if (_totalSupply == 0 || _reflectionTotal == 0) return 0;
        return ((_reflectionTotal * 10000) / _totalSupply) - 10000; // rate of increase
    }
}
