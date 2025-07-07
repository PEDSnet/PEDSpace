#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 [-s|--source <source_dir>] [-d|--destination <dest_dir>] [-b|--build] [-p|--pm2-reload]"
    echo "  -s, --source        Source directory path (default: current directory)"
    echo "  -d, --destination   Destination directory path (required)"
    echo "  -b, --build         Build production version before copying"
    echo "  -p, --pm2-reload    Reload PM2 after copying (requires dspace-ui.json in destination)"
    echo "  -h, --help          Display this help message"
}

# Initialize variables
SRC_DIR=""
DEST_DIR=""
BUILD_PROD=false
PM2_RELOAD=false

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
        -p|--pm2-reload)
            PM2_RELOAD=true
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

# Backup existing dist directory if it exists
if [ -d "$DEST_DIR/dist" ]; then
    mv "$DEST_DIR/dist" "$DEST_DIR/dist.$TIMESTAMP.bak"
    echo "Existing dist directory backed up to $DEST_DIR/dist.$TIMESTAMP.bak"
fi

# Copy dist directory from source to destination
echo "Copying $DIST_SRC to $DEST_DIR/dist..."
cp -r "$DIST_SRC" "$DEST_DIR/dist"

if [ $? -eq 0 ]; then
    echo "Successfully copied $DIST_SRC to $DEST_DIR/dist"
else
    echo "Error: Failed to copy $DIST_SRC to $DEST_DIR/dist"
    exit 1
fi

# Reload PM2 if requested
if [ "$PM2_RELOAD" = true ]; then
    echo "Reloading PM2..."
    cd "$DEST_DIR"
    
    # Check if dspace-ui.json exists
    if [ ! -f "dspace-ui.json" ]; then
        echo "Warning: dspace-ui.json not found in $DEST_DIR. PM2 reload skipped."
    else
        pm2 reload dspace-ui.json
        if [ $? -eq 0 ]; then
            echo "PM2 reloaded successfully."
        else
            echo "Error: PM2 reload failed."
            exit 1
        fi
    fi
fi

echo "Operation completed successfully."
