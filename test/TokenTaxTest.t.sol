// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {AnchoToken} from "../src/AnchoToken.sol";

contract TokenTaxTest is Test {
    AnchoToken public token;
    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public vault = makeAddr("vault");
    address public emergencyAdmin = makeAddr("emergencyAdmin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    function setUp() public {
        vm.prank(owner);
        token = new AnchoToken(owner, treasury, vault, emergencyAdmin);
        
        // give some tokens to user1 for testing transfers
        vm.prank(owner);
        token.transfer(user1, 1000 * 10 ** 18);
    }
    
    function test_TaxDistribution() public {
        uint256 transferAmount = 100 * 10 ** 18;
        uint256 expectedTax = (transferAmount * 200) / 10000; // 2% of 100 = 2 tokens
        
        uint256 user1InitialBalance = token.balanceOf(user1);
        uint256 user2InitialBalance = token.balanceOf(user2);
        uint256 treasuryInitialBalance = token.balanceOf(treasury);
        uint256 vaultInitialBalance = token.balanceOf(vault);
        
        vm.prank(user1);
        token.transfer(user2, transferAmount);
        
        // user2 should receive amount minus tax (100 - 2 = 98)
        assertEq(token.balanceOf(user2), user2InitialBalance + transferAmount - expectedTax);
        
        // user1 should be debited full amount (100)
        assertEq(token.balanceOf(user1), user1InitialBalance - transferAmount);
        
        // tax should be split 50/50 between treasury and vault (1 token each)
        assertEq(token.balanceOf(treasury), treasuryInitialBalance + expectedTax / 2);
        assertEq(token.balanceOf(vault), vaultInitialBalance + expectedTax / 2);
    }
    
    function test_NoTaxOnMint() public {
        // minting should not apply tax (from = address(0))
        uint256 totalSupplyBefore = token.totalSupply();
        
        // can't test internal _mint, but we can verify initial mint worked without tax
        assertEq(token.totalSupply(), 777_777_777 * 10 ** 18);
        assertEq(token.balanceOf(owner), 777_777_777 * 10 ** 18 - 1000 * 10 ** 18);
    }
    
    function test_NoTaxOnBurn() public {
        // burning should not apply tax (to = address(0))
        uint256 totalSupplyBefore = token.totalSupply();
        
        vm.prank(user1);
        token.transfer(address(0), 100 * 10 ** 18); // Burn tokens
        
        // total supply should decrease by exact amount, no tax
        assertEq(token.totalSupply(), totalSupplyBefore - 100 * 10 ** 18);
    }
    
    function test_TaxRateChange() public {
        // test that only owner can change tax rate
        vm.prank(user1);
        vm.expectRevert();
        token.setTaxRate(250);
        
        // owner should be able to change within bounds
        vm.prank(owner);
        token.setTaxRate(250); // 2.5%
        assertEq(token.taxRate(), 250);
        
        // test upper bound (3%)
        vm.prank(owner);
        token.setTaxRate(300);
        assertEq(token.taxRate(), 300);
        
        // test exceeding maximum
        vm.prank(owner);
        vm.expectRevert("Tax rate too high");
        token.setTaxRate(301);
    }
    
    function test_TaxCalculationEdgeCases() public {
        // test with small amounts
        vm.prank(owner);
        token.transfer(user2, 100); // 100 wei (smallest unit)
        
        // with 2% tax on 100 wei = 2 wei tax (1 wei to each)
        // should handle very small amounts correctly
        assertEq(token.balanceOf(user2), 100 - 2);
    }
}