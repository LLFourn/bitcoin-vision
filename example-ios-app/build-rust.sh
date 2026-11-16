#!/usr/bin/env bash
# Builds the app's native half and everything the Xcode project expects
# beside it, the way the Android app's Gradle preBuild does:
#
#   build/BitcoinVisionMobile.xcframework  the bridge crate as a static library
#                                          for devices and the arm64 simulator
#   build/generated/                       the UniFFI Swift bindings
#   build/Resources/                       models, fonts and license notices
#
# The bridge crate is the Android app's: example-android-app/rust holds the
# one `bitcoin-vision-mobile`, and both apps bind to it. Nothing here runs
# a toolchain installer; the two iOS targets must already be added:
#
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim
#
# Usage: ./build-rust.sh [device|simulator|all]   (default: all)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
native="$root/example-android-app/rust"
out="$here/build"
export CARGO_TARGET_DIR="$out/rust"

# Xcode runs build phases with a bare PATH; find the rustup Cargo the way a
# shell would.
if ! command -v cargo >/dev/null 2>&1 && [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
fi
# Xcode's environment points the linker at the iOS SDK it is building for;
# the host-side bindings generator must not inherit that.
unset SDKROOT IPHONEOS_DEPLOYMENT_TARGET MACOSX_DEPLOYMENT_TARGET

which="${1:-all}"
case "$which" in
    device) targets=(aarch64-apple-ios) ;;
    simulator) targets=(aarch64-apple-ios-sim) ;;
    all) targets=(aarch64-apple-ios aarch64-apple-ios-sim) ;;
    *) echo "build-rust.sh: expected device, simulator or all, not $which" >&2; exit 2 ;;
esac

export IPHONEOS_DEPLOYMENT_TARGET=17.0
for target in "${targets[@]}"; do
    # The crate declares lib + cdylib for Android; iOS links a static archive.
    (cd "$native" && cargo rustc --locked --release -p bitcoin-vision-mobile --lib \
        --target "$target" --crate-type staticlib)
done
unset IPHONEOS_DEPLOYMENT_TARGET

# Xcode runs this before every build, and judges what to recompile, relink and
# re-copy by timestamps. So each output is made aside and takes its place only
# if it differs from what is there: a build that changed no Rust touches nothing.
stage="$out/staging"
rm -rf "$stage"
mkdir -p "$stage"
settle() {
    if [ -e "$2" ] && diff -rq "$1" "$2" >/dev/null 2>&1; then
        rm -rf "$1"
    else
        rm -rf "$2"
        mv "$1" "$2"
    fi
}

# Bindings come from the metadata in the built library, so any one target serves.
lib="$CARGO_TARGET_DIR/${targets[0]}/release/libbitcoin_vision_mobile.a"
gen="$stage/generated"
mkdir -p "$gen"
(cd "$native" && cargo run --locked --release -p bitcoin-vision-mobile --features bindgen \
    --bin uniffi-bindgen -- generate --library "$lib" --language swift --out-dir "$gen")

headers="$stage/headers"
mkdir -p "$headers"
cp "$gen/bitcoin_vision_mobileFFI.h" "$headers/"
cp "$gen/bitcoin_vision_mobileFFI.modulemap" "$headers/module.modulemap"

xcf="$stage/BitcoinVisionMobile.xcframework"
args=()
for target in aarch64-apple-ios aarch64-apple-ios-sim; do
    a="$CARGO_TARGET_DIR/$target/release/libbitcoin_vision_mobile.a"
    # A platform not rebuilt this time keeps its last archive, if there is one.
    [ -f "$a" ] && args+=(-library "$a" -headers "$headers")
done
xcodebuild -create-xcframework "${args[@]}" -output "$xcf" >/dev/null

res="$stage/Resources"
mkdir -p "$res/models" "$res/fonts" "$res/licenses"
cp "$root/penlock-scan/models/cell-reference.onnx" "$res/models/"
for name in word-detector.onnx word-reference.onnx word-reference.calibration \
    text-recogniser.onnx text-recogniser.dict.txt; do
    cp "$root/words/models/$name" "$res/models/"
done
cp "$root/forms/fonts/IBMPlexMono-Regular.ttf" "$root/forms/fonts/IBMPlexSans-Variable.ttf" "$res/fonts/"
cp "$root/LICENSE" "$root/LICENSE-APACHE" "$res/licenses/"
cp "$root/words/models/NOTICE" "$res/licenses/PADDLE-NOTICE"
cp "$root"/forms/fonts/OFL-*.txt "$res/licenses/"

for made in generated headers BitcoinVisionMobile.xcframework Resources; do
    settle "$stage/$made" "$out/$made"
done
rmdir "$stage"

echo "build-rust.sh: built ${targets[*]}"
