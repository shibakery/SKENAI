from pathlib import Path
import re
from datetime import datetime
from typing import Dict, List, Tuple

class ProposalStructure:
    TRACK_MAPPING = {
        'G': 'Genesis',
        'F': 'Fractal',
        'O': 'Options',
        'R': 'Research',
        'C': 'Community',
        'E': 'Encyclic'
    }

    def __init__(self, base_path: str):
        self.base_path = Path(base_path)
        self.proposals_path = self.base_path / 'governance' / 'proposals'

    def parse_existing_proposal(self, filename: str) -> Dict:
        """Parse existing proposal filename and content"""
        pattern = r'(\d{3})_(.+)\.md'
        match = re.match(pattern, filename)
        if not match:
            return None
        
        number, name = match.groups()
        return {
            'old_number': number,
            'name': name,
            'filename': filename
        }

    def generate_new_name(self, proposal: Dict, track: str, level: int) -> str:
        """Generate new filename based on mycelial structure"""
        sequence = proposal['old_number'].zfill(3)
        name = re.sub(r'[^a-z0-9]+', '-', proposal['name'].lower())
        return f"{track}-L{level}-{sequence}-{name}.md"

    def create_proposal_template(self, track: str, level: int, 
                               sequence: str, name: str, 
                               description: str = "") -> str:
        """Create a new proposal template"""
        date = datetime.now().strftime("%Y-%m-%d")
        template = f"""# {self.TRACK_MAPPING[track]} Track Proposal

## Metadata
- Track: {self.TRACK_MAPPING[track]}
- Level: L{level}
- Sequence: {sequence}
- Date: {date}
- Status: Draft

## Title
{name.replace('-', ' ').title()}

## Description
{description}

## Objectives
- 

## Success Metrics
- 

## Dependencies
- 

## Timeline
- 

## Resources Required
- 

## Risk Assessment
- 

## References
- 
"""
        return template

    def suggest_track_mapping(self, old_name: str) -> Tuple[str, int]:
        """Suggest track and level based on old proposal name"""
        name_lower = old_name.lower()
        
        track_hints = {
            'genesis': ('G', 0),
            'sbx': ('G', 1),
            'options': ('O', 0),
            'compendium': ('E', 0),  
            'archive': ('E', 0),     
            'racing': ('E', 0)       
        }
        
        for hint, (track, level) in track_hints.items():
            if hint in name_lower:
                return track, level
                
        return 'G', 0  # Default to Genesis track, level 0

    def migrate_proposals(self) -> List[Dict]:
        """Migrate existing proposals to new structure"""
        migrations = []
        
        for file in self.proposals_path.glob('*.md'):
            if file.name == 'README.md':
                continue
                
            proposal = self.parse_existing_proposal(file.name)
            if not proposal:
                continue
                
            track, level = self.suggest_track_mapping(proposal['name'])
            new_name = self.generate_new_name(proposal, track, level)
            
            migrations.append({
                'old_name': file.name,
                'new_name': new_name,
                'track': track,
                'level': level
            })
            
        return migrations

def main():
    structure = ProposalStructure('c:/Users/ASUS/CascadeProjects/SKENAI')
    migrations = structure.migrate_proposals()
    
    print("Proposed Migrations:")
    print("-" * 80)
    for migration in migrations:
        print(f"Old: {migration['old_name']}")
        print(f"New: {migration['new_name']}")
        print(f"Track: {structure.TRACK_MAPPING[migration['track']]}, Level: {migration['level']}")
        print("-" * 80)
        
    print("\nExample New Proposal Template:")
    print("=" * 80)
    example = structure.create_proposal_template(
        track='G',
        level=0,
        sequence='007',
        name='example-proposal',
        description='This is an example proposal description.'
    )
    print(example)

if __name__ == "__main__":
    main()
