#!/bin/bash

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rustdesk-dir)
            RUSTDESK_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set default RustDesk directory if not provided
RUSTDESK_DIR="${RUSTDESK_DIR:-$HOME/webdev/projects/docker/rustdesk}"

if [ -d "$RUSTDESK_DIR" ]; then
    current_dir=$(pwd)

    if docker compose -f "$RUSTDESK_DIR/docker-compose.yml" ps | grep -q "rustdesk"; then
        docker compose -f "$RUSTDESK_DIR/docker-compose.yml" down
        echo "RustDesk OFF"
    else
        docker compose -f "$RUSTDESK_DIR/docker-compose.yml" up -d
        echo "RustDesk ON"
    fi

    echo "Switching back to original directory: $current_dir"
    cd "$current_dir"
else
    echo "Error: RustDesk directory '$RUSTDESK_DIR' does not exist."
    exit 1
fi
