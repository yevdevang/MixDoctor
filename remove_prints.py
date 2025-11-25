#!/usr/bin/env python3
"""
Script to remove all print statements from Swift files
"""

import os
import re
from pathlib import Path

def remove_print_statements(file_path):
    """Remove all print statements from a Swift file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Track print statements
    new_lines = []
    in_print = False
    paren_count = 0
    removed_count = 0
    
    for line in lines:
        # Check if line contains print(
        if 'print(' in line and not in_print:
            # Count parentheses to handle multi-line prints
            paren_count = line.count('(') - line.count(')')
            if paren_count == 0:
                # Single line print, skip it
                removed_count += 1
                continue
            else:
                # Multi-line print starts
                in_print = True
                removed_count += 1
                continue
        elif in_print:
            # We're in a multi-line print statement
            paren_count += line.count('(') - line.count(')')
            if paren_count <= 0:
                # Multi-line print ends
                in_print = False
            continue
        
        new_lines.append(line)
    
    return new_lines, removed_count

def main():
    """Main function to process all Swift files"""
    root_dir = Path('.')
    swift_files = list(root_dir.rglob('*.swift'))
    
    total_removed = 0
    files_modified = 0
    
    print("🧹 Removing all print statements from Swift files...\n")
    
    for swift_file in swift_files:
        # Skip backup files
        if '.backup' in str(swift_file):
            continue
            
        try:
            new_lines, removed_count = remove_print_statements(swift_file)
            
            if removed_count > 0:
                # Create backup
                backup_path = str(swift_file) + '.backup'
                with open(backup_path, 'w', encoding='utf-8') as f:
                    with open(swift_file, 'r', encoding='utf-8') as original:
                        f.write(original.read())
                
                # Write modified content
                with open(swift_file, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)
                
                print(f"✅ {swift_file}: Removed {removed_count} print statement(s)")
                total_removed += removed_count
                files_modified += 1
        
        except Exception as e:
            print(f"❌ Error processing {swift_file}: {e}")
    
    print(f"\n✨ Done!")
    print(f"📊 Modified {files_modified} file(s)")
    print(f"🗑️  Removed {total_removed} print statement(s)")
    print(f"💾 Backup files created with .backup extension")

if __name__ == '__main__':
    main()
