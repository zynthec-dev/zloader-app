#!/bin/sh
# Rebuild the pinned installer with a status-only acknowledgement fix.
# No dependency gitlink or published upstream artifact is changed.
set -eu
cd "$(dirname "$0")/../.."
root=$PWD
source_revision=3e55c8486b2057e40c1f74aaaa1155c82341cf76
rust_version=1.99.1
export CARGO_HOME="$root/.build/RustToolchain/cargo"
export RUSTUP_HOME="$root/.build/RustToolchain/rustup"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export PATH="$CARGO_HOME/bin:$PATH"
if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
    mkdir -p "$root/.build/RustToolchain"
    curl --fail --silent --show-error --location https://sh.rustup.rs -o "$root/.build/RustToolchain/rustup-init.sh"
    sh "$root/.build/RustToolchain/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain "$rust_version"
fi
case "$(rustc --version)" in
    "rustc $rust_version "*) ;;
    *) rustup toolchain install "$rust_version" --profile minimal; export RUSTUP_TOOLCHAIN="$rust_version" ;;
esac
# Corresponding-source archives already contain this library's patched source.
source="$root/VendorSources/BinaryTargets/idevice"
if [ ! -d "$source/idevice/src" ]; then
    source="$root/.build/PatchedIdevice/source"
    if [ ! -d "$source/.git" ]; then
        mkdir -p "$root/.build/PatchedIdevice"
        git clone --no-checkout https://github.com/SideStore/idevice.git "$source"
        git -C "$source" checkout --detach "$source_revision"
    fi
    test "$(git -C "$source" rev-parse HEAD)" = "$source_revision"
fi
patch="$root/zLoader/Patches/idevice-install-acknowledgement.patch"
if ! git -C "$source" apply --reverse --check "$patch" 2>/dev/null; then
    git -C "$source" apply --check "$patch"
    git -C "$source" apply "$patch"
fi
mode=${1:-ios}
if [ "$mode" = test ]; then
    cargo test --manifest-path "$source/Cargo.toml" -p idevice --locked --no-default-features --features installation_proxy,ring zloader_installation_tests
    exit 0
fi
case "$mode" in
    ios) target=aarch64-apple-ios; slice=ios-arm64; library=libidevice_ffi.a; export IPHONEOS_DEPLOYMENT_TARGET=26.5 ;;
    ios-simulator) target=aarch64-apple-ios-sim; slice=ios-arm64-simulator; library=idevice-ios-sim.a; export IPHONEOS_DEPLOYMENT_TARGET=26.5 ;;
    tvos) target=aarch64-apple-tvos; slice=tvos-arm64; library=libidevice_ffi.a; export TVOS_DEPLOYMENT_TARGET=26.0 ;;
    tvos-simulator) target=aarch64-apple-tvos-sim; slice=tvos-arm64-simulator; library=idevice-tvos-sim.a; export TVOS_DEPLOYMENT_TARGET=26.0 ;;
    *) echo "Unsupported installer build mode: $mode" >&2; exit 1 ;;
esac
rustup target add "$target"
cargo build --manifest-path "$source/Cargo.toml" -p idevice-ffi --release --locked --target "$target" --features obfuscate
artifact="$root/.build/SourcePackages/artifacts/devicegateway/IDevice/IDevice.xcframework/$slice/$library"
test -f "$artifact"
built="$source/target/$target/release/libidevice_ffi.a"
# Replace only the selected generated slice, atomically. SwiftPM's resolved
# upstream version/checksum and all other platform slices remain unchanged.
temporary=$(mktemp "$artifact.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
cp "$built" "$temporary"
mv "$temporary" "$artifact"
python3 - "$root" "$source_revision" "$target" "$built" <<'PY'
from pathlib import Path
import hashlib,json,sys
root,revision,target,built=sys.argv[1:]
built=Path(built)
receipt={'sourceRevision':revision,'target':target,'librarySHA256':hashlib.sha256(built.read_bytes()).hexdigest(),'patchSHA256':hashlib.sha256((Path(root)/'zLoader/Patches/idevice-install-acknowledgement.patch').read_bytes()).hexdigest()}
folder=Path(root)/'.build/PatchedIdevice';folder.mkdir(parents=True,exist_ok=True)
(folder/(target+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS patched installer slice:',target,receipt['librarySHA256'])
PY
