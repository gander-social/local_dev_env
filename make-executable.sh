#!/bin/bash

# Make all shell scripts executable
echo "🔧 Making all shell scripts executable..."
echo "======================================"

# Make all .sh files in current directory and subdirectories executable
find . -name "*.sh" -type f -exec chmod +x {} \;

# List the scripts that were made executable
echo ""
echo "✅ Made the following scripts executable:"
echo ""
find . -name "*.sh" -type f | while read script; do
    echo "  • $script"
done

echo ""
echo "🎉 All shell scripts are now executable!"