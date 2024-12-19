from pathlib import Path
from proposal_structure import ProposalStructure
import shutil
import re

def migrate_proposals():
    structure = ProposalStructure('c:/Users/ASUS/CascadeProjects/SKENAI')
    proposals_dir = structure.proposals_path
    migrations = structure.migrate_proposals()
    
    # Create backup directory
    backup_dir = proposals_dir / 'backup'
    backup_dir.mkdir(exist_ok=True)
    
    # Perform migrations
    for migration in migrations:
        old_path = proposals_dir / migration['old_name']
        new_path = proposals_dir / migration['new_name']
        backup_path = backup_dir / migration['old_name']
        
        # Read existing content
        content = old_path.read_text(encoding='utf-8')
        
        # Update content with new metadata
        metadata = f"""## Metadata
- Track: {structure.TRACK_MAPPING[migration['track']]}
- Level: L{migration['level']}
- Sequence: {re.search(r'\d{3}', migration['old_name']).group()}
- Status: Active
- Created: 2024-12-19
"""
        
        # Add metadata after first heading if it exists
        if '# ' in content:
            parts = content.split('# ', 1)
            content = f"# {parts[1].strip()}\n\n{metadata}\n"
        else:
            content = f"{metadata}\n{content}"
        
        # Backup original file
        shutil.copy2(old_path, backup_path)
        
        # Write new file
        new_path.write_text(content, encoding='utf-8')
        
        # Remove old file
        old_path.unlink()
        
        print(f"Migrated: {migration['old_name']} -> {migration['new_name']}")

if __name__ == "__main__":
    migrate_proposals()
