#!/usr/bin/env bash
# Build the KernelSU late-load pair for one exact Samsung target inside CI.
# Usage: build-r0q-ksu.sh  (parameters via env)
#   KERNEL_RELEASE  exact `uname -r` of the target firmware
#   TARGET          profile id, e.g. r0q-S906EXXSEGZH4
#   KMI             asset KMI name, e.g. android12-5.10
#   DDK_IMAGE       ghcr ddk-min tag
#   VMLINUX         path to the recovered target vmlinux.elf (check_symbol)
set -euo pipefail

: "${KERNEL_RELEASE:?}" "${TARGET:?}" "${KMI:?}" "${DDK_IMAGE:?}"
VMLINUX="${VMLINUX:-}"

WS="$PWD/ksu-build"
mkdir -p "$WS"
cd "$WS"

# 1. KernelSU v3.2.5 + Samsung KDP/RKP/DEFEX patch + Kbuild fix
git clone --depth 1 --branch v3.2.5 --quiet https://github.com/tiann/KernelSU.git KernelSU
cd KernelSU
git apply --whitespace=nowarn "$GITHUB_WORKSPACE/kernelsu/patches/KernelSU-v3.2.5-samsung-kdp-rkp-defex.patch"
python3 "$GITHUB_WORKSPACE/tools/fix_ksu_kbuild.py" "$PWD"
make -C kernel check_symbol CC=gcc >/dev/null
echo "=== patch state ok"

# 2. module build inside the DDK container
echo "=== building kernelsu.ko (release: $KERNEL_RELEASE)"
sudo docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace/kernel \
  "$DDK_IMAGE" \
  bash -lc '
    set -e
    printf "%s\n" "'"$KERNEL_RELEASE"'" > "$KDIR/include/config/kernel.release"
    sed -i "s|^#define UTS_RELEASE .*|#define UTS_RELEASE \"'"$KERNEL_RELEASE"'\"|" \
      "$KDIR/include/generated/utsrelease.h"
    cat "$KDIR/include/config/kernel.release"
    make -C "$KDIR" M=/workspace/kernel src=/workspace/kernel clean >/dev/null
    make -C "$KDIR" M=/workspace/kernel src=/workspace/kernel \
      CONFIG_KSU=m CONFIG_KSU_SAMSUNG_KDP=y CONFIG_KSU_SAMSUNG_RKP=y \
      CONFIG_KSU_SAMSUNG_DEFEX=y KSU_VERSION=32525 CC=clang -j"$(nproc)" modules
    modinfo ./kernelsu.ko | grep vermagic
    cp "$KDIR/vmlinux.symvers" /workspace/ 2>/dev/null || true
  '

if [ -n "$VMLINUX" ]; then
  echo "=== check_symbol vs recovered target vmlinux"
  ./kernel/check_symbol kernel/kernelsu.ko "$VMLINUX"
fi

# 3. strip and embed
NDK_VERSION=android-ndk-r28b
if [ ! -d "$HOME/$NDK_VERSION" ]; then
  curl -sL --retry 5 -o /tmp/ndk.zip https://dl.google.com/android/repository/$NDK_VERSION-linux.zip
  unzip -q /tmp/ndk.zip -d "$HOME"
fi
NDKBIN="$HOME/$NDK_VERSION/toolchains/llvm/prebuilt/linux-x86_64/bin"
"$NDKBIN/llvm-strip" -d kernel/kernelsu.ko
cp kernel/kernelsu.ko "userspace/ksud/bin/aarch64/${KMI}_kernelsu.ko"

# 4. vendor ksud git deps (registry/network quirks) and build
# pin the toolchain to the version the payload repo maintains (rust-embed's
# derive output breaks on older rustc)
rustup toolchain install 1.99.1 --profile minimal
rustup target add aarch64-linux-android --toolchain 1.99.1
export RUSTUP_TOOLCHAIN=1.99.1
cd userspace/ksud
bash "$GITHUB_WORKSPACE/tools/vendor_ksu_deps.sh" "$PWD"
rm -f ../../Cargo.lock
export PATH="$NDKBIN:$HOME/.cargo/bin:$PATH"
export LIBCLANG_PATH="$HOME/$(basename "${NDK_VERSION:-android-ndk-r28b}")/toolchains/llvm/prebuilt/linux-x86_64/lib"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$NDKBIN/aarch64-linux-android35-clang"
export CC_aarch64_linux_android="$NDKBIN/aarch64-linux-android35-clang"
export AR_aarch64_linux_android="$NDKBIN/llvm-ar"
cargo build --release --target aarch64-linux-android -p ksud

OUT="$GITHUB_WORKSPACE/ksu-artifacts"
mkdir -p "$OUT"
cp target/aarch64-linux-android/release/ksud "$OUT/ksud-${TARGET}-kdp"
cp userspace/ksud/bin/aarch64/${KMI}_kernelsu.ko "$OUT/${KMI}_kernelsu-${TARGET}-kdp.ko"
ls -la "$OUT"
