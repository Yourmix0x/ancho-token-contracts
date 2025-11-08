// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, stdError} from "forge-std/Test.sol";
import {AnchoToken} from "../src/AnchoToken.sol";

contract AnchoTokenTest is Test {
    AnchoToken public token;
    address public owner = makeAddr("Owner");
    address public user1 = makeAddr("user1");

    function setUp() public {
        // deploy token with owner
        vm.prank(owner);
        // token = new AnchoToken(owner);
    }

    function test_InitialState() public {
        // test token name and symbol
         assertEq(token.name(), "AnchoToken");
        assertEq(token.symbol(), "ANCHO");
    }

    function test_MaxSupply() public{
        // fixed max supply of 777, 777, 777
        assertEq(token.totalSupply(), 777_777_777 * 10 ** 18);
        assertEq(token.balanceOf(owner), 777_777_777 * 10 ** 18);
    }

    function test_Transfer() public {
        // give some token to user1
        vm.prank(owner);
        token.transfer(user1, 1000 * 10 ** 18);

        assertEq(token.balanceOf(user1), 1000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 777_777_777 * 1000 * 10 ** 18 - 1000 * 10 ** 18);
        
    }

      function test_PauseFunction() public {
        // test that only owner can pause
        vm.prank(user1);
        vm.expectRevert();
        token.pause();
        
        // owner should be able to pause
        vm.prank(owner);
        token.pause();
        
        // transfers should be blocked when paused
        vm.prank(owner);
        vm.expectRevert("ERC20Pausable: token transfer while paused");
        token.transfer(user1, 1000 * 10 ** 18);
    }
}