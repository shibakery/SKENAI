from pathlib import Path
from proposal_structure import ProposalStructure
import shutil
import re
from datetime import datetime

def get_sequence_number(filename):
    match = re.search(r'(\d{3})', filename)
    return match.group(1) if match else '000'

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
        
        # Get sequence number
        sequence = get_sequence_number(migration['old_name'])
        
        # Create metadata section
        today = datetime.now().strftime('%Y-%m-%d')
        metadata = [
            "## Metadata",
            f"- Track: {structure.TRACK_MAPPING[migration['track']]}",
            f"- Level: L{migration['level']}",
            f"- Sequence: {sequence}",
            "- Status: Active",
            f"- Created: {today}",
            f"- Last Updated: {today}",
            "",
            "## Mycelial Properties",
            "### Parent Proposal",
            "- ID: None",
            "- Relationship: Root proposal",
            "",
            "### Sub-Proposals",
            "- None yet",
            "",
            "### Cross-Track Connections",
            "- To be established",
            ""
        ]
        
        metadata_text = "\n".join(metadata)
        
        # Add metadata after first heading if it exists
        if '# ' in content:
            parts = content.split('# ', 1)
            new_content = f"# {parts[1].strip()}\n\n{metadata_text}\n"
        else:
            new_content = f"{metadata_text}\n{content}"
        
        # Backup original file
        print(f"Backing up: {migration['old_name']} -> backup/")
        shutil.copy2(old_path, backup_path)
        
        # Write new file
        print(f"Creating: {migration['new_name']}")
        new_path.write_text(new_content, encoding='utf-8')
        
        # Remove old file
        print(f"Removing: {migration['old_name']}")
        old_path.unlink()
        
        print(f"Successfully migrated: {migration['old_name']} -> {migration['new_name']}")
        print("-" * 80)

if __name__ == "__main__":
    print("Starting proposal migration...")
    print("=" * 80)
    migrate_proposals()
    print("=" * 80)
    print("Migration completed successfully!")
