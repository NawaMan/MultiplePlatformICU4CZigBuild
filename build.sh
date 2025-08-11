#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build.sh [--workdir PATH] [--target TARGET_ID] [--macos-sdk PATH] [--macos-min N]

Options:
  -w, --workdir PATH     Working root (default: /workdir)
  -t, --target  ID       Target: linux-x86 | linux-arm | mac-x86 | mac-arm | mac-universal | all (default: all)
  -s, --macos-sdk PATH   Path to macOS SDK (optional). If omitted/invalid, uses Zig's built-in Darwin headers (no SDK).
  -m, --macos-min N      Minimum macOS version (default: 11.0)
  -h, --help             Show this help

Examples:
  ./build.sh --target linux-x86
  ./build.sh -w /tmp/icu --target linux-arm
  ./build.sh --target mac-x86
  ./build.sh --target mac-arm --macos-sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX14.5.sdk
  ./build.sh --target mac-universal
EOF
}

# -------------------- args --------------------
WORK_DIR=/workdir
TARGET=all
MACOS_MIN_VER=11.0
MACOS_SDK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workdir) WORK_DIR="$2"; shift 2 ;;
    -t|--target)  TARGET="$2";   shift 2 ;;
    -s|--macos-sdk) MACOS_SDK="$2"; shift 2 ;;
    -m|--macos-min) MACOS_MIN_VER="$2"; shift 2 ;;
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
  ["linux-x86"]="x86_64-linux-musl"
  ["linux-arm"]="aarch64-linux-musl"
  ["mac-x86"]="x86_64-macos"
  ["mac-arm"]="aarch64-macos"
)

# Configure --host triplets for autoconf (ICU)
declare -A HOST_TRIPLES=(
  ["linux-x86"]="x86_64-linux-musl"
  ["linux-arm"]="aarch64-linux-musl"
  ["mac-x86"]="x86_64-apple-darwin"
  ["mac-arm"]="aarch64-apple-darwin"
)

declare -A INSTALL_NAMES=(
  ["linux-x86"]="linux-x86_64"
  ["linux-arm"]="linux-arm_64"
  ["mac-x86"]="macos-x86_64"
  ["mac-arm"]="macos-arm_64"
  ["mac-universal"]="macos-universal"
)

# -------------------- helpers --------------------
ensure_source() {
  if [[ ! -d "$SOURCE_DIR/source" ]]; then
    echo "ERROR: ICU4C source not found at: $SOURCE_DIR/source"
    exit 1
  fi
}

build_host_once() {
  local HOST_INSTALL="$TARGET_DIR/${INSTALL_NAMES["linux-x86"]}"
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

# ---- mac flag sets ----
mac_flags_builtin() {
  local minver="$1"
  # No SDK. Use Zig's bundled Darwin headers/libc++.
  unset SDKROOT || true
  export CPPFLAGS="${CPPFLAGS:-} -DU_HAVE_TZFILE=0"
  export CFLAGS="${CFLAGS:-}"
  export CXXFLAGS="${CXXFLAGS:-} -std=c++20 -stdlib=libc++ -DU_HAVE_TZFILE=0"
  export LDFLAGS="${LDFLAGS:-} -mmacosx-version-min=$minver"
  export AR="zig ar"
  export RANLIB="zig ranlib"
  export NM="llvm-nm"
  export STRIP="llvm-strip"
}

mac_flags_sdk() {
  local sdk="$1"
  local minver="$2"
  export SDKROOT="$sdk"
  export CPPFLAGS="${CPPFLAGS:-} -isysroot $sdk -mmacosx-version-min=$minver -DU_HAVE_TZFILE=0"
  export CFLAGS="${CFLAGS:-}   -isysroot $sdk -mmacosx-version-min=$minver"
  export CXXFLAGS="${CXXFLAGS:-} -std=c++20 -stdlib=libc++ -isysroot $sdk -mmacosx-version-min=$minver -DU_HAVE_TZFILE=0"
  export LDFLAGS="${LDFLAGS:-} -mmacosx-version-min=$minver"
  export AR="zig ar"
  export RANLIB="zig ranlib"
  export NM="llvm-nm"
  export STRIP="llvm-strip"
}

preflight_macos_sdk() {
  local zt="$1"   # x86_64-macos or aarch64-macos
  local sdk="$2"
  local minv="$3"

  for p in "$sdk/usr/lib/libSystem.tbd" "$sdk/usr/include/stdio.h"; do
    if [[ ! -f "$p" ]]; then
      echo "ERROR: macOS SDK at '$sdk' is missing: ${p#$sdk/}"
      exit 1
    fi
  done

  local tf
  tf="$(mktemp -p "${BUILD_DIR}" conftest.XXXXXX.c)"
  echo 'int main(void){return 0;}' > "$tf"
  if ! zig cc -target "$zt" --sysroot "$sdk" -isysroot "$sdk" \
        -mmacosx-version-min="$minv" "$tf" -o "${tf%.c}"; then
    echo "ERROR: Zig failed to link a minimal $zt test with SDK '$sdk'."
    exit 1
  fi
  rm -f "$tf" "${tf%.c}"
}

build_one() {
  local CLI_ID="$1"
  local ZT="${ZIG_TARGETS[$CLI_ID]:-}"
  local HOST_TRIP="${HOST_TRIPLES[$CLI_ID]:-}"
  local INSTALL_NAME="${INSTALL_NAMES["$CLI_ID"]:-}"

  if [[ -z "$ZT" || -z "$INSTALL_NAME" ]]; then
    echo "Unknown target id: $CLI_ID"
    exit 1
  fi

  local BUILD_DIR_TGT="$BUILD_DIR/icu4c-build-$INSTALL_NAME"
  local INSTALL_DIR_TGT="$TARGET_DIR/$INSTALL_NAME"

  # ---- reset flags per target to avoid leakage + nounset issues ----
  CPPFLAGS=""
  CFLAGS=""
  CXXFLAGS=""
  LDFLAGS=""
  unset SDKROOT || true
  export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS

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

  # ---- mac targets ----
  if [[ "$CLI_ID" == "mac-x86" || "$CLI_ID" == "mac-arm" ]]; then
    # tzfile shim (used in both modes)
    local SHIM_DIR="$BUILD_DIR_TGT/shims"
    mkdir -p "$SHIM_DIR"
    cat > "$SHIM_DIR/tzfile.h" <<'EOF'
#ifndef TZFILE_H
#define TZFILE_H
/* Minimal shim for ICU when cross-compiling to macOS.
   ICU needs TZDIR and TZDEFAULT; modern SDKs may lack tzfile.h. */
#ifndef TZDIR
#  define TZDIR "/usr/share/zoneinfo"
#endif
#ifndef TZDEFAULT
#  define TZDEFAULT "/etc/localtime"
#endif
#ifndef TZDEFRULES
#  define TZDEFRULES "posixrules"
#endif
#endif /* TZFILE_H */
EOF
    export CPPFLAGS="-I$SHIM_DIR ${CPPFLAGS:-}"
    export CFLAGS="-I$SHIM_DIR ${CFLAGS:-}"
    export CXXFLAGS="-I$SHIM_DIR ${CXXFLAGS:-}"

    if [[ -n "${MACOS_SDK:-}" && -d "$MACOS_SDK" ]]; then
      echo "[$CLI_ID] using macOS SDK at: $MACOS_SDK"
      mac_flags_sdk "$MACOS_SDK" "$MACOS_MIN_VER"
      preflight_macos_sdk "$ZT" "$MACOS_SDK" "$MACOS_MIN_VER"
      export CC="zig cc -target $ZT --sysroot $MACOS_SDK"
      export CXX="zig c++ -target $ZT --sysroot $MACOS_SDK"
    else
      echo "[$CLI_ID] no SDK provided or not a directory; using Zig's built-in Darwin headers."
      mac_flags_builtin "$MACOS_MIN_VER"
      export CC="zig cc -target $ZT"
      export CXX="zig c++ -target $ZT"
    fi
  else
    # ---- linux targets ----
    export CC="zig cc -target $ZT --sysroot $SYSROOT"
    export CXX="zig c++ -target $ZT --sysroot $SYSROOT"
    export CXXFLAGS="${CXXFLAGS:-} -std=c++20"
  fi

  "$SOURCE_DIR"/source/configure         \
    --host="${HOST_TRIP}"                \
    --with-cross-build="$HOST_BUILD_DIR" \
    --prefix="$INSTALL_DIR_TGT"          \
    --enable-static                      \
    --disable-shared                     \
    --with-data-packaging=static         \
    --disable-samples                    \
    --disable-tests

  make -j"$(nproc)"
  make install
  popd >/dev/null
}

lipo_tool() {
  if command -v lipo >/dev/null 2>&1; then
    echo "lipo"
    return 0
  fi
  if command -v llvm-lipo >/dev/null 2>&1; then
    echo "llvm-lipo"
    return 0
  fi
  return 1
}

build_universal() {
  # Build per-arch first, then merge static libs with lipo if available.
  build_one mac-x86
  build_one mac-arm

  local DIR_X86="$TARGET_DIR/${INSTALL_NAMES["mac-x86"]}"
  local DIR_ARM="$TARGET_DIR/${INSTALL_NAMES["mac-arm"]}"
  local DIR_UNI="$TARGET_DIR/${INSTALL_NAMES["mac-universal"]}"

  rm -rf "$DIR_UNI"
  mkdir -p "$DIR_UNI/lib"
  # Headers and data are arch-agnostic; prefer arm dir for headers, then copy if missing.
  rsync -a "$DIR_ARM/include/" "$DIR_UNI/include/" 2>/dev/null || true
  rsync -a "$DIR_X86/include/" "$DIR_UNI/include/" 2>/dev/null || true

  # If no lipo available, just stage separate outputs and warn.
  local LIPO_BIN
  if ! LIPO_BIN="$(lipo_tool)"; then
    echo "[mac-universal] WARNING: 'lipo' not found. Produced per-arch builds only."
    echo "                 x86_64: $DIR_X86"
    echo "                 arm64 : $DIR_ARM"
    return 0
  fi

  echo "[mac-universal] merging static libraries with $LIPO_BIN…"
  shopt -s nullglob
  for libname in libicu*.a; do
    local X86_LIB="$DIR_X86/lib/$libname"
    local ARM_LIB="$DIR_ARM/lib/$libname"
    if [[ -f "$X86_LIB" && -f "$ARM_LIB" ]]; then
      "$LIPO_BIN" -create -output "$DIR_UNI/lib/$libname" "$X86_LIB" "$ARM_LIB"
    fi
  done

  # Copy any other libs/tools if they exist
  rsync -a "$DIR_ARM/bin/" "$DIR_UNI/bin/" 2>/dev/null || true
  rsync -a "$DIR_X86/bin/" "$DIR_UNI/bin/" 2>/dev/null || true

  echo "[mac-universal] done at: $DIR_UNI"
}

build_target() {
  local CLI_ID="$1"
  case "$CLI_ID" in
    mac-universal) build_universal ;;
    *) build_one "$CLI_ID" ;;
  esac
}

# -------------------- drive --------------------
ensure_source

case "$TARGET" in
  all)
    build_target linux-x86
    build_target linux-arm
    build_target mac-x86
    build_target mac-arm
    ;;
  linux-x86|linux-arm|mac-x86|mac-arm|mac-universal)
    build_target "$TARGET"
    ;;
  *)
    echo "Unsupported --target: $TARGET"
    echo "Use one of: linux-x86 | linux-arm | mac-x86 | mac-arm | mac-universal | all"
    exit 1
    ;;
esac

echo "Done. Artifacts installed under: $TARGET_DIR/{linux-x86_64,linux-arm_64,macos-x86_64,macos-arm_64,macos-universal}"
