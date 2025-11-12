// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title timelock for sensitive operations
 * @dev adds delay to critical functions for security
 */
contract AnchoTimelock is Ownable {
    uint256 public constant DELAY = 2 days; // 48-hour timelock
    mapping(bytes32 => uint256) public pendingOperations;

    event OperationScheduled(bytes32 indexed operationId, uint256 executeAt);
    event OperationExecuted(bytes32 indexed operationId);
    event OperationCancelled(bytes32 indexed operationId);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function scheduleTaxChange(
        uint256 newTaxRate
    ) external onlyOwner returns (bytes32) {
        bytes32 operationId = keccak256(abi.encode("setTaxRate", newTaxRate));
        _scheduleOperation(operationId);
        return operationId;
    }

    function scheduleBridgeStatusChange(
        bool active
    ) external onlyOwner returns (bytes32) {
        bytes32 operationId = keccak256(abi.encode("setBridgeActive", active));
        _scheduleOperation(operationId);
        return operationId;
    }

    function scheduleReflectionRateChange(
        uint256 newReflectionRate
    ) external onlyOwner returns (bytes32) {
        bytes32 operationId = keccak256(abi.encode("setReflectionRate", newReflectionRate));
        _scheduleOperation(operationId);
        return operationId;
    }

    function executeTaxChange(
        address token,
        uint256 newTaxRate
    ) external onlyOwner {
        bytes32 operationId = keccak256(abi.encode("setTaxRate", newTaxRate));
        _executeOperation(operationId);

        // interface for token contract
        (bool success, ) = token.call(
            abi.encodeWithSignature("setTaxRate(uint256)", newTaxRate)
        );
        require(success, "Tax change execution failed");
    }

    function executeBridgeStatusChange(
        address bridge,
        bool active
    ) external onlyOwner {
        bytes32 operationId = keccak256(abi.encode("setBridgeActive", active));
        _executeOperation(operationId);

        // interface for bridge contract
        (bool success, ) = bridge.call(
            abi.encodeWithSignature("setBridgeActive(bool)", active)
        );
        require(success, "Bridge status change execution failed");
    }

    function executeReflectionRateChange(
        address token,
        uint256 newReflectionRate
    ) external onlyOwner {
        bytes32 operationId = keccak256(abi.encode("setReflectionRate", newReflectionRate));
        _executeOperation(operationId);

        // interface for token contract
        (bool success, ) = token.call(
            abi.encodeWithSignature("setReflectionRate(uint256)", newReflectionRate)
        );
        require(success, "Reflection rate change execution failed");
    }

    function cancelOperation(bytes32 operationId) external onlyOwner {
        require(pendingOperations[operationId] > 0, "Operation not scheduled");
        delete pendingOperations[operationId];
        emit OperationCancelled(operationId);
    }

    function _scheduleOperation(bytes32 operationId) internal {
        require(
            pendingOperations[operationId] == 0,
            "Operation already scheduled"
        );
        uint256 executeAt = block.timestamp + DELAY;
        pendingOperations[operationId] = executeAt;
        emit OperationScheduled(operationId, executeAt);
    }

    function _executeOperation(bytes32 operationId) internal {
        uint256 executeAt = pendingOperations[operationId];
        require(executeAt > 0, "Operation not scheduled");
        require(block.timestamp >= executeAt, "Operation timelock not passed");
        delete pendingOperations[operationId];
        emit OperationExecuted(operationId);
    }
}
