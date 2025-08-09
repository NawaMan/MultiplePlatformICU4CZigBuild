#!/bin/bash

mkdir -p build

./ensure-linux-x86-64-build-environment.sh
./install-zig.sh
./prepare-icu4c-source.sh
