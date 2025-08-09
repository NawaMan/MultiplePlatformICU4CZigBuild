#!/bin/bash

source versions.env
source sh-sources/common-source.sh

source sh-sources/zig-source.sh
download-zig $ZIG_VERSION    /tmp/zig.tar.xz
extract-zig  /tmp/zig.tar.xz /opt/zig

echo 
print_status "ZIG vesion: "$(zig version)
