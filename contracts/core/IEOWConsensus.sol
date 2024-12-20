// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEOWConsensus
 * @dev Interface for the Evolution of Work (EOW) consensus mechanism
 */
interface IEOWConsensus {
    enum ValidatorType {
        AINode,
        StakingNode,
        HybridNode
    }

    struct Validator {
        bytes32 validatorId;
        ValidatorType validatorType;
        uint256 stake;
        uint256 computingPower;
        uint256 reputation;
        bool isActive;
    }

    struct Block {
        bytes32 blockHash;
        bytes32 previousHash;
        bytes32[] parentHashes; // DAG structure
        address validator;
        uint256 timestamp;
        uint256 difficulty;
        bytes32 nonce;
    }

    event ValidatorRegistered(
        bytes32 indexed validatorId,
        ValidatorType validatorType
    );

    event BlockProposed(
        bytes32 indexed blockHash,
        address indexed validator
    );

    event ConsensusAchieved(
        bytes32 indexed blockHash,
        bytes32[] parentHashes
    );

    /**
     * @dev Registers a new validator in the network
     * @param validatorType Type of validator (AI, Staking, or Hybrid)
     * @param computingPower Proof of computing capability for PoW
     * @return validatorId The ID of the registered validator
     */
    function registerValidator(
        ValidatorType validatorType,
        uint256 computingPower
    ) external payable returns (bytes32 validatorId);

    /**
     * @dev Proposes a new block to be added to the DAG
     * @param parentHashes Previous block hashes in DAG
     * @param transactions Encoded transaction data
     * @param nonce PoW solution
     * @return blockHash Hash of the proposed block
     */
    function proposeBlock(
        bytes32[] calldata parentHashes,
        bytes calldata transactions,
        bytes32 nonce
    ) external returns (bytes32 blockHash);

    /**
     * @dev Validates and votes on a proposed block
     * @param blockHash Hash of the block to validate
     * @param signature Validator's signature
     */
    function validateBlock(
        bytes32 blockHash,
        bytes calldata signature
    ) external;

    /**
     * @dev Updates validator's stake
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external payable;

    /**
     * @dev Retrieves current network difficulty
     * @return difficulty Current PoW difficulty
     */
    function getCurrentDifficulty() external view returns (uint256 difficulty);
}
