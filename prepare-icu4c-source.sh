#!/bin/bash

BUILD_DIR=${1:-$(pwd)/build}
BUILD_LOG=$BUILD_DIR/build.log

mkdir -p "$BUILD_DIR"
touch    "$BUILD_LOG"

source versions.env
source sh-sources/common-source.sh

source sh-sources/icu4c-source.sh
download-icu4c $ICU_VERSION $BUILD_DIR/icu4c-source.tgz
extract-icu4c  $BUILD_DIR/icu4c-source.tgz $BUILD_DIR/icu4c-source
