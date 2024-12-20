// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ConsensusEngine
 * @dev Implements PRIME blockchain's consensus mechanism
 */
contract ConsensusEngine is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // Structs
    struct Validator {
        uint256 stake;
        uint256 reputation;
        bool isActive;
        uint256 lastProposalTime;
        uint256 successfulProposals;
    }

    struct Block {
        bytes32 blockHash;
        address proposer;
        uint256 timestamp;
        bytes32 previousHash;
        bytes32 stateRoot;
        uint256 number;
        mapping(address => bool) validations;
        uint256 validationCount;
    }

    // State variables
    mapping(address => Validator) public validators;
    mapping(bytes32 => Block) public blocks;
    address[] public validatorSet;
    
    uint256 public constant MIN_STAKE = 1000 ether;
    uint256 public constant VALIDATION_THRESHOLD = 2/3;
    uint256 public constant PROPOSAL_COOLDOWN = 1 minutes;
    uint256 public constant SLASH_AMOUNT = 100 ether;
    
    bytes32 public latestBlockHash;
    uint256 public blockNumber;
    
    // Events
    event ValidatorRegistered(address indexed validator, uint256 stake);
    event ValidatorSlashed(address indexed validator, uint256 amount);
    event BlockProposed(bytes32 indexed blockHash, address indexed proposer);
    event BlockValidated(bytes32 indexed blockHash, address indexed validator);
    event BlockFinalized(bytes32 indexed blockHash, uint256 number);

    // Modifiers
    modifier onlyValidator() {
        require(validators[msg.sender].isActive, "Not an active validator");
        _;
    }

    modifier validBlock(bytes32 blockHash) {
        require(blocks[blockHash].timestamp != 0, "Block does not exist");
        _;
    }

    /**
     * @dev Register as a validator with stake
     */
    function registerValidator() external payable {
        require(msg.value >= MIN_STAKE, "Insufficient stake");
        require(!validators[msg.sender].isActive, "Already a validator");

        validators[msg.sender] = Validator({
            stake: msg.value,
            reputation: 100,
            isActive: true,
            lastProposalTime: 0,
            successfulProposals: 0
        });

        validatorSet.push(msg.sender);
        emit ValidatorRegistered(msg.sender, msg.value);
    }

    /**
     * @dev Propose a new block
     */
    function proposeBlock(
        bytes32 previousHash,
        bytes32 stateRoot,
        bytes memory signature
    ) external onlyValidator nonReentrant {
        require(
            block.timestamp >= validators[msg.sender].lastProposalTime + PROPOSAL_COOLDOWN,
            "Proposal cooldown active"
        );
        
        // Verify previous block
        require(previousHash == latestBlockHash, "Invalid previous hash");
        
        // Create block hash
        bytes32 blockHash = keccak256(
            abi.encodePacked(
                previousHash,
                stateRoot,
                block.timestamp,
                msg.sender
            )
        );
        
        // Verify signature
        require(
            blockHash.toEthSignedMessageHash().recover(signature) == msg.sender,
            "Invalid signature"
        );
        
        // Create new block
        Block storage newBlock = blocks[blockHash];
        newBlock.blockHash = blockHash;
        newBlock.proposer = msg.sender;
        newBlock.timestamp = block.timestamp;
        newBlock.previousHash = previousHash;
        newBlock.stateRoot = stateRoot;
        newBlock.number = blockNumber + 1;
        newBlock.validationCount = 0;
        
        validators[msg.sender].lastProposalTime = block.timestamp;
        
        emit BlockProposed(blockHash, msg.sender);
    }

    /**
     * @dev Validate a proposed block
     */
    function validateBlock(
        bytes32 blockHash,
        bytes memory signature
    ) external onlyValidator validBlock(blockHash) nonReentrant {
        Block storage block_ = blocks[blockHash];
        require(!block_.validations[msg.sender], "Already validated");
        
        // Verify signature
        require(
            blockHash.toEthSignedMessageHash().recover(signature) == msg.sender,
            "Invalid signature"
        );
        
        block_.validations[msg.sender] = true;
        block_.validationCount++;
        
        emit BlockValidated(blockHash, msg.sender);
        
        // Check if block can be finalized
        if (block_.validationCount >= (validatorSet.length * VALIDATION_THRESHOLD) / 100) {
            finalizeBlock(blockHash);
        }
    }

    /**
     * @dev Finalize a block after sufficient validations
     */
    function finalizeBlock(bytes32 blockHash) internal validBlock(blockHash) {
        Block storage block_ = blocks[blockHash];
        
        // Update state
        latestBlockHash = blockHash;
        blockNumber = block_.number;
        
        // Reward proposer
        validators[block_.proposer].successfulProposals++;
        validators[block_.proposer].reputation += 1;
        
        emit BlockFinalized(blockHash, blockNumber);
    }

    /**
     * @dev Slash a validator for malicious behavior
     */
    function slashValidator(
        address validator,
        bytes memory proof
    ) external onlyOwner {
        require(validators[validator].isActive, "Not an active validator");
        require(validators[validator].stake >= SLASH_AMOUNT, "Insufficient stake");
        
        validators[validator].stake -= SLASH_AMOUNT;
        validators[validator].reputation -= 10;
        
        if (validators[validator].stake < MIN_STAKE) {
            validators[validator].isActive = false;
        }
        
        emit ValidatorSlashed(validator, SLASH_AMOUNT);
    }

    /**
     * @dev Get current validator set
     */
    function getValidatorSet() external view returns (address[] memory) {
        return validatorSet;
    }

    /**
     * @dev Get validator info
     */
    function getValidator(
        address validator
    ) external view returns (
        uint256 stake,
        uint256 reputation,
        bool isActive,
        uint256 successfulProposals
    ) {
        Validator memory v = validators[validator];
        return (v.stake, v.reputation, v.isActive, v.successfulProposals);
    }
}
