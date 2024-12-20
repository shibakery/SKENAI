// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/**
 * @title BSTBL Governance
 * @dev Governance mechanism for BSTBL token
 */
contract BSTBLGovernance is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // Governance parameters
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 100000 * 1e18; // 100,000 BSTBL
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 1000000 * 1e18; // 1M BSTBL
    
    struct GovernanceParams {
        uint256 votingDelay;    // Delay before voting starts
        uint256 votingPeriod;   // Duration of voting
        uint256 quorumPercent;  // Required participation
        uint256 proposalThreshold; // Tokens required to propose
    }
    
    GovernanceParams public params;
    
    // Events
    event GovernanceParamsUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumPercent,
        uint256 proposalThreshold
    );
    
    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("BSTBL Governance")
        GovernorSettings(
            1 days,    // 1 day voting delay
            7 days,    // 1 week voting period
            MIN_PROPOSAL_THRESHOLD  // Proposal threshold
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)  // 4% quorum
        GovernorTimelockControl(_timelock)
    {
        params = GovernanceParams({
            votingDelay: 1 days,
            votingPeriod: 7 days,
            quorumPercent: 4,
            proposalThreshold: MIN_PROPOSAL_THRESHOLD
        });
    }
    
    /**
     * @dev Update governance parameters
     */
    function updateGovernanceParams(
        uint256 newVotingDelay,
        uint256 newVotingPeriod,
        uint256 newQuorumPercent,
        uint256 newProposalThreshold
    ) external onlyGovernance {
        require(newVotingDelay >= 1 days, "Voting delay too short");
        require(newVotingPeriod >= 7 days, "Voting period too short");
        require(newQuorumPercent >= 1 && newQuorumPercent <= 100, "Invalid quorum");
        require(
            newProposalThreshold >= MIN_PROPOSAL_THRESHOLD &&
            newProposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            "Invalid threshold"
        );
        
        params.votingDelay = newVotingDelay;
        params.votingPeriod = newVotingPeriod;
        params.quorumPercent = newQuorumPercent;
        params.proposalThreshold = newProposalThreshold;
        
        _setVotingDelay(newVotingDelay);
        _setVotingPeriod(newVotingPeriod);
        _updateQuorumNumerator(newQuorumPercent);
        _setProposalThreshold(newProposalThreshold);
        
        emit GovernanceParamsUpdated(
            newVotingDelay,
            newVotingPeriod,
            newQuorumPercent,
            newProposalThreshold
        );
    }
    
    // The following functions are overrides required by Solidity
    
    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }
    
    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }
    
    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }
    
    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }
    
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, IGovernor)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }
    
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
    
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }
    
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }
    
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
