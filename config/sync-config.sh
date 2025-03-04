#!/bin/bash
#
# Usage:
#   # (Default: operating on symlinked config files in the version-controlled repository)
#   ./sync-config.sh              # Copy from version-controlled file to symlink target
#   ./sync-config.sh --reverse    # Copy from symlink target to version-controlled file
#
#   # (Installer mode: operating on a complete config tree from a new installation)
#   ./sync-config.sh --installer              # Copy from version-controlled file to installer config file
#   ./sync-config.sh --installer --reverse    # Copy from installer config file to version-controlled file
#
#   # Dry-run mode: print what would be done without copying files
#   ./sync-config.sh --dry-run
#   ./sync-config.sh --installer --reverse --dry-run
#
# Explanation:
# -------------
# There are two scenarios:
#
# 1. **Repository Mode (default)**
#    Inside your version-controlled config repository (which lives under
#    /data/dspace-angular-dspace-8.1/config) you have two sets of files:
#      - The version-controlled configuration files (e.g. authentication.cfg)
#      - Their corresponding “linked” files (e.g. authentication.linked.cfg) which
#        are symlinks pointing to the live installation’s config files.
#
#    In *forward mode* (default) the script copies the contents of the
#    version-controlled file (e.g. authentication.cfg) into the live configuration
#    file (the symlink target). In *reverse mode* (with --reverse) it copies the live
#    configuration’s content (the symlink target) back into the version-controlled file.
#
#    IMPORTANT: The file "authentication-oidc_backup.cfg" is not managed by this script.
#
# 2. **Installer Mode**
#    When you are synchronizing a new installation’s configuration tree (e.g.,
#    /data/DSpace-dspace-8.1/dspace/target/dspace-installer/config) with your
#    version-controlled configuration files (located at /data/dspace-angular-dspace-8.1/config),
#    the directory structures are different.
#
#    In installer mode this script finds a matching configuration file based on file name.
#    For each file in the installer tree, it searches recursively in the repository for a file
#    with the same base name and then copies in the chosen direction.
#
# Always ensure you have backups before running this script.
#

set -e

#############################
# Parse command-line options
#############################
INSTALLER_MODE=0
REVERSE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --installer)
      INSTALLER_MODE=1
      ;;
    --reverse)
      REVERSE=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

###########################################
# Installer Mode: Sync the complete config tree by matching file names
###########################################
if [ $INSTALLER_MODE -eq 1 ]; then
  # Define the location of the version-controlled configuration files.
  VC_CONFIG_DIR="/data/dspace-angular-dspace-8.1/config"
  if [ ! -d "$VC_CONFIG_DIR" ]; then
    echo "Error: Version-controlled config directory $VC_CONFIG_DIR does not exist."
    exit 1
  fi
  # Define the installer config directory.
  INSTALLER_CONFIG_DIR="/data/DSpace-dspace-8.1/dspace/config"

  # Confirmation step for installer sync mode.
  echo "-----------------------------------------"
  echo "Installer Configuration Synchronization (File Matching Mode)"
  echo "-----------------------------------------"
  if [ $REVERSE -eq 1 ]; then
    echo "Mode: Reverse (--reverse)"
    echo "Action: Replace the contents of the version-controlled configuration files"
    echo "with the contents of the installer configuration files."
    echo ""
    echo "  Version-Controlled Config: $VC_CONFIG_DIR"
    echo "  Installer Config:          $INSTALLER_CONFIG_DIR"
  else
    echo "Mode: Forward (default)"
    echo "Action: Replace the contents of the installer configuration files"
    echo "with the contents of the version-controlled configuration files."
    echo ""
    echo "  Version-Controlled Config: $VC_CONFIG_DIR"
    echo "  Installer Config:          $INSTALLER_CONFIG_DIR"
  fi
  if [ $DRY_RUN -eq 1 ]; then
    echo "DRY-RUN: No files will be copied."
  fi
  echo ""
  echo "IMPORTANT: Verify that you have backups and review changes (e.g. via 'git diff')."
  echo ""
  read -p "Proceed with the operation? (y/n): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation aborted."
    exit 0
  fi

  # For each file in the installer config tree, try to find a matching file in the repository by name.
  find "$INSTALLER_CONFIG_DIR" -type f -print0 | while IFS= read -r -d '' installer_file; do
    installer_basename=$(basename "$installer_file")
    # Search for a matching version-controlled file (by name) anywhere under VC_CONFIG_DIR.
    vc_file=$(find "$VC_CONFIG_DIR" -type f -name "$installer_basename" -print -quit)
    if [ -z "$vc_file" ]; then
      echo "Warning: No matching version-controlled file found for installer file '$installer_file' (basename: $installer_basename)."
      continue
    fi
    if [ $REVERSE -eq 1 ]; then
      # Reverse mode: update the version-controlled file from the installer file.
      if [ $DRY_RUN -eq 1 ]; then
        echo "[DRY RUN] Would update $vc_file from $installer_file"
      else
        cp "$installer_file" "$vc_file"
        echo "Updated $vc_file from $installer_file"
      fi
    else
      # Forward mode: update the installer file from the version-controlled file.
      if [ $DRY_RUN -eq 1 ]; then
        echo "[DRY RUN] Would update $installer_file from $vc_file"
      else
        cp "$vc_file" "$installer_file"
        echo "Updated $installer_file from $vc_file"
      fi
    fi
  done

###########################################
# Default Mode: Sync symlinked configuration files in the repository
###########################################
else
  # Ensure the script is being run from the expected version-controlled config directory.
  EXPECTED_DIR="/data/dspace-angular-dspace-8.1"
  if [[ ! "$PWD" =~ $EXPECTED_DIR ]]; then
    echo "Error: This script must be run inside the /data/dspace-angular-dspace-8.1 directory."
    exit 1
  fi
  if [[ "$(basename "$PWD")" != "config" ]]; then
    echo "Error: This script must be run inside the 'config/' directory."
    exit 1
  fi

  # Confirmation step for repository sync mode.
  echo "-----------------------------------------"
  echo "Repository Configuration Synchronization"
  echo "-----------------------------------------"
  if [ $REVERSE -eq 1 ]; then
    echo "Mode: Reverse (--reverse)"
    echo "Action: Replace the contents of your version-controlled configuration files"
    echo "with the contents of their corresponding symlinked configuration files."
    echo "This lets you review new configuration parameters via 'git diff' and then reconcile manually."
  else
    echo "Mode: Forward (default)"
    echo "Action: Copy the contents of your version-controlled configuration files"
    echo "into the files that your symlinked configuration files point to."
    echo "This is typically used when copying configurations to a new installation."
  fi
  if [ $DRY_RUN -eq 1 ]; then
    echo "DRY-RUN: No files will be copied."
  fi
  echo ""
  echo "IMPORTANT: The file 'authentication-oidc_backup.cfg' is not managed by this script."
  echo "It is in .gitignore and contains sensitive information. Do NOT change its name or commit it."
  echo ""
  read -p "Proceed with the operation? (y/n): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation aborted."
    exit 0
  fi

  # Process each symlinked configuration file (files with ".linked." in their names)
  find . -type l -name "*.linked.*" -print0 | while IFS= read -r -d '' linkfile; do
    # Derive the base (version-controlled) filename by removing the ".linked" part.
    basefile=$(echo "$linkfile" | sed 's/\.linked//')
    # Double-check that it’s a symlink.
    if [ ! -L "$linkfile" ]; then
      echo "Skipping $linkfile: not a symlink."
      continue
    fi
    # Get the symlink target.
    target=$(readlink "$linkfile")
    if [ $REVERSE -eq 1 ]; then
      # Reverse mode: update the version-controlled file from the symlink target.
      if [ -f "$target" ]; then
        if [ $DRY_RUN -eq 1 ]; then
          echo "[DRY RUN] Would update $basefile from $target"
        else
          cp "$target" "$basefile"
          echo "Updated $basefile from $target"
        fi
      else
        echo "Warning: target file $target does not exist. Skipping $linkfile."
      fi
    else
      # Forward mode: update the symlink target from the version-controlled file.
      if [ -f "$basefile" ]; then
        if [ $DRY_RUN -eq 1 ]; then
          echo "[DRY RUN] Would update $target from $basefile"
        else
          cp "$basefile" "$target"
          echo "Updated $target from $basefile"
        fi
      else
        echo "Warning: base file $basefile does not exist. Skipping $linkfile."
      fi
    fi
  done
fi

echo "-----------------------------------------"
echo "Configuration synchronization completed."
echo "-----------------------------------------"