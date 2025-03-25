#!/bin/bash

# Usage: ./sort_json5.sh input_file output_file
# Example: ./sort_json5.sh src/assets/i18n/en.json5 src/assets/i18n/en_sorted.json5

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 input_file output_file"
    exit 1
fi

input_file=$1
output_file=$2

# Create temporary files for processing
temp_file=$(mktemp)
sorted_file=$(mktemp)

# Extract the content, keeping only lines with key-value pairs
grep -E '^\s*"[^"]+":' "$input_file" > "$temp_file"

# Sort by everything before the first period, using awk to create a sortable key
# Format: <everything before first period>|<original key>|<full line>
awk -F'"' '{
    key=$2;  # Extract the key between first set of quotes
    pos=index(key, ".");
    if (pos > 0) {
        sort_key=substr(key, 1, pos-1) "|" key;
    } else {
        sort_key=key "|" key;  # If no period, use full key
    }
    print sort_key "|" $0;
}' "$temp_file" | sort | cut -d'|' -f3- > "$sorted_file"

# Start the output file with an opening brace
echo "{" > "$output_file"

# Process each line: add two spaces of indentation and a blank line after each entry
while IFS= read -r line; do
    # Remove any trailing commas
    line=${line%,}
    # Add the comma back (except for the last line, which we'll handle later)
    echo "  $line," >> "$output_file"
    # Add a blank line after each entry
    echo "" >> "$output_file"
done < "$sorted_file"

# Remove the trailing comma from the last entry
sed -i '$s/,$//' "$output_file"

# Add the closing brace
echo "}" >> "$output_file"

# Clean up
rm "$temp_file" "$sorted_file"

echo "Sorting and formatting complete. Output saved to $output_file"