#!/bin/bash
set -euo pipefail

WORK_DIR=${1:-/workdir}

BUILD_DIR=$WORK_DIR/build

# Construct the ICU4C Library form the built target.

# From:
# icu4c-library/
#   linux-x86_64/
#     bin/**
#     include/**
#     lib/**
#     sbin/**
#     share/**
#   linux-arm_64/
#     bin/**
#     include/**
#     lib/**
#     sbin/**
#     share/**


# To: 
# icu4c-library/
#   common/
#     include/**
#     share/**
#   linux-x86_64/
#     bin/**
#     lib/**
#     sbin/**
#   linux-arm_64/
#     bin/**
#     lib/**
#     sbin/**


TARGET_LIB=$WORK_DIR/dist/icu4c-library
mkdir -p "$TARGET_LIB/common/include"
mkdir -p "$TARGET_LIB/common/share"

ARCHES=("linux-x86_64" "linux-arm_64")

# Create destination root
mkdir -p "$TARGET_LIB"

# ---- Common (arch-independent) ----
# Use one arch (x86_64) as the donor for headers & share; they’re identical across arches.
DONOR="${ARCHES[0]}"

echo "Preparing common/include ..."
mkdir -p "$TARGET_LIB/common/include"
cp -a "$TARGET_DIR/$DONOR/include/unicode" "$TARGET_LIB/common/include/"

echo "Preparing common/share ..."
mkdir -p "$TARGET_LIB/common/share"
cp -a "$TARGET_DIR/$DONOR/share/icu" "$TARGET_LIB/common/share/"
cp -a "$TARGET_DIR/$DONOR/share/man" "$TARGET_LIB/common/share/"

# ---- Per-arch (CPU-specific) ----
copy_arch() {
  local src="$1"
  local name="$2"
  local dst="$TARGET_LIB/$2"

  echo "Copying per-arch files for $name ..."
  mkdir -p "$dst"

  # bin, sbin, lib are arch-specific
  cp -a "$src/bin"  "$dst/"
  cp -a "$src/sbin" "$dst/"
  cp -a "$src/lib"  "$dst/"
}

for arch in "${ARCHES[@]}"; do
  # Quick sanity checks
  [[ -d "$TARGET_DIR/$arch" ]] || { echo "Missing: $TARGET_DIR/$arch"; exit 1; }
  copy_arch "$TARGET_DIR/$arch" "$arch"
done

echo "✅ ICU4C library prepared at: $TARGET_LIB"
echo "Structure:"
echo "  common/include/**"
echo "  common/share/**"
echo "  linux-x86_64/{bin,lib,sbin}/**"
echo "  linux-arm_64/{bin,lib,sbin}/**"

echo "ICU4C library prepared in: $TARGET_LIB"
