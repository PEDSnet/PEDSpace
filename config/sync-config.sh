#!/bin/bash
#
# Usage:
#   ./sync-config.sh          # copy from version-controlled file to symlink target
#   ./sync-config.sh --reverse  # copy from symlink target to version-controlled file
#
# This script finds files with ".linked" in their names (e.g. authentication.linked.cfg)
# and determines the corresponding version-controlled file (authentication.cfg).
# It then either copies the content of the version-controlled file to the file that the
# symlink points to (default) or, with --reverse, copies the symlink target's content
# back to the version-controlled file.
#
# IMPORTANT:
#  - When running in reverse mode, the script replaces the contents of your version-controlled
#    configuration files with the contents of the symlinked configuration files.
#    This lets you use 'git diff' (e.g. in VSCode) to see new configuration parameters.
#  - There is one non-linked, non-version-controlled configuration file:
#       authentication-oidc_backup.cfg
#    This file is in .gitignore and contains sensitive information. Do NOT change its name
#    or commit it to Git.
#
# NOTE: Make sure you have proper backups before running the script.

set -e

# Ensure script is running inside the expected directory
EXPECTED_DIR="/data/dspace-angular-dspace-8.0"
if [[ ! "$PWD" =~ $EXPECTED_DIR ]]; then
  echo "Error: This script must be run inside the /data/dspace-angular-dspace-8.0 directory."
  exit 1
fi

# Ensure we are in the "config" directory within the project
if [[ "$(basename "$PWD")" != "config" ]]; then
  echo "Error: This script must be run inside the 'config/' directory."
  exit 1
fi

# Check for reverse mode
REVERSE=0
if [[ "$1" == "--reverse" ]]; then
  REVERSE=1
fi

# Confirmation step: explain what will happen and prompt user to proceed.
echo "-----------------------------------------"
echo "Configuration Synchronization Script"
echo "-----------------------------------------"
if [ $REVERSE -eq 1 ]; then
  echo "Mode: Reverse (--reverse)"
  echo "Action: Replace the contents of your version-controlled configuration files"
  echo "with the contents of their corresponding symlinked configuration files."
  echo "This allows you to review the differences (e.g. new configuration parameters)"
  echo "using 'git diff' and then manually reconcile the changes."
else
  echo "Mode: Forward (default)"
  echo "Action: Copy the contents of your version-controlled configuration files"
  echo "into the files that your symlinked configuration files point to."
  echo "This is typically used when copying configurations to the backend or to a"
  echo "new installation."
fi
echo ""
echo "IMPORTANT: The file 'authentication-oidc_backup.cfg' is not managed by this script."
echo "It is in .gitignore and contains sensitive information. Do NOT modify its name or commit it."
echo ""
read -p "Proceed with the operation? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operation aborted."
  exit 0
fi

# Process each symlinked configuration file
find . -type l -name "*.linked.*" -print0 | while IFS= read -r -d '' linkfile; do
  # Derive the base (version-controlled) file name by removing the ".linked" part.
  basefile=$(echo "$linkfile" | sed 's/\.linked//')

  # Verify that we have a symlink (should always be true)
  if [ ! -L "$linkfile" ]; then
    echo "Skipping $linkfile: not a symlink."
    continue
  fi

  # Get the symlink target.
  target=$(readlink "$linkfile")

  if [ $REVERSE -eq 1 ]; then
    # Reverse mode: update the version-controlled file from the symlink target.
    if [ -f "$target" ]; then
      cp "$target" "$basefile"
      echo "Updated $basefile from $target"
    else
      echo "Warning: target file $target does not exist. Skipping $linkfile."
    fi
  else
    # Default mode: update the symlink target from the version-controlled file.
    if [ -f "$basefile" ]; then
      cp "$basefile" "$target"
      echo "Updated $target from $basefile"
    else
      echo "Warning: base file $basefile does not exist. Skipping $linkfile."
    fi
  fi
done
