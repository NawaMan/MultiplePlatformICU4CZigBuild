# Task 001 – Docker Build Environment: Step 1 – Baseline Dockerfile

## Goal

Establish the foundational Docker image used to build the ICU4C Universal Static Bundle. This baseline will:

- Use **Ubuntu 24.04 LTS** as the base image
- Install essential build tools (e.g., `build-essential`, `cmake`, `git`, etc.)
- Install a specific version of **Zig** (recorded in `VERSION.txt`)
- Set up a clean, non-root working environment
- All the installation must be done in `ensure-linux-x86-64-build-environment.sh`