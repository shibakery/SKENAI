from typing import Dict, List, Optional, Set
from dataclasses import dataclass
from enum import Enum
import uuid

class Track(Enum):
    GENESIS = "genesis"
    FRACTAL = "fractal"
    OPTIONS = "options"
    RESEARCH = "research"
    ARCHIVE = "archive"
    COMMUNITY = "community"
    FINAL_BOSS = "final_boss"

class PerformanceLevel(Enum):
    ENTRY = "entry"
    BRONZE = "bronze"
    SILVER = "silver"
    GOLD = "gold"
    PLATINUM = "platinum"
    DIAMOND = "diamond"
    LEGEND = "legend"

@dataclass
class ProposalNode:
    id: str
    track: Track
    performance_level: PerformanceLevel
    depth_level: int
    parent_id: Optional[str]
    title: str
    content: str
    verification_score: float
    sub_proposals: List['ProposalNode']
    connections: Set[str]  # Set of proposal IDs this node is connected to

    def __init__(self, track: Track, performance_level: PerformanceLevel, 
                 depth_level: int = 0, parent_id: Optional[str] = None,
                 title: str = "", content: str = ""):
        self.id = str(uuid.uuid4())
        self.track = track
        self.performance_level = performance_level
        self.depth_level = depth_level
        self.parent_id = parent_id
        self.title = title
        self.content = content
        self.verification_score = 0.0
        self.sub_proposals = []
        self.connections = set()

class MycelialNetwork:
    def __init__(self):
        self.proposals: Dict[str, ProposalNode] = {}
        self.root_proposals: List[ProposalNode] = []

    def create_proposal(self, track: Track, performance_level: PerformanceLevel,
                       depth_level: int = 0, parent_id: Optional[str] = None,
                       title: str = "", content: str = "") -> ProposalNode:
        """Create a new proposal node in the network"""
        proposal = ProposalNode(track, performance_level, depth_level, parent_id, title, content)
        self.proposals[proposal.id] = proposal
        
        if parent_id:
            parent = self.proposals.get(parent_id)
            if parent:
                parent.sub_proposals.append(proposal)
        else:
            self.root_proposals.append(proposal)
            
        return proposal

    def connect_proposals(self, proposal_id1: str, proposal_id2: str) -> bool:
        """Create a bidirectional connection between two proposals"""
        if proposal_id1 not in self.proposals or proposal_id2 not in self.proposals:
            return False
            
        self.proposals[proposal_id1].connections.add(proposal_id2)
        self.proposals[proposal_id2].connections.add(proposal_id1)
        return True

    def propagate_verification(self, proposal_id: str, score_delta: float):
        """Propagate verification score changes through the network"""
        if proposal_id not in self.proposals:
            return
            
        proposal = self.proposals[proposal_id]
        proposal.verification_score += score_delta
        
        # Propagate to parent
        if proposal.parent_id:
            parent = self.proposals.get(proposal.parent_id)
            if parent:
                parent_delta = score_delta * 0.5  # Parent gets 50% of child's verification
                self.propagate_verification(parent.id, parent_delta)
        
        # Propagate to connected proposals
        for connected_id in proposal.connections:
            if connected_id in self.proposals:
                connection_delta = score_delta * 0.3  # Connected proposals get 30% of verification
                self.proposals[connected_id].verification_score += connection_delta

    def get_proposal_ecosystem(self, proposal_id: str, max_depth: int = -1) -> List[ProposalNode]:
        """Get all proposals connected to a given proposal within max_depth connections"""
        if proposal_id not in self.proposals:
            return []
            
        visited = set()
        ecosystem = []
        
        def dfs(current_id: str, current_depth: int):
            if current_id in visited or (max_depth != -1 and current_depth > max_depth):
                return
                
            visited.add(current_id)
            current_proposal = self.proposals[current_id]
            ecosystem.append(current_proposal)
            
            # Visit sub-proposals
            for sub in current_proposal.sub_proposals:
                dfs(sub.id, current_depth + 1)
                
            # Visit connected proposals
            for connected_id in current_proposal.connections:
                dfs(connected_id, current_depth + 1)
        
        dfs(proposal_id, 0)
        return ecosystem
