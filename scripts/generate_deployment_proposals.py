from pathlib import Path
from datetime import datetime, timedelta
import json
import re

class ProposalGenerator:
    def __init__(self, base_path: str):
        self.base_path = Path(base_path)
        self.proposals_dir = self.base_path / 'governance' / 'proposals'
        self.sequence_counter = self.get_next_sequence()
        
    def get_next_sequence(self):
        """Get the next available sequence number"""
        existing = list(self.proposals_dir.glob('*-L*-[0-9][0-9][0-9]-*.md'))
        if not existing:
            return 7  # Start after existing proposals
        numbers = [int(re.search(r'-(\d{3})-', str(p)).group(1)) for p in existing if re.search(r'-(\d{3})-', str(p))]
        return max(numbers) + 1 if numbers else 7

    def create_proposal(self, track: str, level: int, title: str, description: str,
                       budget: float, duration: int, series: str,
                       dependencies: list = None, objectives: list = None):
        """Create a new proposal file"""
        sequence = str(self.sequence_counter).zfill(3)
        self.sequence_counter += 1
        
        # Create filename
        safe_title = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
        filename = f"{track}-L{level}-{sequence}-S{series}-{safe_title}.md"
        
        # Create content
        content = [
            f"# SIP-{sequence}: {title}",
            "",
            "## Metadata",
            f"- Track: {track}",
            f"- Level: L{level}",
            f"- Sequence: {sequence}",
            f"- Series: {series}",
            "- Status: Draft",
            f"- Created: {datetime.now().strftime('%Y-%m-%d')}",
            "",
            "## Summary",
            description,
            "",
            "## Budget",
            f"${budget:,.2f}",
            "",
            "## Timeline",
            f"Duration: {duration} days",
            "",
            "## Objectives"
        ]
        
        if objectives:
            for obj in objectives:
                content.append(f"- {obj}")
        
        content.extend([
            "",
            "## Dependencies"
        ])
        
        if dependencies:
            for dep in dependencies:
                content.append(f"- {dep}")
        
        content.extend([
            "",
            "## Success Metrics",
            "- [ ] Deliverable 1",
            "- [ ] Deliverable 2",
            "",
            "## Risk Assessment",
            "- Risk 1: Mitigation strategy",
            "- Risk 2: Mitigation strategy"
        ])
        
        # Write to file
        proposal_path = self.proposals_dir / filename
        proposal_path.write_text('\n'.join(content))
        return filename

def generate_deployment_proposals():
    generator = ProposalGenerator('c:/Users/ASUS/CascadeProjects/SKENAI')
    
    # Define series
    FOUNDATION = "F1"  # Foundation Series
    CORE_DEV = "C1"   # Core Development Series
    INT_TEST = "I1"   # Integration & Testing Series
    LAUNCH = "L1"     # Launch Series
    
    # Genesis Track Proposals
    proposals = [
        # Foundation Series
        {
            "track": "G", "level": 0,
            "title": "Development Environment Setup",
            "description": "Setup and configuration of development environment including version control, CI/CD, and code quality tools.",
            "budget": 8000, "duration": 14,
            "series": FOUNDATION,
            "objectives": ["Setup Git repositories", "Configure CI/CD pipeline", "Install code quality tools"]
        },
        {
            "track": "G", "level": 1,
            "title": "Base Agent Architecture Implementation",
            "description": "Implementation of core agent communication protocols and state management.",
            "budget": 10000, "duration": 21,
            "series": FOUNDATION
        },
        
        # Fractal Track Proposals
        {
            "track": "F", "level": 0,
            "title": "Learning Models Foundation",
            "description": "Implementation of base learning models and pattern recognition systems.",
            "budget": 9500, "duration": 14,
            "series": CORE_DEV
        },
        {
            "track": "F", "level": 1,
            "title": "Adaptation Mechanisms Development",
            "description": "Development of dynamic weight adjustment and performance optimization systems.",
            "budget": 9000, "duration": 14,
            "series": CORE_DEV
        },
        
        # Options Track Proposals
        {
            "track": "O", "level": 0,
            "title": "Exchange Connectivity Module",
            "description": "Development of exchange API integration and order management systems.",
            "budget": 8500, "duration": 14,
            "series": CORE_DEV
        },
        {
            "track": "O", "level": 1,
            "title": "Risk Management System",
            "description": "Implementation of risk calculation and stop-loss mechanisms.",
            "budget": 9500, "duration": 21,
            "series": CORE_DEV
        },
        
        # Research Track Proposals
        {
            "track": "R", "level": 0,
            "title": "Market Analysis Framework",
            "description": "Development of technical and fundamental analysis tools.",
            "budget": 7500, "duration": 14,
            "series": CORE_DEV
        },
        {
            "track": "R", "level": 1,
            "title": "Performance Metrics System",
            "description": "Implementation of KPI tracking and reporting systems.",
            "budget": 6500, "duration": 14,
            "series": INT_TEST
        },
        
        # Community Track Proposals
        {
            "track": "C", "level": 0,
            "title": "Web Platform Development",
            "description": "Development of community web interface and API portal.",
            "budget": 10000, "duration": 21,
            "series": LAUNCH
        },
        {
            "track": "C", "level": 1,
            "title": "Community Tools Implementation",
            "description": "Development of forums, feedback systems, and support infrastructure.",
            "budget": 8500, "duration": 14,
            "series": LAUNCH
        },
        
        # Encyclic Track Proposals
        {
            "track": "E", "level": 0,
            "title": "Documentation System Setup",
            "description": "Implementation of documentation framework and initial content structure.",
            "budget": 5500, "duration": 7,
            "series": FOUNDATION
        },
        {
            "track": "E", "level": 1,
            "title": "Knowledge Base Development",
            "description": "Development of searchable knowledge base and training resources.",
            "budget": 7500, "duration": 14,
            "series": INT_TEST
        }
    ]
    
    # Generate all proposals
    generated = []
    for proposal in proposals:
        filename = generator.create_proposal(**proposal)
        generated.append({
            "filename": filename,
            "track": proposal["track"],
            "level": proposal["level"],
            "series": proposal["series"],
            "budget": proposal["budget"]
        })
    
    # Print summary
    print("\nProposal Generation Summary:")
    print("=" * 80)
    
    series_totals = {}
    track_totals = {}
    
    for prop in generated:
        series_totals[prop["series"]] = series_totals.get(prop["series"], 0) + prop["budget"]
        track_totals[prop["track"]] = track_totals.get(prop["track"], 0) + prop["budget"]
        print(f"Created: {prop['filename']}")
    
    print("\nSeries Totals:")
    for series, total in series_totals.items():
        print(f"{series}: ${total:,.2f}")
    
    print("\nTrack Totals:")
    for track, total in track_totals.items():
        print(f"{track}: ${total:,.2f}")

if __name__ == "__main__":
    generate_deployment_proposals()
