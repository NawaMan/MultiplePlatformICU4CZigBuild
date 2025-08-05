#!/bin/bash

# Script to enter the ICU4C Universal Static Bundle build container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Create required directories if they don't exist
mkdir -p "${PROJECT_ROOT}/host/source"
mkdir -p "${PROJECT_ROOT}/dist"

# Check if the container is already running
if [ "$(docker ps -q -f name=icu4c-builder)" ]; then
    echo "Entering existing icu4c-builder container..."
    docker exec -it icu4c-builder /bin/bash
else
    # Check if the container exists but is stopped
    if [ "$(docker ps -aq -f name=icu4c-builder)" ]; then
        echo "Starting existing icu4c-builder container..."
        docker start icu4c-builder
        docker exec -it icu4c-builder /bin/bash
    else
        # Build and start the container
        echo "Building and starting icu4c-builder container..."
        cd "${SCRIPT_DIR}"
        docker-compose up -d
        docker exec -it icu4c-builder /bin/bash
    fi
fi
