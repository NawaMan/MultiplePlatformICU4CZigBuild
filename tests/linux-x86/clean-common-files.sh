#!/bin/bash

function remove() {
    FILE="$1"
    echo "remove '$FILE'"
    rm -Rf "$FILE"
}

remove icu4c-library
remove sh-sources
remove *.cpp
remove *.hpp
remove install-zig.sh
remove versions.env
