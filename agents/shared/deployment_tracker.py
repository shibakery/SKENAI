from mycelial_base import MycelialNetwork, Track, PerformanceLevel
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import json

class DeploymentNode:
    def __init__(self, title: str, description: str, 
                 start_date: datetime, end_date: datetime,
                 budget: float, resources: List[str]):
        self.title = title
        self.description = description
        self.start_date = start_date
        self.end_date = end_date
        self.budget = budget
        self.resources = resources
        self.progress = 0.0
        self.dependencies = []
        self.risks = []
        self.metrics = {}

class DeploymentTracker:
    def __init__(self):
        self.network = MycelialNetwork()
        self.deployment_data: Dict[str, DeploymentNode] = {}
        
    def create_deployment_node(self, track: Track, level: PerformanceLevel,
                             title: str, description: str,
                             start_date: datetime, duration_days: int,
                             budget: float, resources: List[str],
                             parent_id: Optional[str] = None) -> str:
        """Create a new deployment node in the network"""
        end_date = start_date + timedelta(days=duration_days)
        deployment_data = DeploymentNode(title, description, start_date, 
                                       end_date, budget, resources)
        
        # Create proposal in mycelial network
        proposal = self.network.create_proposal(
            track=track,
            performance_level=level,
            depth_level=0 if not parent_id else 
                        self.network.proposals[parent_id].depth_level + 1,
            parent_id=parent_id,
            title=title,
            content=description
        )
        
        self.deployment_data[proposal.id] = deployment_data
        return proposal.id
        
    def update_progress(self, node_id: str, progress: float):
        """Update progress of a deployment node"""
        if node_id in self.deployment_data:
            self.deployment_data[node_id].progress = progress
            # Propagate verification in the mycelial network
            self.network.propagate_verification(node_id, progress/100.0)
            
    def add_dependency(self, node_id: str, dependency_id: str):
        """Add a dependency between deployment nodes"""
        if (node_id in self.deployment_data and 
            dependency_id in self.deployment_data):
            self.deployment_data[node_id].dependencies.append(dependency_id)
            self.network.connect_proposals(node_id, dependency_id)
            
    def add_risk(self, node_id: str, risk: str, severity: float):
        """Add a risk to a deployment node"""
        if node_id in self.deployment_data:
            self.deployment_data[node_id].risks.append({
                'description': risk,
                'severity': severity
            })
            
    def add_metric(self, node_id: str, metric_name: str, target_value: float):
        """Add a success metric to a deployment node"""
        if node_id in self.deployment_data:
            self.deployment_data[node_id].metrics[metric_name] = {
                'target': target_value,
                'current': 0.0
            }
            
    def get_critical_path(self) -> List[str]:
        """Calculate the critical path through the deployment"""
        nodes = []
        visited = set()
        
        def dfs(node_id: str) -> float:
            if node_id in visited:
                return 0
                
            visited.add(node_id)
            node = self.deployment_data[node_id]
            
            max_path = 0
            for dep_id in node.dependencies:
                path_length = dfs(dep_id)
                max_path = max(max_path, path_length)
                
            return max_path + (node.end_date - node.start_date).days
            
        # Find the node with the longest path
        max_length = 0
        critical_start = None
        
        for node_id in self.deployment_data:
            visited = set()
            path_length = dfs(node_id)
            if path_length > max_length:
                max_length = path_length
                critical_start = node_id
                
        # Reconstruct the critical path
        if critical_start:
            current = critical_start
            while current:
                nodes.append(current)
                next_node = None
                max_remaining = 0
                
                for dep_id in self.deployment_data[current].dependencies:
                    remaining = (self.deployment_data[dep_id].end_date - 
                               self.deployment_data[dep_id].start_date).days
                    if remaining > max_remaining:
                        max_remaining = remaining
                        next_node = dep_id
                        
                current = next_node
                
        return nodes
        
    def export_plan(self, filepath: str):
        """Export the deployment plan to JSON"""
        plan_data = {
            'nodes': {},
            'connections': []
        }
        
        for node_id, node in self.deployment_data.items():
            plan_data['nodes'][node_id] = {
                'title': node.title,
                'description': node.description,
                'start_date': node.start_date.isoformat(),
                'end_date': node.end_date.isoformat(),
                'budget': node.budget,
                'resources': node.resources,
                'progress': node.progress,
                'risks': node.risks,
                'metrics': node.metrics
            }
            
        for node_id in self.network.proposals:
            node = self.network.proposals[node_id]
            for connection in node.connections:
                plan_data['connections'].append({
                    'from': node_id,
                    'to': connection
                })
                
        with open(filepath, 'w') as f:
            json.dump(plan_data, f, indent=2)
