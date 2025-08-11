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


TARGET_DIR="$BUILD_DIR/icu4c-target"

LIBRARY_DIR="icu4c-library"
DIST_DIR="$WORK_DIR/dist"
TARGET_LIB="$DIST_DIR/$LIBRARY_DIR"
TARGET_TGZ="$DIST_DIR/$LIBRARY_DIR.tar.gz"

mkdir -p "$DIST_DIR"

# Start clean
rm -rf "$TARGET_LIB" "$TARGET_TGZ"
mkdir -p "$TARGET_LIB/common/include"
mkdir -p "$TARGET_LIB/common/share"

# Detect which arches are present
CANDIDATES=( linux-x86_64 linux-arm_64 macos-x86_64 macos-arm_64 macos-universal )
ARCHES=()
for a in "${CANDIDATES[@]}"; do
  [[ -d "$TARGET_DIR/$a" ]] && ARCHES+=("$a")
done

if [[ ${#ARCHES[@]} -eq 0 ]]; then
  echo "ERROR: No built ICU targets found under $TARGET_DIR"
  exit 1
fi

# Choose a donor for common headers/share (all arches are equivalent for these)
DONOR="${ARCHES[0]}"

echo "Preparing common/include from $DONOR ..."
cp -a "$TARGET_DIR/$DONOR/include/unicode" "$TARGET_LIB/common/include/"

# Copy if present (some builds may omit man pages)
echo "Preparing common/share from $DONOR ..."
if [[ -d "$TARGET_DIR/$DONOR/share/icu" ]]; then
  cp -a "$TARGET_DIR/$DONOR/share/icu" "$TARGET_LIB/common/share/"
fi
if [[ -d "$TARGET_DIR/$DONOR/share/man" ]]; then
  cp -a "$TARGET_DIR/$DONOR/share/man" "$TARGET_LIB/common/share/"
fi

# ---- Per-arch (CPU-specific) ----
copy_arch() {
  local src="$1"
  local name="$2"
  local dst="$TARGET_LIB/$name"

  echo "Copying per-arch files for $name ..."
  mkdir -p "$dst"

  # bin, sbin, lib are arch-specific
  [[ -d "$src/bin"  ]] && cp -a "$src/bin"  "$dst/"
  [[ -d "$src/sbin" ]] && cp -a "$src/sbin" "$dst/"
  [[ -d "$src/lib"  ]] && cp -a "$src/lib"  "$dst/"
}

# Per-arch copies
for arch in "${ARCHES[@]}"; do
  copy_arch "$TARGET_DIR/$arch" "$arch"
done

# Tar it up
tar -czf "$TARGET_TGZ" -C "$DIST_DIR" "$LIBRARY_DIR"

echo "✅ ICU4C library prepared at: $TARGET_LIB"
echo "Structure:"
echo "  common/include/**"
echo "  common/share/**"
echo "  linux-x86_64/{bin,lib,sbin}/**"
echo "  linux-arm_64/{bin,lib,sbin}/**"
echo "✅ ICU4C library archive file at: $TARGET_TGZ"

echo "ICU4C library prepared in: $TARGET_LIB"