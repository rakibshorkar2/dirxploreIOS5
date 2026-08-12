#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="ios/Runner/Torrent/LibTorrent"

OPENSSL_ROOT="$(brew --prefix openssl@3 2>/dev/null || echo /opt/homebrew/opt/openssl@3)"
if [ ! -d "$OPENSSL_ROOT" ]; then
    echo "OpenSSL not found at $OPENSSL_ROOT. Install with: brew install openssl@3" >&2
    exit 1
fi

echo "==> Configuring libtorrent (cmake -G Xcode)"
cmake "$ROOT/Thirdparty/libtorrent" \
    -B "$ROOT/libtorrent-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -G Xcode \
    -DCMAKE_XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST=YES \
    -DCMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS="iphoneos" \
    -DCMAKE_CXX_FLAGS="-DTORRENT_HAVE_MMAP=0 -DNDEBUG" \
    -Ddeprecated-functions=OFF \
    -Dwebtorrent=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT"

echo "==> Building torrent-rasterbar (release, arm64)"
xcodebuild -project "$ROOT/libtorrent-build/libtorrent.xcodeproj" \
    -target torrent-rasterbar \
    -configuration Release \
    -sdk iphoneos \
    -arch arm64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

LIB="$(find "$ROOT/libtorrent-build" -name libtorrent-rasterbar.a -path "*Release*" | head -n 1)"
if [ -z "$LIB" ]; then
    echo "libtorrent-rasterbar.a not found after build" >&2
    exit 1
fi
cp "$LIB" "$ROOT/libtorrent-rasterbar.a"
echo "==> Installed $ROOT/libtorrent-rasterbar.a"