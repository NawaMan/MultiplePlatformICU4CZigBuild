#!/bin/bash

mkdir -p build

./in-docker/ensure-linux-x86-64-build-environment.sh
./in-docker/install-zig.sh
./in-docker/install-zig.sh
