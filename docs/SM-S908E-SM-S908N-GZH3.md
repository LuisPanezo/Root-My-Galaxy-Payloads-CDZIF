# SM-S908E / SM-S908N (S908EXXSEGZH4 / S908NKSS9GZH3) porting record

Offline port of the Galaxy S22 Ultra September 2026 security builds to the
b0q CVE-2026-43499 payload. There is no target handset: the profiles are
static-analysis and build verified only.

Note: the Galaxy S22 Ultra shipped Snapdragon 8 Gen 1 (SM8450) worldwide —
there is no Exynos Ultra. The S908E (ARO) and S908N (KOO) packages carry
sister builds of the same GKI kernel generation.

## Firmware identity

| Field | SM-S908E | SM-S908N |
| --- | --- | --- |
| Region | ARO | KOO |
| AP/PDA | `S908EXXSEGZH4` | `S908NKSS9GZH3` |
| Kernel release | `5.10.236-android12-9-31998796-abS908EXXSEGZH4` | `5.10.236-android12-9-31998796-abS908NKSS9GZH3` |

## Verified chain

| Object | SM-S908E | SM-S908N |
| --- | --- | --- |
| Package SHA-256 | `F673826A806A817001E06CA10F813655447BD1C2AE18D90129DD5AA5D88FC1EC` | (see feed history) |
| boot.img SHA-256 | `A48907A8B3F5A274F9B7E5F04FB4538A227B20F3AD87B9EC0866747517172CBE` | `D9AD1CBA1A138D37A08C9F4CCEB91D500D73C44DD230B3ACB776E5D6E937164B` |
| kernel SHA-256 | `677C00EDE6D420C5B3E9CBE303542EFF8557A22FAC0666CBAE848B1D7165281C` | `45EDAD6E2D2A8AA7135E48FE7CE49B97AC444837433A0AC8ABD8C4B2E2D756E0` |

ARM64 Image header: `text_offset = 0`, `flags = 0xa`, magic `ARMd`.
No BTF in either build (android12-5.10).

## Symbol recovery

`vmlinux-to-elf` recovered both images with base `0xffffffc008000000`
(112,596 symbols each). The `.text` layout is byte-identical to the
r0q-S906EXXSEGZH4 kernel (same GKI `31998796` build): every text symbol
offset matches (call_usermodehelper_exec_work 0x001086b4, worker_thread
0x00112588, worker caller 0x00112ae0, configfs_read_file 0x006040d8,
ashmem chain 0x0114ab24.., event index 67 -> event ID 84 with
`__TRACE_LAST_TYPE = 17`). The `.data` sections shift between the three
builds (S Pen/ultra device drivers), so the data symbols were re-derived
per build:

| Symbol | S906E (reference) | S908E | S908N |
| --- | ---: | ---: | ---: |
| `anon_pipe_buf_ops` | 0x01f03a28 | 0x01f03ee8 | 0x01f03aa8 |
| `ashmem_fops` | 0x02080db8 | 0x02081278 | 0x02080e38 |
| `kmalloc_caches` | 0x020c2fa0 | 0x020c3460 | 0x020c3020 |
| `nfulnl_logger.name` target | 0x01dfa083 | 0x01dfa505 | 0x01dfa091 |
| `loggers` / `nfulnl_logger` / `init_task` / `sysctl_bootid` / `random_table` / `root_task_group` / `selinux_state` / `ashmem_misc` | identical across all three builds | | |

The boot-ID data-pointer slot was located by the unique-qword search
(single hit per image). The task_struct layout (5.10 GKI: usage 0x40,
prio 0x84, sched_task_group 0x310, pi_lock 0x86c, pi_waiters 0x880) was
verified against each build's static `init_task`
(`sched_task_group@0x310 == &root_task_group` exact pointer match on both).

## Physical map

All vendor_boot DTBs anchor `hyp_region@80000000` (SM8450):

```c
#define P0_PHYS_OFFSET 0x80000000ULL
#define P0_KERNEL_PHYS_LOAD 0x80080000ULL
```

`P0_KERNEL_PHYS_LOAD` uses the Qualcomm ABL constant
`memory_base + 0x00080000 + text_offset(0)` verified for this platform
lineage by the hardware-tested e3q record; the DTB anchor is identical.
The P0 fingerprint gate fails safe if the carried value is wrong.

## Payloads, module and artifacts

Fingerprints: probe `0x1f0000`, 32 candidate rows at 0x10000 steps, all
256 source qwords read back per build.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `artifacts/b0q-S908EXXSEGZH4/cve-2026-43499-app.so` | 104,128 | `27e55f981209ee4f7f0c3af3d998ab5b4ef515e2506c90084dd03637e7a798b1` |
| `artifacts/b0q-S908NKSS9GZH3/cve-2026-43499-app.so` | 104,128 | `26918c80e33c93f86ffca7a28f0de3461d85aa1f7e98d61b6803eb6e56cb6bde` |
| `kernelsu/android12-5.10_kernelsu-b0q-S908EXXSEGZH4-kdp.ko` | 366,120 | `97b80671d1eeecc66cdba95a9833ab6f09bac943fe9080f03b1ac61c27cbd8fe` |
| `kernelsu/ksud-b0q-S908EXXSEGZH4-kdp` | 4,865,880 | `86a0e8256bede23ab5316c7631ee135c6d62853208a8dae423ef7d4363bd1fca` |
| `kernelsu/android12-5.10_kernelsu-b0q-S908NKSS9GZH3-kdp.ko` | 366,120 | `4fc6b66d740b749259e42d3d382727290e5c63ef21c141b4a03f6da897bc8c82` |
| `kernelsu/ksud-b0q-S908NKSS9GZH3-kdp` | 4,865,880 | `d7cd417932a557025848ebc0c00c6078d29f17f98efad65d365d9578e40d75e2` |

Both modules report their exact release vermagic (built in CI with the
DDK image `ghcr.io/ylarod/ddk-min:android12-5.10-20260828`), pass
`check_symbol` against their recovered target `vmlinux.elf` (release
assets `analysis-s908e` / `analysis-s908n`), and each `ksud` embeds its
KO as the `android12-5.10_kernelsu.ko` asset.

## Hardware validation

**PENDING — no handset available.** Static analysis and reproducible
build verification only. Validate on the exact builds above before
treating these profiles as device-tested.
