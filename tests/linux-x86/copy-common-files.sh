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

copy-dir  ../../build/icu4c-target icu4c-library
copy-dir  ../../sh-sources         sh-sources
copy-file ../*.cpp                 .
copy-file ../*.hpp                 .
copy-file ../../install-zig.sh     .
copy-file ../../versions.env       .
