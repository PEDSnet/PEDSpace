#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 [-s|--source <source_dir>] [-d|--destination <dest_dir>]"
    echo "  -s, --source        Source directory path (default: current directory)"
    echo "  -d, --destination   Destination directory path (required)"
    echo "  -h, --help          Display this help message"
}

# Initialize variables
SRC_DIR=""
DEST_DIR=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SRC_DIR="$2"
            shift 2
            ;;
        -d|--destination)
            DEST_DIR="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
done

# Set default source directory if not provided
if [ -z "$SRC_DIR" ]; then
    SRC_DIR="$(pwd)/dist"
else
    SRC_DIR="$(realpath "$SRC_DIR")/dist"
fi

# Check if destination directory is provided
if [ -z "$DEST_DIR" ]; then
    echo "Error: Destination directory is required."
    print_usage
    exit 1
fi

# Resolve full paths
DEST_DIR=$(realpath "$DEST_DIR")

# Check if source directory exists
if [ ! -d "$SRC_DIR" ]; then
    echo "Error: Source directory $SRC_DIR does not exist."
    exit 1
fi

# Create timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Backup existing dist directory if it exists
if [ -d "$DEST_DIR/dist" ]; then
    mv "$DEST_DIR/dist" "$DEST_DIR/dist.$TIMESTAMP.bak"
    echo "Existing dist directory backed up to $DEST_DIR/dist.$TIMESTAMP.bak"
fi

# Copy dist directory from source to destination
cp -r "$SRC_DIR" "$DEST_DIR/dist"

if [ $? -eq 0 ]; then
    echo "Successfully copied $SRC_DIR to $DEST_DIR"
else
    echo "Error: Failed to copy $SRC_DIR to $DEST_DIR"
    exit 1
fi

echo "Operation completed successfully."
