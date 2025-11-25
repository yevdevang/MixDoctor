#!/bin/bash

# Script to remove all print statements from Swift files
# This will remove lines that contain print( statements

echo "🧹 Removing all print statements from Swift files..."

# Find all Swift files and remove print statements
find . -name "*.swift" -type f | while read -r file; do
    # Count print statements before
    before=$(grep -c "print(" "$file" 2>/dev/null || echo "0")
    
    if [ "$before" -gt 0 ]; then
        echo "Processing: $file ($before print statements)"
        
        # Create a backup
        cp "$file" "$file.backup"
        
        # Remove lines containing print( statements
        # This handles single-line and multi-line print statements
        sed -i '' '/print(/d' "$file"
        
        # Count print statements after
        after=$(grep -c "print(" "$file" 2>/dev/null || echo "0")
        removed=$((before - after))
        
        echo "  ✅ Removed $removed print statements"
    fi
done

echo ""
echo "✨ Done! All print statements have been removed."
echo "💾 Backup files created with .backup extension"
echo ""
echo "To restore backups if needed:"
echo "  find . -name '*.swift.backup' -exec bash -c 'mv \"\$0\" \"\${0%.backup}\"' {} \\;"
