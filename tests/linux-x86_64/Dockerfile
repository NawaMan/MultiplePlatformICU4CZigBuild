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

WORKDIR ${WORKDIR}

# Copy build related files
COPY in-docker/ensure-test-build-environment.sh /workdir/ensure-test-build-environment.sh
COPY ignored/sh-sources                         /workdir/sh-sources
COPY ignored/install-zig.sh                     /workdir/install-zig.sh
COPY ignored/versions.env                       /workdir/versions.env
RUN  /workdir/ensure-test-build-environment.sh
RUN  rm -Rf /workdir/ensure-test-build-environment.sh
RUN  rm -Rf /workdir/sh-sources
RUN  rm -Rf /workdir/install-zig.sh

ENTRYPOINT ["/bin/bash"]
