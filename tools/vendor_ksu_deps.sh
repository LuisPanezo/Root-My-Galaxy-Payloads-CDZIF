#!/usr/bin/env bash
# Replace the git dependencies of the ksud/ksuinit cargo workspaces with
# local path dependencies fetched via codeload tarballs (locked SHAs from
# the KernelSU v3.2.5 Cargo.lock).
# Usage: vendor_ksu_deps.sh <ksud-checkout-dir>
set -euo pipefail
KSUD_DIR="${1:?ksud checkout dir required}"
DEPS="$KSUD_DIR/cargo-vendor-deps"
rm -rf "$DEPS"; mkdir -p "$DEPS"; cd "$DEPS"

fetch() {
  for i in 1 2 3 4 5; do
    timeout 120 curl -sL --connect-timeout 20 -o "$2" "$1" && return 0
    echo "retry $2 ($i)"; sleep 3
  done
  return 1
}

fetch https://codeload.github.com/5ec1cff/android_bootimg/tar.gz/153423f6310fd4ae187e32da48e97b9fc613b783 android_bootimg.tgz
fetch https://codeload.github.com/KernelSU2/java-properties/tar.gz/42a4aa941b70ded2dd3be9e9f892471023e70229 java-properties.tgz
fetch https://codeload.github.com/KernelSU2/adb_client/tar.gz/d97a966435bebaa55017834869dec08150826aa7 adb_client.tgz
fetch https://codeload.github.com/KernelSU2/ksu_props/tar.gz/699849f3e4db47b622bcb7fae8e76c728b1b65a6 prop-rs-android.tgz
fetch https://codeload.github.com/KernelSU2/rustix/tar.gz/4a53fbc7cb7a07cabe87125cc21dbc27db316259 rustix.tgz
fetch https://codeload.github.com/kstep/kernlog.rs/tar.gz/68caa7bf1e27baea35b00ebba786cafae0bca90f kernlog.tgz

mkdir -p android_bootimg java-properties adb_client prop-rs-android rustix kernlog
tar xzf android_bootimg.tgz -C android_bootimg --strip-components=1
tar xzf java-properties.tgz -C java-properties --strip-components=1
tar xzf adb_client.tgz -C adb_client --strip-components=1
tar xzf prop-rs-android.tgz -C prop-rs-android --strip-components=1
tar xzf rustix.tgz -C rustix --strip-components=1
tar xzf kernlog.tgz -C kernlog --strip-components=1

# adb_client's crate manifest inherits version/edition/etc. from a workspace
# root that does not define them; materialize the inheritance so the crate
# works as a plain path dependency from a foreign workspace.
python3 - <<'PYEOF'
from pathlib import Path

manifest = Path("adb_client/adb_client/Cargo.toml")
data = manifest.read_text()
replacements = {
    'version.workspace = true': 'version = "3.1.1"',
    'edition.workspace = true': 'edition = "2021"',
    'authors.workspace = true': '',
    'keywords.workspace = true': '',
    'license.workspace = true': '',
    'repository.workspace = true': '',
    'rust-version.workspace = true': '',
}
for old, new in replacements.items():
    data = data.replace(old, new)
manifest.write_text(data)
print("adb_client manifest materialized")
PYEOF

export DEPS
export KSUD_DIR
python3 - <<'PYEOF'
import os
from pathlib import Path

deps = Path(os.environ["DEPS"])
ksud = Path(os.environ["KSUD_DIR"])

def sub(path: Path, pairs):
    data = path.read_text()
    for old, new in pairs:
        if old in data:
            data = data.replace(old, new, 1)
        elif new in data:
            continue
        else:
            raise SystemExit(f"pattern missing in {path}: {old[:70]!r}")
    path.write_text(data)

sub(ksud / "Cargo.toml", [
    ('android-bootimg = { git = "https://github.com/5ec1cff/android_bootimg", rev = "153423f6310fd4ae187e32da48e97b9fc613b783" }',
     f'android-bootimg = {{ path = "{deps}/android_bootimg/android-bootimg" }}'),
    ('java-properties = { git = "https://github.com/Kernel-SU/java-properties.git", branch = "master", default-features = false }',
     f'java-properties = {{ path = "{deps}/java-properties", default-features = false }}'),
    ('adb_client = { git = "https://github.com/Kernel-SU/adb_client" }',
     f'adb_client = {{ path = "{deps}/adb_client/adb_client" }}'),
    ('prop-rs-android = { git = "https://github.com/Kernel-SU/ksu_props" }',
     f'prop-rs-android = {{ path = "{deps}/prop-rs-android/crates/prop-rs-android" }}'),
])

sub(ksud.parent / "ksuinit" / "Cargo.toml", [
    ('rustix = { git = "https://github.com/Kernel-SU/rustix.git", rev = "4a53fbc", features = ["mount", "fs", "runtime", "system", "process"] }',
     f'rustix = {{ path = "{deps}/rustix", features = ["mount", "fs", "runtime", "system", "process"] }}'),
    ('kernlog = { git = "https://github.com/kstep/kernlog.rs" }',
     f'kernlog = {{ path = "{deps}/kernlog" }}'),
])
print("VENDORED_OK")
PYEOF
