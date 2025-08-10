
# SOURCE ME - DO NOT RUN

download-zig() {
    ZIG_VERSION=$1
    ZIG_FILE=$2
    OS=${3:-linux}
    PLATFORM=${4:-x86_64}

    if [ "$ZIG_VERSION" == "" ]; then
        exit_with_error "ZIG_VERSION is not set!"
    fi

    print "Ensure ZIG source"
    if [ ! -f "$ZIG_FILE" ]; then
        ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-${PLATFORM}-${OS}-${ZIG_VERSION}.tar.xz"
        print "📥 Downloading ZIG..."
        curl -L -o $ZIG_FILE "$ZIG_URL"
        print ""
    fi
}

extract-zig() {
    ZIG_FILE=$1
    ZIG_DIR=$2

    print "📦 Extracting ICU to $ZIG_DIR ..."
    sudo rm -rf $ZIG_DIR
    sudo mkdir -p $ZIG_DIR
    pushd $ZIG_DIR 1> /dev/null

    sudo tar -xf $ZIG_FILE --strip-components=1
    sudo ln -s /opt/zig/zig /usr/bin/zig

    popd 1> /dev/null

    echo "END: extract-zig"
    pwd
    ls  -la
}