#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 [-s|--source <source_dir>] [-d|--destination <dest_dir>] [-b|--build]"
    echo "  -s, --source        Source directory path (default: current directory)"
    echo "  -d, --destination   Destination directory path (required)"
    echo "  -b, --build         Build production version before copying"
    echo "  -h, --help          Display this help message"
}

# Initialize variables
SRC_DIR=""
DEST_DIR=""
BUILD_PROD=false

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
        -b|--build)
            BUILD_PROD=true
            shift
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
    SRC_DIR="$(pwd)"
else
    SRC_DIR="$(realpath "$SRC_DIR")"
fi

# Check if destination directory is provided
if [ -z "$DEST_DIR" ]; then
    echo "Error: Destination directory is required."
    print_usage
    exit 1
fi

# Resolve full paths
DEST_DIR=$(realpath "$DEST_DIR")

# Build production version if requested
if [ "$BUILD_PROD" = true ]; then
    echo "Building production version..."
    cd "$SRC_DIR"
    yarn build:prod
    if [ $? -ne 0 ]; then
        echo "Error: Build failed."
        exit 1
    fi
    echo "Build completed successfully."
fi

# Set the dist source path
DIST_SRC="$SRC_DIR/dist"

# Check if source dist directory exists
if [ ! -d "$DIST_SRC" ]; then
    echo "Error: Source dist directory $DIST_SRC does not exist."
    if [ "$BUILD_PROD" = false ]; then
        echo "Hint: Try running with -b/--build to build the production version first."
    fi
    exit 1
fi

# Create timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Stage the new dist next to the destination so the swap-in is a fast rename, not a slow copy
STAGING_DIR="$DEST_DIR/dist.new.$TIMESTAMP"
echo "Copying $DIST_SRC to $STAGING_DIR..."
cp -r "$DIST_SRC" "$STAGING_DIR"

if [ $? -ne 0 ]; then
    echo "Error: Failed to copy $DIST_SRC to $STAGING_DIR"
    rm -rf "$STAGING_DIR"
    exit 1
fi

# Swap in the staged dist with two renames, minimizing the time the live site is missing dist
if [ -d "$DEST_DIR/dist" ]; then
    mv "$DEST_DIR/dist" "$DEST_DIR/dist.$TIMESTAMP.bak"
    echo "Existing dist directory backed up to $DEST_DIR/dist.$TIMESTAMP.bak"
fi

mv "$STAGING_DIR" "$DEST_DIR/dist"

if [ $? -eq 0 ]; then
    echo "Successfully installed new dist at $DEST_DIR/dist"
else
    echo "Error: Failed to move $STAGING_DIR to $DEST_DIR/dist"
    exit 1
fi

echo "Operation completed successfully."
echo "To apply the update, run: sudo systemctl reload pm2-dspace"
