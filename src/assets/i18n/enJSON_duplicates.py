#!/usr/bin/env python3

import json
import argparse
import sys
import re
from typing import Dict, Tuple, List, Any

def parse_json5(filepath: str) -> Dict[str, str]:
    """
    Parse a JSON5 file into a dictionary.
    Handles the specific format with keys and values on separate lines.
    Preserves Angular template syntax and HTML tags.
    """
    result = {}
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove comments
    content = re.sub(r'//.*?\n', '\n', content)
    
    # Parse key-value pairs with a more careful approach
    # This pattern looks for "key": "value" pairs but carefully handles escaped quotes
    lines = content.split('\n')
    current_key = None
    current_value = None
    
    for line in lines:
        # Skip empty lines and lines that are just brackets or whitespace
        line = line.strip()
        if not line or line in ['{', '}']:
            continue
            
        # Look for key-value pairs
        key_match = re.match(r'"([^"]+)":\s*"(.*)"(?:,)?$', line)
        if key_match:
            key = key_match.group(1)
            value = key_match.group(2)
            
            if key in result:
                # Mark as duplicate by storing both values
                if isinstance(result[key], list):
                    result[key].append(value)
                else:
                    result[key] = [result[key], value]
            else:
                result[key] = value
    
    return result

def find_duplicates(data: Dict[str, Any]) -> Dict[str, List[str]]:
    """
    Find all duplicate keys in the dictionary.
    Returns a dictionary of key -> [values] for keys with multiple values.
    """
    return {k: v for k, v in data.items() if isinstance(v, list)}

def resolve_duplicates(data: Dict[str, Any]) -> Dict[str, str]:
    """
    Interactively resolve duplicate keys in the dictionary.
    Returns a dictionary with resolved values.
    """
    duplicates = find_duplicates(data)
    resolved_data = {k: v for k, v in data.items() if not isinstance(v, list)}
    
    if not duplicates:
        print("No duplicates found in the file.")
        return data
    
    print(f"Found {len(duplicates)} duplicate keys.")
    
    for i, (key, values) in enumerate(duplicates.items(), 1):
        print(f"\nDuplicate {i}/{len(duplicates)}: '{key}'")
        print("-" * 80)
        for j, value in enumerate(values, 1):
            print(f"Option {j}: \"{value}\"")
        
        while True:
            choice = input(f"Choose which value to keep (1-{len(values)}), or 's' to skip: ")
            if choice.lower() == 's':
                print(f"Skipping '{key}'")
                resolved_data[key] = values[0]  # Default to first value
                break
            try:
                choice_idx = int(choice) - 1
                if 0 <= choice_idx < len(values):
                    resolved_data[key] = values[choice_idx]
                    print(f"Selected option {choice} for '{key}'")
                    break
                else:
                    print(f"Invalid choice. Please enter a number between 1 and {len(values)}.")
            except ValueError:
                print("Invalid input. Please try again.")
    
    return resolved_data

def write_json5(data: Dict[str, str], output_file: str) -> None:
    """
    Write the resolved data back to a JSON5 file in the same format.
    Properly preserves Angular template syntax and HTML tags.
    """
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("{\n\n")
        for key, value in sorted(data.items()):
            # Escape any quotes within the value - only needed if they're not already escaped
            escaped_value = value.replace('"', '\\"') if not value.find('\\"') >= 0 else value
            # Replace back any double-escaped quotes to avoid over-escaping
            escaped_value = escaped_value.replace('\\\\"', '\\"')
            
            f.write(f'  "{key}": "{escaped_value}",\n\n')
        
        # Remove the last comma and add closing brace if there are any keys
        if data:
            f.seek(f.tell() - 3, 0)
            f.write("\n\n}\n")
        else:
            f.write("}\n")
    
    print(f"Result saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Resolve duplicate keys in JSON5 files interactively.')
    parser.add_argument('input_file', help='Input JSON5 file path')
    parser.add_argument('--output', '-o', help='Output file path (default: resolved_output.json5)', 
                        default='resolved_output.json5')
    
    args = parser.parse_args()
    
    try:
        # Parse JSON5 file
        data = parse_json5(args.input_file)
        
        # Resolve duplicates
        resolved_data = resolve_duplicates(data)
        
        # Write resolved data back to file
        write_json5(resolved_data, args.output)
        
    except FileNotFoundError:
        print(f"Error: File {args.input_file} not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(0)

if __name__ == "__main__":
    main()