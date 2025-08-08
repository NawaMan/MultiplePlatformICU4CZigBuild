#!/bin/bash

zig c++                               \
    -std=c++20                        \
    *.cpp                             \
    -I.                               \
    -Iicu4c-library/linux-x86/include \
    -lfmt                             \
    -o simple-test
