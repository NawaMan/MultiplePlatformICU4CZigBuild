#!/usr/bin/env bash
set -euo pipefail

WORK_DIR=${1:-/workdir}

BUILD_DIR=$WORK_DIR/build
SOURCE_DIR=$BUILD_DIR/icu4c-source
TARGET_DIR=$BUILD_DIR/icu4c-target
LIB_DIR=$(zig env | jq -r '.lib_dir')

OS=linux
ARC=x86_64

# paths (same names as before)
HOST_BUILD=$BUILD_DIR/icu4c-build-host
HOST_INSTALL=$TARGET_DIR/${OS}-${ARC}

SYSROOT="$LIB_DIR/libc"

# ---------- Host build (unchanged in spirit) ----------
rm -rf "$HOST_BUILD" && mkdir -p "$HOST_BUILD"
mkdir -p "$HOST_INSTALL"
cd "$HOST_BUILD"

export CC="zig cc -target x86_64-linux-musl --sysroot $SYSROOT"
export CXX="zig c++ -target x86_64-linux-musl --sysroot $SYSROOT"
export CXXFLAGS="-std=c++20"

"$SOURCE_DIR"/source/configure        \
  --prefix="$HOST_INSTALL"     \
  --enable-static              \
  --disable-shared             \
  --with-data-packaging=static \
  --disable-samples            \
  --disable-tests

make -j"$(nproc)"
make install

# ---------- Cross builds (looped, mirrors your second block) ----------
# Map ARC -> ZIG_TARGET; add more entries if needed.
declare -A ZIG_TARGETS=(
  [arm_64]=aarch64-linux-musl
  # [x86_64]=x86_64-linux-musl   # example if you ever want to include host in the loop
  # [riscv64]=riscv64-linux-musl
)

# List of ARCs you want to build (excluding the already-done host x86_64)
BUILD_ARCS=(arm_64)

for ARC in "${BUILD_ARCS[@]}"; do
  OS=linux
  ZIG_TARGET="${ZIG_TARGETS[$ARC]}"

  BUILD_DIR_TGT=$BUILD_DIR/icu4c-build-${OS}-${ARC}
  INSTALL_DIR_TGT=$TARGET_DIR/${OS}-${ARC}

  rm -rf "$BUILD_DIR_TGT" && mkdir -p "$BUILD_DIR_TGT"
  mkdir -p "$INSTALL_DIR_TGT"
  cd "$BUILD_DIR_TGT"

  export CC="zig cc -target $ZIG_TARGET --sysroot $SYSROOT"
  export CXX="zig c++ -target $ZIG_TARGET --sysroot $SYSROOT"
  export CXXFLAGS="-std=c++20"

  "$SOURCE_DIR"/source/configure     \
    --host=$ZIG_TARGET               \
    --with-cross-build="$HOST_BUILD" \
    --prefix="$INSTALL_DIR_TGT"      \
    --enable-static                  \
    --disable-shared                 \
    --with-data-packaging=static     \
    --disable-samples                \
    --disable-tests

  make -j"$(nproc)"
  make install
done
