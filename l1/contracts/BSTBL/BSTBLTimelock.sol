// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title BSTBL Timelock
 * @dev Timelock controller for BSTBL governance
 */
contract BSTBLTimelock is TimelockController {
    /**
     * @dev Constructor
     * @param minDelay minimum delay for operations
     * @param proposers accounts to be granted proposer role
     * @param executors accounts to be granted executor role
     * @param admin optional account to be granted admin role
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
