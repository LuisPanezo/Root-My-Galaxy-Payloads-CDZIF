#!/usr/bin/env python3
"""Apply the Samsung Kbuild hunks to a KernelSU checkout (CRLF-aware).

Usage: fix_ksu_kbuild.py <KernelSU-checkout-dir>
"""
import sys
from pathlib import Path

repo = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
path = repo / "kernel" / "Kbuild"
data = path.read_bytes().decode("utf-8")
nl = "\r\n" if "\r\n" in data else "\n"

replacements = [
    ("kernelsu-objs := core/init.o" + nl + nl,
     "kernelsu-objs := core/init.o" + nl + nl +
     "kernelsu-objs += compat/samsung_kdp.o" + nl +
     "kernelsu-objs += compat/samsung_defex.o" + nl + nl),

    ("ifeq ($(CONFIG_KSU_DEBUG),y)" + nl +
     "ccflags-y += -DCONFIG_KSU_DEBUG=1" + nl +
     "endif" + nl +
     "endif" + nl + nl,
     "ifeq ($(CONFIG_KSU_DEBUG),y)" + nl +
     "ccflags-y += -DCONFIG_KSU_DEBUG=1" + nl +
     "endif" + nl +
     "ifeq ($(CONFIG_KSU_SAMSUNG_KDP),y)" + nl +
     "ccflags-y += -DCONFIG_KSU_SAMSUNG_KDP=1" + nl +
     "endif" + nl +
     "ifeq ($(CONFIG_KSU_SAMSUNG_RKP),y)" + nl +
     "ccflags-y += -DCONFIG_KSU_SAMSUNG_RKP=1" + nl +
     "endif" + nl +
     "ifeq ($(CONFIG_KSU_SAMSUNG_DEFEX),y)" + nl +
     "ccflags-y += -DCONFIG_KSU_SAMSUNG_DEFEX=1" + nl +
     "endif" + nl +
     "ifeq ($(CONFIG_KSU_SAMSUNG_NO_PATCH_TEXT),y)" + nl +
     "ccflags-y += -DCONFIG_KSU_SAMSUNG_NO_PATCH_TEXT=1" + nl +
     "endif" + nl +
     "endif" + nl + nl),

    ("ccflags-y += -I$(srctree)/security/selinux -I$(srctree)/security/selinux/include" + nl,
     "ccflags-y += -I$(srctree)/security/selinux -I$(srctree)/security/selinux/include" + nl +
     "ccflags-y += -I$(objtree)/security/selinux -I$(objtree)/security/selinux/include" + nl),

    ("ccflags-y += -I$(KSU_KERNEL_DIR) -I$(KSU_KERNEL_DIR)/include" + nl,
     "ccflags-y += -I$(KSU_KERNEL_DIR) -I$(KSU_KERNEL_DIR)/include -I$(KSU_KERNEL_DIR)/.." + nl),

    ('$(warning "KSU_GIT_VERSION not defined! It is better to make KernelSU a git repository!")' + nl +
     "ccflags-y += -DKSU_VERSION=16" + nl,
     '$(warning "KSU_GIT_VERSION not defined! It is better to make KernelSU a git repository!")' + nl +
     "KSU_VERSION ?= 32525" + nl +
     "$(info -- KernelSU fallback version: $(KSU_VERSION))" + nl +
     "ccflags-y += -DKSU_VERSION=$(KSU_VERSION)" + nl),
]

for old, new in replacements:
    if old not in data:
        if new.split(nl)[0] in data:
            continue  # already applied
        sys.exit(f"Kbuild pattern not found: {old[:80]!r}")
    data = data.replace(old, new, 1)

path.write_bytes(data.encode("utf-8"))
print("KBUILD_PATCHED_OK")
