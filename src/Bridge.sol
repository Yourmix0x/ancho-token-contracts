// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bridge is Ownable {
    IERC20 public token;
    
    // bridge configuration
    uint256 public constant BRIDGE_LIMIT = 7_000_000 * 10 ** 18;
    uint256 public totalBridged;
    
    // bridge state
    bool public bridgeActive;
    mapping(address => uint256) public bridgeBalances;
    
    // events
    event TokensBridged(address indexed user, uint256 amount, uint256 totalBridged);
    event TokensReturned(address indexed user, uint256 amount);
    event BridgeStatusChanged(bool active);
    
    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
        bridgeActive = true;
    }
    
    /**
     * @notice bridge tokens to another chain
     * @dev this simulates "burn on Base" - tokens are locked in this contract
     */
    function bridgeTokens(uint256 amount) external {
        require(bridgeActive, "Bridge inactive");
        require(amount > 0, "Amount must be positive");
        require(totalBridged + amount <= BRIDGE_LIMIT, "Exceeds bridge limit");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Update state
        bridgeBalances[msg.sender] += amount;
        totalBridged += amount;
        
        emit TokensBridged(msg.sender, amount, totalBridged);
    }
    
    /**
     * @notice return tokens to user (simulates "mint on ETH")
     * @dev in production, this would be called by a bridge validator
     */
    function returnTokens(address user, uint256 amount) external onlyOwner {
        require(bridgeBalances[user] >= amount, "Insufficient bridged balance");
        
        bridgeBalances[user] -= amount;
        totalBridged -= amount;
        
        require(token.transfer(user, amount), "Return transfer failed");
        emit TokensReturned(user, amount);
    }
    
    function setBridgeActive(bool active) external onlyOwner {
        bridgeActive = active;
        emit BridgeStatusChanged(active);
    }
    
    function getRemainingCapacity() external view returns (uint256) {
        return BRIDGE_LIMIT - totalBridged;
    }
    
    function isBridgeLimitReached() external view returns (bool) {
        return totalBridged >= BRIDGE_LIMIT;
    }
    
    /**
     * @notice emergency withdrawal of tokens (only if bridge is inactive)
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(!bridgeActive, "Bridge must be inactive");
        require(token.transfer(to, amount), "Withdrawal failed");
    }
}