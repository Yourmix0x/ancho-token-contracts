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

    // tax destination
    address public treasuryWallet;
    address public drawVault;

    // events for transparency
    event TaxRateUpdated(uint256 newTaxRate);
    event TaxDistributed(uint256 treasuryAmount, uint256 drawVaultAmount);

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

        // mint the entire supply to the owner
        _mint(initialOwner, MAX_SUPPLY);
    }

    // override the _update function to apply tax on transfers
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        // safety checks
        require(!circuitBreakerActive, "Circuit breaker active");
        require(!blacklisted[from] && !blacklisted[to], "Address blacklisted");

        // no tax applied in these cases:
        // - minting (from is zero address)
        // - burning (to is zero address)
        // - transfers to/from treasury or vault (avoid double taxation)
        if (from == address(0) || to == address(0) || taxRate == 0) {
            super._update(from, to, value);
            return;
        }

        // calculate tax amount - 2% tax
        uint256 taxAmount = (value * taxRate) / 10000;
        uint256 transferAmount = value - taxAmount;

        // transfer the amount minus tax to recipient
        super._update(from, to, transferAmount);

        // distribute tax - 1% to each destination
        uint256 halfTax = taxAmount / 2;
        super._update(from, treasuryWallet, halfTax);
        super._update(from, drawVault, taxAmount - halfTax); // handle odd numbers

        emit TaxDistributed(halfTax, taxAmount - halfTax);
    }

    // function to update tax rate - adjustable up to 3%
    // Enhanced with timelock requirement - FROM PRD REQUIREMENT #6
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
}
