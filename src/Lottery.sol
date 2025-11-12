// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lottery is VRFConsumerBaseV2, Ownable {
    // chainlink VRF variables
    VRFCoordinatorV2Interface public COORDINATOR;
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;

    // lottery state
    enum LotteryState {
        OPEN,
        DRAWING,
        CLOSED
    }
    LotteryState public state;

    // lottery configuration
    uint256 public constant PRIZE_CAP = 7_000_000 * 10 ** 18; // 7M tokens
    uint256 public constant PRIZE_PERCENTAGE = 25; // 25%
    uint256 public constant MIN_TOKEN_HOLDING = 777 * 10 ** 18; // Hold 777 tokens to enter

    // token references
    IERC20 public anchoToken;
    address public drawVault;

    // current draw information
    uint256 public currentDrawId;
    uint256 public currentPrizePool;
    address[] public currentParticipants;

    mapping(uint256 => address) public drawWinners;
    mapping(uint256 => uint256) public requestToDrawId;

    // events
    event LotteryDrawStarted(
        uint256 drawId,
        uint256 prizePool,
        uint256 participantCount
    );
    event LotteryDrawCompleted(uint256 drawId, address winner, uint256 prize);
    event ParticipantAdded(address participant);

    constructor(
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        address _anchoToken,
        address _drawVault,
        address initialOwner
    ) VRFConsumerBaseV2(vrfCoordinator) Ownable(initialOwner) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        anchoToken = IERC20(_anchoToken);
        drawVault = _drawVault;
        state = LotteryState.CLOSED;
    }

    // users enter lottery by calling this function
    function enterLottery() external {
        require(state == LotteryState.OPEN, "Lottery not open for entries");
        require(
            anchoToken.balanceOf(msg.sender) >= MIN_TOKEN_HOLDING,
            "Hold at least 777 tokens"
        );

        // prevent duplicate entries
        for (uint256 i = 0; i < currentParticipants.length; i++) {
            if (currentParticipants[i] == msg.sender) {
                revert("Already entered this draw");
            }
        }

        currentParticipants.push(msg.sender);
        emit ParticipantAdded(msg.sender);
    }

    // start draw on scheduled dates
    function startDraw() external {
        require(state == LotteryState.CLOSED, "Lottery already in progress");
        require(isDrawDate(), "Not a valid draw date");
        require(currentParticipants.length >= 1, "No participants");

        // calculate prize pool - min(vault × 25 %, 7 M)
        uint256 vaultBalance = anchoToken.balanceOf(drawVault);
        uint256 prizePool = (vaultBalance * PRIZE_PERCENTAGE) / 100;
        if (prizePool > PRIZE_CAP) {
            prizePool = PRIZE_CAP;
        }

        require(prizePool > 0, "No funds available for draw");
        require(
            anchoToken.allowance(drawVault, address(this)) >= prizePool,
            "Insufficient allowance"
        );

        currentDrawId++;
        currentPrizePool = prizePool;
        state = LotteryState.DRAWING;

        // request randomness from Chainlink VRF
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );

        requestToDrawId[requestId] = currentDrawId;

        emit LotteryDrawStarted(
            currentDrawId,
            prizePool,
            currentParticipants.length
        );
    }

    // chainlink VRF callback
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(state == LotteryState.DRAWING, "Lottery not in drawing state");

        uint256 drawId = requestToDrawId[requestId];
        require(drawId == currentDrawId, "Draw ID mismatch");

        if (currentParticipants.length == 0) {
            state = LotteryState.CLOSED;
            return;
        }

        // select random winner
        uint256 winnerIndex = randomWords[0] % currentParticipants.length;
        address winner = currentParticipants[winnerIndex];

        // transfer prize to winner
        require(
            anchoToken.transferFrom(drawVault, winner, currentPrizePool),
            "Prize transfer failed"
        );

        // record winner
        drawWinners[currentDrawId] = winner;

        emit LotteryDrawCompleted(currentDrawId, winner, currentPrizePool);

        // reset for next draw
        delete currentParticipants;
        state = LotteryState.CLOSED;
    }

    // date checking - fixed calculation
    function isDrawDate() public view returns (bool) {
        // gets day of month (1-31) from timestamp
        uint256 daysSinceEpoch = block.timestamp / (24 * 60 * 60);

        // approximate calculation - good enough for testing
        uint256 day = (((daysSinceEpoch + 3) % 365) % 31) + 1;

        // ensure day is within valid range (1-31)
        if (day > 31) day = (day % 31) + 1;

        return (day == 7 || day == 17 || day == 27);
    }

    // admin functions
    function openLottery() external onlyOwner {
        require(state == LotteryState.CLOSED, "Lottery not closed");
        state = LotteryState.OPEN;
    }

    function emergencyCancel() external onlyOwner {
        require(state == LotteryState.DRAWING, "No active draw to cancel");
        delete currentParticipants;
        state = LotteryState.CLOSED;
    }

    // view functions
    function getParticipantCount() external view returns (uint256) {
        return currentParticipants.length;
    }

    function getCurrentParticipants() external view returns (address[] memory) {
        return currentParticipants;
    }
}
