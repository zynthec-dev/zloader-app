#!/bin/sh
# Restore the exact upstream OpenSSL distribution required by the container signer.
set -eu
cd "$(dirname "$0")/../.."
revision=623c84da314e85363236507ca38a4bde65df21c3
cache="$PWD/.build/LiveContainerOpenSSL"
if [ ! -d "$cache/.git" ]; then
    git clone --no-checkout https://github.com/krzyzanowskim/OpenSSL.git "$cache"
    git -C "$cache" checkout --detach "$revision"
fi
test "$(git -C "$cache" rev-parse HEAD)" = "$revision"
test -d "$cache/Frameworks/OpenSSL.xcframework"
if [ ! -e Vendor/LiveContainer/OpenSSL ]; then
    ln -s ../../.build/LiveContainerOpenSSL Vendor/LiveContainer/OpenSSL
fi
test "$(cd Vendor/LiveContainer/OpenSSL && pwd -P)" = "$cache"
