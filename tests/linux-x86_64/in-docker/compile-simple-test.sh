#!/bin/bash

INC_DIR=icu4c-library/linux-x86_64/include
LIB_DIR=icu4c-library/linux-x86_64/lib

zig c++          \
    -std=c++20   \
    src/*.cpp    \
    -I.          \
    -I"$INC_DIR" \
    -L"$LIB_DIR" \
    -licuuc      \
    -licui18n    \
    -licudata    \
    -licuio      \
    -o simple-test
