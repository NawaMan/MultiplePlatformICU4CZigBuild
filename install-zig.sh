#!/bin/bash

# Detect OS
case "$(uname -s)" in
    Linux*)   OS="linux" ;;
    Darwin*)  OS="macos" ;;
    CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
    *)        
        echo "Error: Unsupported OS '$(uname -s)'. Only Linux, macOS, and Windows are supported."
        exit 1
        ;;
esac

# Detect architecture
case "$(uname -m)" in
    x86_64)  PLATFORM="x86_64" ;;
    aarch64) PLATFORM="aarch64" ;;
    *)       
        echo "Error: Unsupported architecture '$(uname -m)'. Only x86_64 and aarch64 are supported."
        exit 1
        ;;
esac

source versions.env
source sh-sources/common-source.sh
source sh-sources/zig-source.sh

download-zig "$ZIG_VERSION" /tmp/zig.tar.xz "$OS" "$PLATFORM"
extract-zig  /tmp/zig.tar.xz /opt/zig

echo
print_status "ZIG version: $(zig version)"
