#!/bin/bash

set -euo pipefail

SHOULD_BUILD=""
COMMAND="/workdir/compile-run-simple-test.all.sh"

for arg in "$@"; do
    case "$arg" in
        --build-docker) SHOULD_BUILD="--build"      ;;
        --bash)         COMMAND="bash"              ;;
        *)              echo "Unknown option: $arg" ;;
    esac
done

echo SHOULD_BUILD=$SHOULD_BUILD
echo COMMAND=$COMMAND

IMAGE_NAME=mpicu4zb-test-linux-x86
if [ "$SHOULD_BUILD" == "--build" ]; then
    ./clean-common-files.sh
    ./copy-common-files.sh
    SHOULD_BUILD="--build"

    echo "Build docker image ..."
    docker build -t "$IMAGE_NAME" .
    echo "Build docker image completed."
else
    SHOULD_BUILD=""
    echo "Skip docker image build."
fi

# Prepare the `dist` folder.
mkdir -p dist
chown -R $(id -u):$(id -g) dist
chmod -R ug+rwX dist

echo 
echo 

export UID
export GID=$(id -g)
docker compose up $SHOULD_BUILD --detach
docker exec -it mpicu4zb-test-linux-x86_64 "$COMMAND"
docker compose down

echo 
echo 

echo "Post build clean up."
./clean-common-files.sh
