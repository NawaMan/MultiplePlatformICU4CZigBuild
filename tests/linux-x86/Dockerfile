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
    nano             \
    sudo             \
    tree             \
    && rm -rf /var/lib/apt/lists/*

# Copy build related files
COPY in-docker/ensure-test-build-environment.sh /workdir/ensure-test-build-environment.sh
COPY ignored/sh-sources                         /workdir/sh-sources
COPY ignored/versions.env                       /workdir/versions.env
COPY ignored/install-zig.sh                     /workdir/install-zig.sh

WORKDIR ${WORKDIR}
RUN /workdir/ensure-test-build-environment.sh

# Copy test related files.
COPY in-docker/compile-simple-test.sh /workdir/compile-simple-test.sh
COPY ignored/icu4c-library            /workdir/icu4c-library
COPY ignored/console.hpp              /workdir/console.hpp
COPY ignored/simple-test.cpp          /workdir/simple-test.cpp

ENTRYPOINT ["/bin/bash"]
