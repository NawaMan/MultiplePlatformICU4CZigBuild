#!/bin/bash

function build-test() {
    OS=$1
    ARC=$2
    BIT=${3:-64}

    OSNAME=${OS}

    INC_DIR=icu4c-library/${OSNAME}-${ARC}_${BIT}/include
    LIB_DIR=icu4c-library/${OSNAME}-${ARC}_${BIT}/lib

    TARGET=${ARC}_${BIT} ; [ "$TARGET" = "arm_64" ] && TARGET=aarch64
    TARGET=${TARGET}-${OSNAME}-musl

    zig c++ \
        -target $TARGET \
        -std=c++20      \
        src/*.cpp       \
        -O2             \
        -I.             \
        -I"$INC_DIR"    \
        -L"$LIB_DIR"    \
        -licui18n       \
        -licuuc         \
        -licudata       \
        -licuio         \
        -pthread        \
        -ldl            \
        -o dist/simple-test-${TARGET}
}

for OS in linux ; do
    for ARC in x86 arm ; do
        build-test $OS $ARC
    done
done
