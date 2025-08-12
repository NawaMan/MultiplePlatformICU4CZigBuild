#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build.sh [--workdir PATH] [--target TARGET_ID] [--macos-sdk PATH] [--macos-min N]

Options:
  -w, --workdir PATH     Working root (default: /workdir)
  -t, --target  ID       Target: linux-x86 | linux-arm | mac-x86 | mac-arm | mac-universal | windows-x86 | windows-arm | all (default: all)
  -s, --macos-sdk PATH   Path to macOS SDK (optional). If omitted/invalid, uses Zig's built-in Darwin headers (no SDK).
  -m, --macos-min N      Minimum macOS version (default: 11.0)
  -h, --help             Show this help

Examples:
  ./build.sh --target linux-x86
  ./build.sh -w /tmp/icu --target linux-arm
  ./build.sh --target mac-x86
  ./build.sh --target mac-arm --macos-sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX14.5.sdk
  ./build.sh --target windows-x86
  ./build.sh --target windows-arm
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
  ["windows-x86"]="x86_64-windows-gnu"
  ["windows-arm"]="aarch64-windows-gnu"
)

# Configure --host triplets for autoconf (ICU)
declare -A HOST_TRIPLES=(
  ["linux-x86"]="x86_64-linux-musl"
  ["linux-arm"]="aarch64-linux-musl"
  ["mac-x86"]="x86_64-apple-darwin"
  ["mac-arm"]="aarch64-apple-darwin"
  ["windows-x86"]="x86_64-w64-mingw32"
  ["windows-arm"]="aarch64-w64-mingw32"
)

declare -A INSTALL_NAMES=(
  ["linux-x86"]="linux-x86_64"
  ["linux-arm"]="linux-arm_64"
  ["mac-x86"]="macos-x86_64"
  ["mac-arm"]="macos-arm_64"
  ["mac-universal"]="macos-universal"
  ["windows-x86"]="windows-x86_64"
  ["windows-arm"]="windows-arm_64"
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

  "$SOURCE_DIR"/source/configure  \
    --prefix="$HOST_INSTALL"      \
    --enable-static               \
    --disable-shared              \
    --with-data-packaging=static  \
    --disable-samples             \
    --disable-tests

  make -j"$(nproc)"
  make install
  popd >/dev/null

  HOST_BUILD_DIR="$HOST_BUILD"
}

# ---- mac flag sets ----
mac_flags_builtin() {
  local minver="$1"
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

# ---- windows flag set (MinGW via Zig) ----
win_flags() {
  # Static libs only, so keep it simple.
  export CPPFLAGS="${CPPFLAGS:-}"
  export CFLAGS="${CFLAGS:-}"
  export CXXFLAGS="${CXXFLAGS:-} -std=c++20"
  export LDFLAGS="${LDFLAGS:-}"
  export AR="zig ar"
  export RANLIB="zig ranlib"
  export NM="llvm-nm"
  export STRIP="llvm-strip"
  # If ICU's build ever wants a resource compiler, point RC to llvm-rc if present:
  if command -v llvm-rc >/dev/null 2>&1; then export RC="llvm-rc"; fi
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

  # Host-only target: ensure host tools exist
  if [[ "$CLI_ID" == "linux-x86" ]]; then
    build_host_once
    return 0
  fi

  ensure_source
  build_host_once

  # Reset AFTER host build so host CC/CXX don't leak into other targets
  for v in CC CXX AR RANLIB NM STRIP RC SDKROOT; do unset "$v" || true; done
  CPPFLAGS=""; CFLAGS=""; CXXFLAGS=""; LDFLAGS=""
  export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS

  echo "[$CLI_ID] building for $ZT…"
  rm -rf "$BUILD_DIR_TGT"
  mkdir -p "$BUILD_DIR_TGT" "$INSTALL_DIR_TGT"
  pushd "$BUILD_DIR_TGT" >/dev/null

  # Absolute path for --bindir (used on Windows)
  local INSTALL_DIR_ABS
  INSTALL_DIR_ABS="$(cd "$INSTALL_DIR_TGT" && pwd -P)"

  # Select toolchains and per-target flags
  case "$CLI_ID" in
    mac-x86|mac-arm)
      # tzfile shim (modern SDKs may not ship tzfile.h)
      local SHIM_DIR="$BUILD_DIR_TGT/shims"
      mkdir -p "$SHIM_DIR"
      cat > "$SHIM_DIR/tzfile.h" <<'EOF'
#ifndef TZFILE_H
#define TZFILE_H
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
      ;;
    windows-x86|windows-arm)
      win_flags
      export CC="zig cc -target $ZT"
      export CXX="zig c++ -target $ZT"
      ;;
    *)
      # linux-arm, etc.
      export CC="zig cc -target $ZT --sysroot $SYSROOT"
      export CXX="zig c++ -target $ZT --sysroot $SYSROOT"
      export CXXFLAGS="${CXXFLAGS:-} -std=c++20"
      ;;
  esac

  # Extra configure options by target
  local CONFIGURE_EXTRA=""
  case "$CLI_ID" in
    windows-x86|windows-arm)
      # Skip target-side .exe; install sicudt directly under lib/
      CONFIGURE_EXTRA+=" --disable-tools --disable-extras --bindir=${INSTALL_DIR_ABS}/lib"
      ;;
    # mac-x86|mac-arm)
    #   CONFIGURE_EXTRA+=" --disable-tools"
    #   ;;
  esac

  "$SOURCE_DIR"/source/configure         \
    --host="${HOST_TRIP}"                \
    --with-cross-build="$HOST_BUILD_DIR" \
    --prefix="$INSTALL_DIR_TGT"          \
    --enable-static                      \
    --disable-shared                     \
    --with-data-packaging=static         \
    --disable-samples                    \
    --disable-tests                      \
    $CONFIGURE_EXTRA

  # Ensure Windows lib/ exists in case anything targets it directly
  if [[ "$CLI_ID" == "windows-x86" || "$CLI_ID" == "windows-arm" ]]; then
    mkdir -p "$INSTALL_DIR_TGT/lib"
  fi

  make -j"$(nproc)"
  make install

  # Safety: if pkgdata still dropped sicudt.* under bin/, move it to lib/
  if [[ "$CLI_ID" == "windows-x86" || "$CLI_ID" == "windows-arm" ]]; then
    shopt -s nullglob
    for f in "$INSTALL_DIR_TGT/bin"/sicudt.*; do
      echo "[windows] moving $(basename "$f") -> lib/"
      mv -f "$f" "$INSTALL_DIR_TGT/lib/"
    done
    # Create Windows bin/ & sbin/ with explanatory placeholders
    mkdir -p "$INSTALL_DIR_TGT/bin" "$INSTALL_DIR_TGT/sbin"
    cat > "$INSTALL_DIR_TGT/bin/ICU_TOOLS_OMITTED.txt" <<'TXT'
This directory is intentionally empty in cross-compiled Windows builds.

Why:
- ICU command-line tools (genrb, gencmn, icupkg, etc.) are disabled here:
    --disable-tools --disable-extras
- Data generation uses the *host* ICU tools via --with-cross-build=...
- Building Windows .exe tools in a cross MinGW setup is brittle and unnecessary for shipping libraries.

If you need Windows ICU tools (.exe):
- Build ICU natively on Windows, or
- Remove the disable flags and adjust link rules to the appropriate ICU libs.

All linkable libraries for this target are under ../lib
TXT
    cp "$INSTALL_DIR_TGT/bin/ICU_TOOLS_OMITTED.txt" "$INSTALL_DIR_TGT/sbin/ICU_TOOLS_OMITTED.txt"
  fi

  popd >/dev/null
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
    build_target windows-x86
    build_target windows-arm
    ;;
  linux-x86|linux-arm|mac-x86|mac-arm|mac-universal|windows-x86|windows-arm)
    build_target "$TARGET"
    ;;
  *)
    echo "Unsupported --target: $TARGET"
    echo "Use one of: linux-x86 | linux-arm | mac-x86 | mac-arm | mac-universal | windows-x86 | windows-arm | all"
    exit 1
    ;;
esac

echo "Done. Artifacts installed under: $TARGET_DIR/{linux-x86_64,linux-arm_64,macos-x86_64,macos-arm_64,macos-universal,windows-x86_64,windows-arm_64}"
