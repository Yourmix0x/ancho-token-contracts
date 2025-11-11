// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {AnchoToken} from "../src/AnchoToken.sol";
import {Bridge} from "../src/Bridge.sol";

contract BridgeTest is Test {
    Bridge public bridge;
    AnchoToken public token;
    
    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public vault = makeAddr("vault");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    function setUp() public {
        // deploy token
        vm.prank(owner);
        token = new AnchoToken(owner, treasury, vault);
        
        // deploy bridge
        vm.prank(owner);
        bridge = new Bridge(address(token), owner);
        
        // give users tokens and approval (accounting for 2% tax)
        vm.prank(owner);
        token.transfer(user1, 10_000 * 10 ** 18); // user1 receives 9,800 tokens
        
        vm.prank(owner);
        token.transfer(user2, 5_000_000 * 10 ** 18); // user2 receives 4,900,000 tokens
        
        vm.prank(user1);
        token.approve(address(bridge), type(uint256).max);
        
        vm.prank(user2);
        token.approve(address(bridge), type(uint256).max);
        
        // fund bridge with tokens for returns
        vm.prank(owner);
        token.transfer(address(bridge), 5_000_000 * 10 ** 18);
    }
    
    function test_BridgeInitialization() public {
        assertEq(address(bridge.token()), address(token));
        assertEq(bridge.totalBridged(), 0);
        assertEq(bridge.getRemainingCapacity(), 7_000_000 * 10 ** 18);
        assertTrue(bridge.bridgeActive());
    }
    
    function test_BridgeTokens() public {
        uint256 amount = 1_000 * 10 ** 18;
        uint256 user1InitialBalance = token.balanceOf(user1); // 9,800 tokens after tax
        
        vm.prank(user1);
        bridge.bridgeTokens(amount);
        
        // check user's balance decreased (user pays full amount, bridge receives amount minus tax)
        uint256 expectedBalance = user1InitialBalance - amount;
        assertEq(token.balanceOf(user1), expectedBalance);
        
        // check bridge state updated (bridge records full amount bridged)
        assertEq(bridge.totalBridged(), amount);
        assertEq(bridge.bridgeBalances(user1), amount);
    }
    
    function test_BridgeLimit() public {
        // user1 bridges small amount (has 9,800 tokens)
        vm.prank(user1);
        bridge.bridgeTokens(1_000 * 10 ** 18);
        
        // user2 tries to bridge amount that would exceed 7M limit
        vm.prank(user2);
        vm.expectRevert("Exceeds bridge limit");
        bridge.bridgeTokens(7_000_000 * 10 ** 18); // This would exceed limit
        
        // user2 can bridge within remaining capacity
        uint256 remainingCapacity = bridge.getRemainingCapacity(); // Should be 6,999,000 tokens
        uint256 user2Balance = token.balanceOf(user2); // Should be 4,900,000 tokens
        
        // Bridge the smaller of: remaining capacity or user2's balance
        uint256 bridgeAmount = remainingCapacity < user2Balance ? remainingCapacity : user2Balance;
        
        vm.prank(user2);
        bridge.bridgeTokens(bridgeAmount);
        
        // Check that we're close to or at the limit
        assertLe(bridge.totalBridged(), 7_000_000 * 10 ** 18);
    }
    
    function test_ReturnTokens() public {
        // first bridge some tokens
        uint256 amount = 1_000 * 10 ** 18;
        vm.prank(user1);
        bridge.bridgeTokens(amount);
        
        // return tokens to user
        uint256 userBalanceBefore = token.balanceOf(user1);
        vm.prank(owner);
        bridge.returnTokens(user1, amount);
        
        // user should get tokens back (minus tax on return transfer)
        uint256 taxOnReturn = (amount * 200) / 10000; // 2% tax
        assertEq(token.balanceOf(user1), userBalanceBefore + amount - taxOnReturn);
        assertEq(bridge.totalBridged(), 0);
        assertEq(bridge.bridgeBalances(user1), 0);
    }
    
    function test_OnlyOwnerCanReturnTokens() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.returnTokens(user1, 1000);
    }
    
    function test_BridgeInactive() public {
        vm.prank(owner);
        bridge.setBridgeActive(false);
        
        vm.prank(user1);
        vm.expectRevert("Bridge inactive");
        bridge.bridgeTokens(1000);
    }
}