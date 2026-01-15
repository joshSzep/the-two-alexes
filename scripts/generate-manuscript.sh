#!/bin/bash

# Generate MANUSCRIPT.md from all chapter files
# Run from the repository root: ./scripts/generate-manuscript.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$REPO_ROOT/MANUSCRIPT.md"
CHAPTERS_DIR="$REPO_ROOT/chapters"

# Start the manuscript
cat > "$OUTPUT" << 'EOF'
# The Two Alexes

Joshua Szepietowski

EOF

# Define acts in order
declare -a ACTS=(
    "act-1-the-aftermath|I|THE AFTERMATH"
    "act-2-before-the-truth|II|BEFORE THE TRUTH"
    "act-3-the-moment|III|THE MOMENT"
    "act-4-the-present|IV|THE PRESENT"
    "act-5-the-choice|V|THE CHOICE"
)

first_chapter=true

for act_info in "${ACTS[@]}"; do
    IFS='|' read -r act_dir act_num act_title <<< "$act_info"
    
    act_path="$CHAPTERS_DIR/$act_dir"
    
    if [[ ! -d "$act_path" ]]; then
        echo "Warning: Act directory not found: $act_path" >&2
        continue
    fi
    
    # Add act heading
    echo "## ACT $act_num — $act_title" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    
    # Process each chapter file in the act (sorted)
    for chapter_file in "$act_path"/*.md; do
        if [[ ! -f "$chapter_file" ]]; then
            continue
        fi
        
        # Add separator between chapters (but not before the first one)
        if [[ "$first_chapter" == true ]]; then
            first_chapter=false
        else
            echo "---" >> "$OUTPUT"
            echo "" >> "$OUTPUT"
        fi
        
        # Read the chapter content and transform the heading
        # Change "# Chapter" to "### Chapter"
        sed 's/^# Chapter/### Chapter/' "$chapter_file" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    done
done

echo "Generated: $OUTPUT"
