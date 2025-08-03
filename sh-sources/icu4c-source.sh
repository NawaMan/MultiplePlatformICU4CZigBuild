
# SOURCE ME - DO NOT RUN

download-icu4c() {
    ICU_VERSION=$1
    ICU4C_FILE=$2


    if [ "$ICU_VERSION" == "" ]; then
        exit_with_error "ICU_VERSION is not set!"
    fi

    print "Ensure ICU source"
    if [ ! -f "$ICU4C_FILE" ]; then
        ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"
        print "📥 Downloading ICU4C..."
        curl -L -o $ICU4C_FILE "$ICU_URL"
        print ""
    fi
}

extract-icu4c() {
    ICU4C_FILE=$1
    ICU4C_DIR=$2

    print "📦 Extracting ICU to $ICU4C_DIR ..."
    rm -rf $ICU4C_DIR
    mkdir $ICU4C_DIR
    pushd $ICU4C_DIR 1> /dev/null

    tar -xzf $ICU4C_FILE --strip-components=1

    popd 1> /dev/null

    echo "END: extract-icu4c"
    pwd
    ls  -la
}