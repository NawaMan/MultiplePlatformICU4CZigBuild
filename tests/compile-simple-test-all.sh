#!/bin/bash
set -euo pipefail

DIST=dist
mkdir -p "$DIST"

build-test() {
  local OS="$1"
  local ARC="$2"
  local BIT="${3:-64}"

  # Normalize OS name used in your icu4c-library paths
  local OSNAME="$OS"
  if [[ "$OS" == "mac" || "$OS" == "darwin" || "$OS" == "macos" ]]; then
    OSNAME="macos"
  fi

  # Map input arch to (a) dir/output arch name and (b) Zig target arch
  local DIR_ARCH_BIT OUT_ARCH ARCH_TRIPLE
  if [[ "$ARC" == "x86" || "$ARC" == "x86_64" ]]; then
    DIR_ARCH_BIT="x86_64"
    OUT_ARCH="x86_64"
    ARCH_TRIPLE="x86_64"
  else
    DIR_ARCH_BIT="arm_64"
    OUT_ARCH="arm_64"     # <- output name uses arm_64
    ARCH_TRIPLE="aarch64" # <- Zig target arch stays aarch64
  fi

  local INC_DIR="icu4c-library/common/include"
  local LIB_DIR="icu4c-library/${OSNAME}-${DIR_ARCH_BIT}/lib"

  # Compose Zig target + per-OS flags
  local ZIG_TARGET EXTRA_CXX EXTRA_LINK
  if [[ "$OSNAME" == "linux" ]]; then
    ZIG_TARGET="${ARCH_TRIPLE}-linux-musl"
    EXTRA_CXX=""
    EXTRA_LINK="-pthread -ldl"
  else
    ZIG_TARGET="${ARCH_TRIPLE}-macos"
    EXTRA_CXX="-stdlib=libc++ -mmacosx-version-min=11.0"
    EXTRA_LINK="-mmacosx-version-min=11.0"
  fi

  # ---- Output name (no '-musl', with arm_64) ----
  local OUT="$DIST/simple-test-${OUT_ARCH}-${OSNAME}"

  echo
  echo "Building for ${ZIG_TARGET} …"

  zig c++ \
    -target "$ZIG_TARGET" \
    -std=c++20 \
    ${EXTRA_CXX:-} \
    src/*.cpp \
    -O2 \
    -I. \
    -I"$INC_DIR" \
    -L"$LIB_DIR" \
    -licui18n -licuuc -licudata -licuio \
    ${EXTRA_LINK:-} \
    -o "$OUT"

  echo "Built $OUT"
  echo
}

# Build all four variants (linux/macOS × x86/arm)
for OS in linux macos; do
  for ARC in x86 arm; do
    build-test "$OS" "$ARC"
  done
done
