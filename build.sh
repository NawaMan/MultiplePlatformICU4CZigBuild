#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build.sh [--workdir PATH] [--target TARGET_ID]

Options:
  -w, --workdir PATH     Working root (default: /workdir)
  -t, --target  ID       Target to build: linux-x86 | linux-arm | all (default: all)
  -h, --help             Show this help

Examples:
  ./build.sh --target linux-x86
  ./build.sh -w /tmp/icu --target linux-arm
  ./build.sh --target linux-x86 --target linux-arm
  ./build.sh
EOF
}

# -------------------- args --------------------
WORK_DIR=/workdir
TARGET=all

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workdir) WORK_DIR="$2"; shift 2 ;;
    -t|--target)  TARGET="$2";   shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# -------------------- constants/paths --------------------
BUILD_DIR="$WORK_DIR/build"
SOURCE_DIR="$BUILD_DIR/icu4c-source"
TARGET_DIR="$BUILD_DIR/icu4c-target"

LIB_DIR="$(zig env | jq -r '.lib_dir')"
SYSROOT="$LIB_DIR/libc"

# Map CLI target IDs -> zig targets + install dir names
declare -A ZIG_TARGETS=(
  [linux-x86]="x86_64-linux-musl"
  [linux-arm]="aarch64-linux-musl"
)

declare -A INSTALL_NAMES=(
  [linux-x86]="linux-x86_64"
  [linux-arm]="linux-arm_64"
)

# -------------------- helpers --------------------
ensure_source() {
  if [[ ! -d "$SOURCE_DIR/source" ]]; then
    echo "ERROR: ICU4C source not found at: $SOURCE_DIR/source"
    exit 1
  fi
}

build_host_once() {
  local HOST_INSTALL="$TARGET_DIR/${INSTALL_NAMES[linux-x86]}"
  local HOST_BUILD="$BUILD_DIR/icu4c-build-host"

  if [[ -f "$HOST_INSTALL/lib/libicuuc.a" ]]; then
    echo "[host] already built at $HOST_INSTALL (skipping)"
    HOST_BUILD_DIR="$HOST_BUILD"
    return 0
  fi

  echo "[host] building for linux-x86_64…"
  rm -rf "$HOST_BUILD"
  mkdir -p "$HOST_BUILD" "$HOST_INSTALL"
  pushd "$HOST_BUILD" >/dev/null

  export CC="zig cc -target x86_64-linux-musl --sysroot $SYSROOT"
  export CXX="zig c++ -target x86_64-linux-musl --sysroot $SYSROOT"
  export CXXFLAGS="-std=c++20"

  "$SOURCE_DIR"/source/configure        \
    --prefix="$HOST_INSTALL"            \
    --enable-static                     \
    --disable-shared                    \
    --with-data-packaging=static        \
    --disable-samples                   \
    --disable-tests

  make -j"$(nproc)"
  make install
  popd >/dev/null

  HOST_BUILD_DIR="$HOST_BUILD"
}

build_target() {
  local CLI_ID="$1"
  local ZT="${ZIG_TARGETS[$CLI_ID]:-}"
  local INSTALL_NAME="${INSTALL_NAMES[$CLI_ID]:-}"

  if [[ -z "$ZT" || -z "$INSTALL_NAME" ]]; then
    echo "Unknown target id: $CLI_ID"
    exit 1
  fi

  local BUILD_DIR_TGT="$BUILD_DIR/icu4c-build-$INSTALL_NAME"
  local INSTALL_DIR_TGT="$TARGET_DIR/$INSTALL_NAME"

  if [[ "$CLI_ID" == "linux-x86" ]]; then
    build_host_once
    return 0
  fi

  ensure_source
  build_host_once

  echo "[$CLI_ID] building for $ZT…"
  rm -rf "$BUILD_DIR_TGT"
  mkdir -p "$BUILD_DIR_TGT" "$INSTALL_DIR_TGT"
  pushd "$BUILD_DIR_TGT" >/dev/null

  export CC="zig cc -target $ZT --sysroot $SYSROOT"
  export CXX="zig c++ -target $ZT --sysroot $SYSROOT"
  export CXXFLAGS="-std=c++20"

  "$SOURCE_DIR"/source/configure     \
    --host="$ZT"                     \
    --with-cross-build="$HOST_BUILD_DIR" \
    --prefix="$INSTALL_DIR_TGT"      \
    --enable-static                  \
    --disable-shared                 \
    --with-data-packaging=static     \
    --disable-samples                \
    --disable-tests

  make -j"$(nproc)"
  make install
  popd >/dev/null
}

# -------------------- drive --------------------
ensure_source

case "$TARGET" in
  all)
    build_target linux-x86
    build_target linux-arm
    ;;
  linux-x86|linux-arm)
    build_target "$TARGET"
    ;;
  *)
    echo "Unsupported --target: $TARGET"
    echo "Use one of: linux-x86 | linux-arm | all"
    exit 1
    ;;
esac

echo "Done. Artifacts installed under: $TARGET_DIR/{linux-x86_64,linux-arm_64}"
