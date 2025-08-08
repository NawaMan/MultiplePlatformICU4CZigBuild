#!/bin/bash

zig c++        \
    -std=c++17 \
    *.cpp      \
    -I.        \
    -lfmt      \
    -o simple-test
