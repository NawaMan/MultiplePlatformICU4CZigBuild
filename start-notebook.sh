#!/bin/bash

cd docker

PORT="${PORT:-8888}"

# Create required folders
mkdir -p ../notebooks ../shared ../ignored

# Export UID and GID
export UID=$(id -u)
export GID=$(id -g)

# Generate override for port and env
cat <<EOF > docker-compose.override.yml
services:
  icu4c-builder:
    ports:
      - "${PORT}:8888"
    environment:
      - JUPYTER_PORT=${PORT}
EOF

echo "Using UID=$UID and GID=$GID"
echo "Mapping localhost:${PORT} → container:8888"

# Run Docker Compose
docker compose up --build
