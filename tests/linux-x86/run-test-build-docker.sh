#!/bin/bash

SHOULD_BUILD=${1:-''}
echo $SHOULD_BUILD

IMAGE_NAME=mpicu4zb-test-linux-x86
if [ "$SHOULD_BUILD" == "--build" ]; then
    ./clean-common-files.sh
    ./copy-common-files.sh

    echo "Build docker image ..."
    docker build -t "$IMAGE_NAME" .
    echo "Build docker image completed."
else
    echo "Skip docker image build."
fi

echo 
echo 
docker compose up $SHOULD_BUILD --detach
docker exec -it mpicu4zb-test-linux-x86 bash
docker compose down

echo 
echo 
echo "Post build clean up."
./clean-common-files.sh
