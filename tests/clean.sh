#!/bin/bash

function remove() {
    FILE="$1"
    echo "remove '$FILE'"
    rm -Rf "$FILE"
}

remove dist
./clean-common-files.sh
