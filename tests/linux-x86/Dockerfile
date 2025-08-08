# Use versions.env for version management
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables
ENV HOME=/home/ubuntu
ENV WORKDIR=/workdir

# Install bash
RUN apt-get update && apt-get install -y \
    bash             \
    build-essential  \
    curl             \
    g++-multilib     \
    gcc-multilib     \
    libfmt-dev       \
    libstdc++-10-dev \
    sudo             \
    tree             \
    && rm -rf /var/lib/apt/lists/*

COPY in-docker/ensure-test-build-environment.sh /workdir/ensure-test-build-environment.sh
COPY in-docker/compile-simple-test.sh           /workdir/compile-simple-test.sh
COPY sh-sources                                 /workdir/sh-sources
COPY icu4c-library                              /workdir/icu4c-library
COPY versions.env                               /workdir/versions.env
COPY install-zig.sh                             /workdir/install-zig.sh
COPY console.hpp                                /workdir/console.hpp
COPY simple-test.cpp                            /workdir/simple-test.cpp

WORKDIR ${WORKDIR}

RUN /workdir/ensure-test-build-environment.sh

ENTRYPOINT ["/bin/bash"]
