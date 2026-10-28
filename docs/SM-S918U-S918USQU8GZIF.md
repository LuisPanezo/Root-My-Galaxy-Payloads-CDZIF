# SM-S918U / S918USQU8GZIF porting record

Offline port of the Galaxy S23 Ultra US unlocked firmware
`S918USQU8GZIF` (XAA, September 2026 security patch) to the dm3q
CVE-2026-43499 payload. There is no target handset: the profile is
static-analysis and build verified only. The write-path flavor choice is
documented below.

## Firmware identity

| Field | Verified value |
| --- | --- |
| Package model | `SM-S918U` |
| Region | `XAA` |
| AP/PDA package | `S918USQU8GZIF` |
| Device codename | `dm3q` (Snapdragon 8 Gen 2) |
| Kernel release | `5.15.197-android13-8-34343818-abS918USQU8GZIF` |

The previous catalog profiles for this family
(`dm3q-S918BXXSAFZF5`, `dm3q-S9180ZHS8FZF5`) cover the 2025 builds on
kernel 5.15.189; phones updated to the September 2026 patch run
5.15.197 and require this profile.

## Verified chain

| Object | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| Firmware package `S918USQU8GZIF_XAA.zip` | 12,279,786,664 | `CF221796CEC861C9D971058835DF6F5DB4B907C701A7441F73E3FDE49E3B3661` |
| Decompressed `boot.img` | 100,663,296 | `464DEF7EF465F67FA57E938AD4908CFDD53D25C3BEE197D231B4A2511B39618E` |
| Raw kernel payload | 46,860,800 | `4F6D4B2C6C219497DB51F90FCAD069785512DB803858F5598350563599743455` |

ARM64 Image header: `text_offset = 0`, `image_size = 0x2f50000`,
`flags = 0xa`, magic `ARMd`.

## Symbol recovery

`vmlinux-to-elf` recovered 126,452 defined symbols with base
`0xffffffc008000000`. The target **ships BTF**
(`[0x21f39dc, 0x27c4953)`, 6,098,807 bytes) — every structure layout below
is BTF-derived and matches the FZF5 record byte for byte:

```text
file_operations: ioctl 0x50; compat_ioctl 0x58; mmap 0x60; open 0x70;
  release 0x80; splice_read 0xc8; show_fdinfo 0xe0 (size 0x120)
task_struct: usage 0x38; prio 0x7c; normal_prio 0x84; sched_task_group 0x400;
  pi_lock 0x884; pi_waiters 0x898; pi_top_task 0x8a8; pi_blocked_on 0x8b0;
  cred 0x798; real_cred 0x790
rt_mutex_waiter (compact): task 0x30; lock 0x38; wake_state 0x40;
  prio 0x44; deadline 0x48; ww_ctx 0x50 (size 0x58)
configfs_buffer: page 0x10; needs_read_fill 0x50; bin_buffer 0x58;
  bin_buffer_size 0x60; cb_max_size 0x64
pool_workqueue: nr_active 0x5c; max_active 0x60; worker_pool: worklist 0x20;
  nr_idle 0x34; work_struct: data 0x00; entry 0x08; func 0x18
```

The static `init_task` image additionally verifies the task_struct offsets:
`sched_task_group@0x400 == &root_task_group` (exact pointer match),
`usage@0x38 == 2`, `prio/normal_prio @ 0x7c/0x84 == 120`.

Per-build symbol offsets relative to `KIMAGE_TEXT_BASE`:

| Use | Symbol/derivation | Offset |
| --- | --- | ---: |
| UMH callback | `call_usermodehelper_exec_work` | `0x00104888` |
| `prepare_kernel_cred` | | `0x0011e694` |
| `commit_creds` | | `0x001203d0` |
| `override_creds` | | `0x0011f4a8` |
| worker wchan | instruction after `bl schedule` in `worker_thread` | `0x0010ddfc` |
| no-op seek | `noop_llseek` | `0x004bc6b4` |
| splice read | `generic_file_splice_read` | `0x00528e28` |
| configfs read | `configfs_read_iter` | `0x005d8a1c` |
| configfs binary write | `configfs_bin_write_iter` | `0x005d9444` |
| ashmem ioctl | `ashmem_ioctl` | `0x011513a0` |
| ashmem compat ioctl | `compat_ashmem_ioctl` | `0x011519fc` |
| ashmem mmap | `ashmem_mmap` | `0x01151a54` |
| ashmem open | `ashmem_open` | `0x01151d34` |
| ashmem release | `ashmem_release` | `0x01151dcc` |
| ashmem fdinfo | `ashmem_show_fdinfo` | `0x01151ee8` |
| pipe ops | `anon_pipe_buf_ops` | `0x01e824e0` |
| ashmem fops | `ashmem_fops` | `0x020108b8` |
| kmalloc table | `kmalloc_caches` | `0x020679b0` |
| `"nfnetlink_log"` string | `nfulnl_logger.name` target | `0x01d60ff7` |
| unbound workqueue | `system_unbound_wq` | `0x02a90808` |
| netfilter logger object | `nfulnl_logger` | `0x02a91e50` |
| initial task | `init_task` | `0x02c05400` |
| root task group | `root_task_group` | `0x02cb9ac0` |
| SELinux enforcing | `selinux_state.enforcing` (offset 0) | `0x02d8e600` |
| ashmem misc fops | `ashmem_misc + 0x10` | `0x02bfd278` |
| boot-ID sysctl storage | `sysctl_bootid` | `0x02e6c131` |
| boot-ID ctl-table data pointer | unique `&sysctl_bootid` qword | `0x02bbabc8` |

`__TRACE_LAST_TYPE = 20` (BTF); `__event_sched_blocked_reason -
__start_ftrace_events` = `0x2c0` = 88 entries; the runtime event ID is
`20 + 88 = 108`, matching the FZF5 profile as expected for the shared KMI.

## Physical map and slide data

All vendor_boot DTBs anchor `hyp_region@80000000` (lowest RAM base):

```c
#define P0_PHYS_OFFSET 0x80000000ULL
#define P0_KERNEL_PHYS_LOAD 0xa7e58000ULL
```

`P0_KERNEL_PHYS_LOAD` carries the dm3q platform ABL load base recorded in
the FZF5 profile (bootloader-fixed; the FZF5 value already embeds that
platform's base, measured with device kallsyms). The P0 fingerprint gate
fails safe if the carried value is wrong. The probe is `0x1f8000` with
64 candidate rows at 0x8000 steps (all 256 source qwords independently
read back from the raw Image).

## Write-path flavor: SIGRETURN

The FZF5 profile ships the MCAST stack writer, whose `MCAST_WAITER_OFF`
derives from the compiler frame geometry of `do_ipv6_setsockopt`. That
geometry changed in GZIF (frame `0x2c0 -> 0x260`, disassembly-verified),
so the MCAST offset does not carry. This profile selects the SIGRETURN
stack writer (`SLIDE_STACK_WRITER=2`), whose waiter offsets
(`0x18` FPSIMD / `0x28` SVE) are arm64 signal-frame ABI constants and
stable across these builds.

## Payload build

The release target builds at 102,328 bytes and is padded to the fixed
104,128-byte release size:

```text
artifacts/dm3q-S918USQU8GZIF/cve-2026-43499-app.so
size 104128
SHA-256 e99487fdbdb930ad8c06cf670487f3dd1be6b4ce1483add14412f9a99b868a68
```

## KernelSU late-load artifacts

Built in CI with the DDK image
`ghcr.io/ylarod/ddk-min:android13-5.15-20260828`, KernelSU `v3.2.5` +
Samsung KDP/RKP/DEFEX patch, `UTS_RELEASE`/`kernel.release` replaced with
the exact target release. The module must report exactly:

```text
vermagic: 5.15.197-android13-8-34343818-abS918USQU8GZIF SMP preempt mod_unload modversions aarch64
```

`check_symbol` runs against the recovered target `vmlinux.elf` (release
asset `analysis-s918u` of this repository). `ksud` embeds the KO as the
`android13-5.15_kernelsu.ko` asset.

## Hardware validation

**PENDING — no handset available.** Static analysis and reproducible build
verification only. Validate on an `SM-S918U` running exact firmware
`S918USQU8GZIF` before treating this profile as device-tested.
