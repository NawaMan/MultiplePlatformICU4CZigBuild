# Use versions.env for version management
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables
ENV HOME=/home/ubuntu
ENV WORKDIR=/workdir

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    bash        \
    curl        \
    file        \
    jq          \
    less        \
    man         \
    manpages    \
    nano        \
    python3     \
    python3-pip \
    sudo        \
    tree        \
    unzip       \
    wget        \
    xmlstarlet  \
    zip         \
    &&          \
    rm -rf /var/lib/apt/lists/*

# Install Jupyter and Bash kernel
RUN pip3 install --break-system-packages --no-cache-dir notebook bash_kernel && \
    python3 -m bash_kernel.install

# ✅ Prepare runtime directories and assign permissions to existing 'ubuntu' user
RUN mkdir -p ${WORKDIR} ${HOME}/.local/share/jupyter/runtime && \
    chown -R ubuntu:ubuntu ${WORKDIR} ${HOME}

# ✅ Create a startup script for Jupyter
RUN echo '#!/bin/bash\n\
mkdir -p "$HOME/.local/share/jupyter/runtime"\n\
chown -R "$(id -u):$(id -g)" "$HOME/.local"\n\
exec jupyter notebook \\\n\
  --ip=0.0.0.0 \\\n\
  --port=${JUPYTER_PORT:-8888} \\\n\
  --no-browser \\\n\
  --NotebookApp.token="" \\\n\
  --NotebookApp.password="" \\\n\
  --notebook-dir=/workdir/notebooks' > /usr/local/bin/start-jupyter.sh && \
  chmod +x /usr/local/bin/start-jupyter.sh && \
  chown ubuntu:ubuntu /usr/local/bin/start-jupyter.sh

# Add environment variables to bashrc
RUN mkdir -p "/workdir/build" && \
    echo 'export BUILD_LOG="/workdir/build/build.log"' >> /home/ubuntu/.bashrc && \
    chown ubuntu:ubuntu /home/ubuntu/.bashrc

# ✅ Allow passwordless sudo for ubuntu and set bash as default shell
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chsh -s /bin/bash ubuntu

# ✅ Switch to non-root user and set bash for Jupyter terminal
USER ubuntu
WORKDIR ${WORKDIR}
ENV SHELL=/bin/bash

# Default command to run Jupyter
CMD ["/usr/local/bin/start-jupyter.sh"]
