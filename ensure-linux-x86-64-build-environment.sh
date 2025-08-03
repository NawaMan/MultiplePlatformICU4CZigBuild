#!/bin/bash

set -e

source sh-sources/common-source.sh

print_section "Installing dependencies"

apt-get update -qq
apt-get install -y             \
    autoconf                   \
    automake                   \
    build-essential            \
    cmake                      \
    curl                       \
    g++-multilib               \
    gcc-multilib               \
    gnupg                      \
    lsb-release                \
    pkg-config                 \
    python3                    \
    software-properties-common \
    unzip                      \
    wget                       \
    zip                        \
    2>&1                       \
    | grep -E 'is already the newest version|Setting up|Preparing to unpack|Installing'

