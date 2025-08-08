#!/bin/bash

function remove() {
    FILE="$1"
    echo "remove '$FILE'"
    rm -Rf "$FILE"
}

remove ignored/icu4c-library
remove ignored/sh-sources
remove ignored/*.cpp
remove ignored/*.hpp
remove ignored/install-zig.sh
remove ignored/versions.env
