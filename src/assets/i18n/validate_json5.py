#!/usr/bin/env python3

import json
import re
import sys

def parse_json5_with_duplicates(filepath):
    """Parse a JSON5 file and return a dictionary that preserves duplicate keys."""
    result = {}
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove comments
    content = re.sub(r'//.*?\n', '\n', content)
    
    # Parse key-value pairs
    lines = content.split('\n')
    
    for line in lines:
        line = line.strip()
        if not line or line in ['{', '}']:
            continue
            
        key_match = re.match(r'"([^"]+)":\s*"(.*)"(?:,)?$', line)
        if key_match:
            key = key_match.group(1)
            value = key_match.group(2)
            
            if key in result:
                if isinstance(result[key], list):
                    result[key].append(value)
                else:
                    result[key] = [result[key], value]
            else:
                result[key] = value
    
    return result

def compare_files(original_file, cleaned_file):
    """Compare original and cleaned files considering duplicates."""
    original_data = parse_json5_with_duplicates(original_file)
    cleaned_data = parse_json5_with_duplicates(cleaned_file)
    
    # Identify duplicate keys in original file
    duplicate_keys = {k for k, v in original_data.items() if isinstance(v, list)}
    
    # Check for missing keys
    missing_keys = set()
    for key in original_data:
        if key not in cleaned_data:
            missing_keys.add(key)
    
    # Check for keys with changed values (considering duplicates)
    changed_values = {}
    for key in original_data:
        if key in cleaned_data and key not in duplicate_keys:
            if original_data[key] != cleaned_data[key]:
                changed_values[key] = {
                    'original': original_data[key],
                    'cleaned': cleaned_data[key]
                }
    
    # Check if values in cleaned file match one of the duplicate values
    invalid_resolutions = {}
    for key in duplicate_keys:
        if key in cleaned_data:
            cleaned_value = cleaned_data[key]
            original_values = original_data[key] if isinstance(original_data[key], list) else [original_data[key]]
            
            if cleaned_value not in original_values:
                invalid_resolutions[key] = {
                    'original_options': original_values,
                    'cleaned': cleaned_value
                }
    
    # Print results
    print(f"Total unique keys in original file: {len(original_data)}")
    print(f"Duplicate keys in original file: {len(duplicate_keys)}")
    print(f"Total keys in cleaned file: {len(cleaned_data)}")
    
    if missing_keys:
        print(f"\n⚠️ Found {len(missing_keys)} keys missing from cleaned file:")
        for key in sorted(missing_keys):
            print(f"  - {key}")
    else:
        print("\n✅ All keys from the original file are present in the cleaned file")
    
    if changed_values:
        print(f"\n⚠️ Found {len(changed_values)} non-duplicate keys with changed values:")
        for key, values in changed_values.items():
            print(f"  - {key}:")
            print(f"    Original: \"{values['original']}\"")
            print(f"    Cleaned:  \"{values['cleaned']}\"")
    else:
        print("✅ All non-duplicate values preserved correctly")
    
    if invalid_resolutions:
        print(f"\n⚠️ Found {len(invalid_resolutions)} duplicate keys with values that don't match any original option:")
        for key, values in invalid_resolutions.items():
            print(f"  - {key}:")
            print(f"    Original options: {values['original_options']}")
            print(f"    Cleaned value: \"{values['cleaned']}\"")
    else:
        print("✅ All resolved duplicates match one of the original values")
    
    # Overall result
    if not missing_keys and not changed_values and not invalid_resolutions:
        print("\n✅ VALIDATION PASSED: All content preserved correctly")
    else:
        print("\n❌ VALIDATION FAILED: Found issues with the cleaned file")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python validate_json5.py original.json5 cleaned.json5")
        sys.exit(1)
    
    original_file = sys.argv[1]
    cleaned_file = sys.argv[2]
    
    compare_files(original_file, cleaned_file)