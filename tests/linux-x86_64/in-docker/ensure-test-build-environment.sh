#!/bin/bash

set -e

source sh-sources/common-source.sh

print_section "Installing dependencies"
apt-get update
apt-get install -y  \
    build-essential \
    g++-multilib    \
    gcc-multilib    \
    libfmt-dev      \
    tree            \
    unzip           \
    wget

./install-zig.sh
