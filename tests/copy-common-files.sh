#!/bin/bash

function copy-dir() {
    SRC="$1"
    TGT="$2"
    echo "copy files in '$SRC' to '$TGT'"
    cp -r "$SRC" "$TGT"
}

function copy-file() {
    SRC="$1"
    TGT="$2"
    echo "copy '$SRC' on to '$TGT'"
    cp "$SRC" "$TGT"
}

mkdir -p ignored
copy-dir  ../build/icu4c-target ignored/icu4c-library
copy-dir  ../sh-sources         ignored/sh-sources
copy-file ../install-zig.sh     ignored/
copy-file ../versions.env       ignored/
