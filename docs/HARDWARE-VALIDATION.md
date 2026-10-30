# Hardware validation with diagnostic runs

The offline ports carry a small number of constants that are normally
measured on a running device. This app build exposes a **diagnostic run**
that measures them on real hardware **without installing root**.

## How to run a diagnostic

1. Install the diagnostic APK (advanced mode required).
2. Settings → Advanced → **Diagnostic run** → ON.
3. Start the install for your profile as usual.
4. The exploit runs the P0 oracle gate, prints the measured values to the
   log, and **aborts cleanly** — nothing is installed, nothing persists.
   (The app will report the run as failed at the final marker; that is the
   diagnostic behaving as designed.)
5. Copy the full log from the app (or from
   `/data/local/tmp/ksu-exploit.log` when using Shizuku).

## What the log lines mean

| Log line | What it measures | Which carried constant it validates |
| --- | --- | --- |
| `slide tracefs ... candidate=...` / `slide-kaslr-ok source=... slide=...` | the runtime KASLR slide of this boot | nothing carried — proves the leak stage works |
| `p0 fingerprint source_offset=... runtime_slide=...` | which fingerprint row matched the physical memory | the P0 fingerprint table and `P0_KERNEL_PHYS_LOAD` (if no row matches, the carried physical load constant is wrong) |
| `p0 physical elapsed_ms=...` | full oracle pass success | everything above, end to end |
| `slide pi stage=...` lines | the PI-chain reclaim geometry | the task_struct/waiter layout constants |

## Decision table

| Diagnostic result | Meaning | Action |
| --- | --- | --- |
| fingerprint row matched, run continues past P0 | carried constants are correct | re-run without diagnostic mode to actually root |
| no fingerprint row matched, gate clean | carried `P0_KERNEL_PHYS_LOAD` wrong for this build | report the log; the constant gets re-derived |
| panic / reboot during the diagnostic | write-path geometry wrong | report the exact stage line; do not retry |

Send the captured log to the feed maintainer (or open an issue) and the
profile gets tuned or confirmed from real hardware.
