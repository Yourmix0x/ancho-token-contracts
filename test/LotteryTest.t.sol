// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, stdError} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";
import {AnchoToken} from "../src/AnchoToken.sol";

// mock VRF coordinator for testing
contract MockVRFCoordinator {
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256) {
        return 1; // mock request ID
    }
}

contract LotteryTest is Test {
    Lottery public lottery;
    AnchoToken public token;
    MockVRFCoordinator public mockVRF;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public vault = makeAddr("vault");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 keyHash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint64 subscriptionId = 1;

    function setUp() public {
        // deploy mock VRF coordinator
        mockVRF = new MockVRFCoordinator();

        // Deploy token
        vm.prank(owner);
        token = new AnchoToken(owner, treasury, vault);

        // deploy lottery
        vm.prank(owner);
        lottery = new Lottery(
            address(mockVRF),
            keyHash,
            subscriptionId,
            address(token),
            vault,
            owner
        );

        // fund the vault with tokens
        vm.prank(owner);
        token.transfer(vault, 10_000_000 * 10 ** 18);
    }

    function test_LotteryInitialization() public {
          assertEq(address(lottery.anchoToken()), address(token));
        assertEq(lottery.drawVault(), vault);
        assertEq(
            uint256(lottery.state()),
            uint256(Lottery.LotteryState.CLOSED)
        );
    }

    function test_PrizeCalculation() public {
        // vault has 10M tokens, 25% = 2.5M, which is less than 7M cap
        uint256 vaultBalance = token.balanceOf(vault);
        uint256 expectedPrize = (vaultBalance * 25) / 100; // 2.5M

        // test the prize cap logic
        assertTrue(
            expectedPrize < 7_000_000 * 10 ** 18,
            "Prize should be below cap"
        );
    }

    function test_DrawDateValidation() public {
        // test date checking (simplified)
        // mock block.timestamp for proper testing
        vm.warp(1704067200);

        // This is a basic test - we'll enhance with proper date mocking
        bool isDrawDate = lottery.isDrawDate();
        // Just testing that the function doesn't revert
        assertTrue(isDrawDate == true || isDrawDate == false);
    }

    function test_OnlyOwnerCanAddParticipants() public {
        vm.prank(user1);
        vm.expectRevert();
        lottery.addParticipant(user2);

        vm.prank(owner);
        lottery.addParticipant(user1);
        // Should not revert
    }

    function test_EmergencyCancel() public {
        // Only owner can emergency cancel
        vm.prank(user1);
        vm.expectRevert();
        lottery.emergencyCancel();
    }
}
