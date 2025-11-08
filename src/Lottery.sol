// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
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
    enum LotteryState { OPEN, DRAWING, CLOSED }
    LotteryState public state;
    
    // lottery configuration
    uint256 public constant PRIZE_CAP = 7_000_000 * 10 ** 18; // 7M tokens
    uint256 public constant PRIZE_PERCENTAGE = 25; // 25%
    
    // token and vault references
    IERC20 public anchoToken;
    address public drawVault;
    
    // current draw information
    uint256 public currentDrawId;
    uint256 public currentPrizePool;
    address[] public currentParticipants;
    mapping(uint256 => address) public drawWinners; // drawId -> winner
    
    // events
    event LotteryDrawStarted(uint256 drawId, uint256 prizePool, uint256 participantCount);
    event LotteryDrawCompleted(uint256 drawId, address winner, uint256 prize);
    event RandomnessRequested(uint256 requestId, uint256 drawId);
    
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
    
    // start a new lottery draw - can be called by anyone on scheduled dates
    function startDraw() external {
        require(state == LotteryState.CLOSED, "Lottery already in progress");
        require(isDrawDate(), "Not a valid draw date");
        
        // calculate prize pool - min(vault × 25 %, 7 M)
        uint256 vaultBalance = anchoToken.balanceOf(drawVault);
        uint256 prizePool = (vaultBalance * PRIZE_PERCENTAGE) / 100;
        if (prizePool > PRIZE_CAP) {
            prizePool = PRIZE_CAP;
        }
        
        require(prizePool > 0, "No funds available for draw");
        
        // take snapshot of token holders (simplified - we'll enhance this)
        // for now, we'll assume we have a way to get participants
        currentDrawId++;
        currentPrizePool = prizePool;
        state = LotteryState.DRAWING;
        
        // request randomness from chainlink VRF
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1 // number of random words
        );
        
        emit LotteryDrawStarted(currentDrawId, prizePool, currentParticipants.length);
        emit RandomnessRequested(requestId, currentDrawId);
    }
    
    // chainlink VRF callback function
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(state == LotteryState.DRAWING, "Lottery not in drawing state");
        
        if (currentParticipants.length == 0) {
            // no participants, refund to vault
            state = LotteryState.CLOSED;
            return;
        }
        
        // select winner using randomness
        uint256 winnerIndex = randomWords[0] % currentParticipants.length;
        address winner = currentParticipants[winnerIndex];
        
        // transfer prize to winner
        anchoToken.transferFrom(drawVault, winner, currentPrizePool);
        
        // record winner
        drawWinners[currentDrawId] = winner;
        
        emit LotteryDrawCompleted(currentDrawId, winner, currentPrizePool);
        
        // reset for next draw
        delete currentParticipants;
        state = LotteryState.CLOSED;
    }
    
    // check if today is a valid draw date (7th, 17th, 27th)
    function isDrawDate() public view returns (bool) {
        (uint year, uint month, uint day) = timestampToDate(block.timestamp);
        
        return (day == 7 || day == 17 || day == 27);
    }
    
    // helper function to extract date from timestamp
    function timestampToDate(uint timestamp) public pure returns (uint year, uint month, uint day) {
        // simplified date calculation - in production, use a proper library
        // this is a basic implementation for testing
        uint256 _days = timestamp / 1 days;
        
        year = 1970 + _days / 365;
        month = (_days % 365) / 30 + 1;
        day = (_days % 30) + 1;
        
        // note: This is simplified. For production, use a proper date library
    }
    
    // add participant (simplified - we'll enhance with NFT logic later)
    function addParticipant(address participant) external onlyOwner {
        currentParticipants.push(participant);
    }
    
    // emergency function to cancel draw
    function emergencyCancel() external onlyOwner {
        require(state == LotteryState.DRAWING, "No active draw to cancel");
        state = LotteryState.CLOSED;
        delete currentParticipants;
    }
    
    // configuration functions
    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }
    
    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }
}