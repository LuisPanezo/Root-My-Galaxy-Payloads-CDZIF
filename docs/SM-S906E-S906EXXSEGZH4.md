# SM-S906E / S906EXXSEGZH4 porting record

Offline port of the Galaxy S22+ US-LatAm Snapdragon firmware
`S906EXXSEGZH4` to the r0q CVE-2026-43499 payload. There is **no target
handset**: the profile is static-analysis and build verified only, exactly
like the SM-A155N record. Every offset below was derived from this exact
build; nothing was copied from another target except the branch-shared
layout constants noted explicitly.

## Firmware identity

| Field | Verified value |
| --- | --- |
| Package model | `SM-S906E` |
| Region | `ARO` (same AP binary across ARO/COO/TPA) |
| AP/PDA package | `S906EXXSEGZH4` |
| Internal build | `S906EXXSEGZH4` (kernel banner `abS906EXXSEGZH4`) |
| Device codename | `r0q` (Snapdragon 8 Gen 1, SM8450) |
| Kernel release | `5.10.236-android12-9-31998796-abS906EXXSEGZH4` |

## Verified chain

| Object | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| Firmware package `S906EXXSEGZH4_ARO.zip` | 10,261,312,009 | `C2C299F52BB488B73A96667260493885D8BEC0C40AA6AE6F7EBE071C03B7861D` |
| Decompressed `boot.img` | 100,663,296 | `713ED05A1353DCFC3CD9A7258E8532981375F0835F8CA4D35E68D458B9A9E957` |
| Raw kernel payload | 41,495,040 | `003BAC655D3359B236147BE519ACCCECD5DBDDE11BF3C71DCF1BA8007FB571F2` |

ARM64 Image header: `text_offset = 0`, `image_size = 0x2a50000`,
`flags = 0xa`, magic `ARMd`.

## Symbol recovery

`vmlinux-to-elf` recovered 112,596 defined symbols with base
`0xffffffc008000000`. The target has **no BTF** (android12-5.10), so the
structure layouts follow the android12-9 branch values verified for
`a15-A155NKSS6BYH1` — same GKI KMI, same `NR_CPUS=8` — and were then
confirmed directly against this target's static `init_task` image:

```text
init_task.sched_task_group @ 0x310 == &root_task_group  (exact pointer match)
init_task.usage @ 0x40 == 2
init_task.prio @ 0x84 == 120; normal_prio @ 0x8c == 120
pi_lock @ 0x86c == 0; pi_waiters @ 0x880 == {0,0}
pi_top_task @ 0x890 == 0; pi_blocked_on @ 0x898 == 0
```

All required symbols were present with 5.10 names (`configfs_read_file`,
`configfs_write_bin_file`, `generic_file_splice_read`). Per-build offsets
relative to `KIMAGE_TEXT_BASE`:

| Use | Symbol/derivation | Offset |
| --- | --- | ---: |
| UMH callback | `call_usermodehelper_exec_work` | `0x001086b4` |
| worker wchan | instruction after `bl schedule` in `worker_thread` | `0x00112ae0` |
| no-op seek | `noop_llseek` | `0x004c3694` |
| splice read | `generic_file_splice_read` | `0x0053866c` |
| configfs read | `configfs_read_file` | `0x006040d8` |
| configfs write | `configfs_write_bin_file` | `0x00604a68` |
| ashmem ioctl | `ashmem_ioctl` | `0x0114ab24` |
| ashmem compat ioctl | `compat_ashmem_ioctl` | `0x0114b5f0` |
| ashmem mmap | `ashmem_mmap` | `0x0114b648` |
| ashmem open | `ashmem_open` | `0x0114b878` |
| ashmem release | `ashmem_release` | `0x0114b910` |
| ashmem fdinfo | `ashmem_show_fdinfo` | `0x0114ba2c` |
| pipe ops | `anon_pipe_buf_ops` | `0x01f03a28` |
| ashmem fops | `ashmem_fops` | `0x02080db8` |
| kmalloc table | `kmalloc_caches` | `0x020c2fa0` |
| `"nfnetlink_log"` string | `nfulnl_logger.name` target | `0x01dfa083` |
| unbound workqueue | `system_unbound_wq` | `0x02589e08` |
| netfilter logger object | `nfulnl_logger` | `0x02591348` |
| initial task | `init_task` | `0x0259c000` |
| root task group | `root_task_group` | `0x0279c040` |
| SELinux enforcing | `selinux_state.enforcing` | `0x028cdcd8` |
| ashmem misc fops | `ashmem_misc + 0x10` | `0x026ecd28` |
| boot-ID sysctl storage | `sysctl_bootid` | `0x0296dd45` |
| boot-ID ctl-table data pointer | unique `&sysctl_bootid` qword | `0x026acb50` |

The boot-id pointer had exactly one hit in the raw Image, with the `boot_id`
procname pointer verified in the preceding qword of the enclosing ctl-table
entry. `selinux_state.enforcing` is the first member
(`CONFIG_SECURITY_SELINUX_DEVELOP=y`, consistent with the 6.6 BTF record
where enforcing is also at 0).

`__TRACE_LAST_TYPE` is 17 on this branch (18 `trace_type` members,
zero-indexed, verified in the s5e9925 android12-9 source);
`__event_sched_blocked_reason - __start_ftrace_events` = `0x218` = 67
entries; the runtime event ID is `17 + 67 = 84` (same as the A15 record,
as expected for a shared KMI). `SLIDE_PSELECT_WORD_SHIFT = 0` and
`SKB_DATA_DELTA = -0xe80` carry from the same-branch A15 values.

## Physical map

All vendor_boot DTBs carry `/reserved-memory/hyp_region@80000000`, fixing
the lowest RAM base at `0x80000000` (Qualcomm SM8450):

```c
#define P0_PHYS_OFFSET 0x80000000ULL
#define P0_KERNEL_PHYS_LOAD 0x80080000ULL
```

`P0_KERNEL_PHYS_LOAD` uses the Qualcomm ABL constant
`memory_base + 0x00080000 + text_offset(0)` verified for this ABL lineage
by the hardware-tested `e3q-S928USQS6DZF2` record; the DTB anchor is
identical. The LinuxLoader constants could not be extracted from the
compressed ABL volume offline. The P0 fingerprint gate fails safe if this
carried value is wrong (no fingerprint row matches; no write occurs).
Hardware validation is pending.

`tools/generate_p0_fingerprint` produced all 32 candidate rows at probe
`0x1f0000` from the raw Image and independently read back all 256 source
qwords at offsets `0x000` through `0xe00`.

## Payload build

The release target builds at 92,072 bytes and is padded to the fixed
104,128-byte release size:

```text
artifacts/r0q-S906EXXSEGZH4/cve-2026-43499-app.so
size 104128
SHA-256 afeca30fe1f066673eed47adc7905d919b04dacee8cb4173e1028ea1cd7327ba
```

## KernelSU late-load artifacts

Built in CI with the DDK image
`ghcr.io/ylarod/ddk-min:android12-5.10-20260828` (matching GKI tree),
KernelSU `v3.2.5` + Samsung KDP/RKP/DEFEX patch, `UTS_RELEASE`/`kernel.release`
replaced with the exact target release, `KSU_VERSION=32525`. The module must
report exactly:

```text
vermagic: 5.10.236-android12-9-31998796-abS906EXXSEGZH4 SMP preempt mod_unload modversions aarch64
```

`check_symbol` runs against the recovered target `vmlinux.elf` (retained as
the `analysis-s906e` release asset of this repository). The KO keeps a
zero-length `__versions` section for the kallsyms-based manual relocation
loader. `ksud` embeds the KO as the `android12-5.10_kernelsu.ko` asset and
is rebuilt from the same tree.

## Hardware validation

**PENDING — no handset available.** This profile follows the SM-A155N
precedent: static analysis and reproducible build verification only. It
must be validated on an `SM-S906E` running exact firmware `S906EXXSEGZH4`
before it can be considered device-tested.
