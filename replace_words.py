import re

def replace_words(file_path):
    # Read the contents of the file
    with open(file_path, 'r') as file:
        lines = file.readlines()

    # Function to perform the replacements
    def replace_after_colon(text):
        # Split text by ':'
        parts = text.split(':', 1)
        if len(parts) < 2:
            return text

        # The text after the colon
        after_colon = parts[1]

        # Replace 'Collection' with 'Domain' first
        after_colon = re.sub(r'(?<!\{)\bCollection\b(?!\})', 'Domain', after_colon)
        after_colon = re.sub(r'(?<!\{)\bcollection\b(?!\})', 'domain', after_colon)

        # Then replace 'Community' with 'Collection'
        after_colon = re.sub(r'(?<!\{)\bCommunity\b(?!\})', 'Collection', after_colon)
        after_colon = re.sub(r'(?<!\{)\bcommunity\b(?!\})', 'collection', after_colon)
        
        after_colon = re.sub(r'(?<!\{)\bCommunities\b(?!\})', 'Collections', after_colon)
        after_colon = re.sub(r'(?<!\{)\bcommunities\b(?!\})', 'collections', after_colon)

        # Reconstruct the line
        return parts[0] + ':' + after_colon

    # Perform replacements for each line
    updated_lines = [replace_after_colon(line) for line in lines]

    # Write the updated contents back to the file
    with open(file_path, 'w') as file:
        file.writelines(updated_lines)

# Specify the path to your file
file_path = '/opt/dspace-angular-dspace-7.6.1/src/assets/i18n/en.json5'
replace_words(file_path)
