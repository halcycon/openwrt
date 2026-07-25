# AGENTS.md

> SPDX-License-Identifier: MIT
>
> This file (fork/agent documentation) is MIT-licensed.
> It does **not** relicense OpenWrt, the Linux kernel, or
> `kmod-octeon-flowtable` — see [Licensing](#licensing).

## Repository purpose

This repository is a GitHub-maintained OpenWrt tree for the Ubiquiti
UniFi Security Gateway Pro 4 (USG-PRO-4). It tracks Shiz's device work
on Codeberg and adds hardware flow offload via a port of the clean-room
`octeon-flowtable` driver.

### Upstream / credits

| Role | Repository |
|------|------------|
| OpenWrt device support (USG-PRO-4 / `ubnt-e200`) | [codeberg.org/Shiz/openwrt](https://codeberg.org/Shiz/openwrt) — branch `device/ubnt-e200` |
| Clean-room Octeon nftables flow offload (CN50xx, ERLite-3) | [github.com/packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable) |
| This GitHub mirror / USG-PRO-4 CN61xx port | [github.com/halcycon/openwrt](https://github.com/halcycon/openwrt) |

Git remotes should normally be arranged as:

- `origin`: `git@github.com:halcycon/openwrt.git`
- `upstream`: `https://codeberg.org/Shiz/openwrt.git`

The GitHub repository is not a native GitHub fork (source lives on
Codeberg). It retains the complete Git history and tracks Codeberg
through the `upstream` remote.

### Branches — do not merge into `main`

| Branch | Role |
|--------|------|
| `main` (local; tracks `upstream/main`) | Stock OpenWrt tip. **Not** the USG-PRO-4 integration line. |
| `upstream/device/ubnt-e200` (and `origin/device/ubnt-e200`) | Shiz’s USG / EdgeRouter CN61xx device baseline. Rebase/merge from here. |
| **`usg-pro-4/factory-macs`** (current work branch) | This mirror’s integration branch: device baseline **plus** factory MAC fix, octeon-flowtable, and docs. |

**Do not merge `usg-pro-4/factory-macs` into `main`.** That would replace the
OpenWrt-tracking tip with a device fork and make rebasing on upstream
painful. Keep USG work on a device/integration branch; keep `main` as
upstream OpenWrt (or omit publishing a GitHub `main` that pretends to be
the product branch).

If the default branch on GitHub should be “what you flash,” rename or
retarget the default to `usg-pro-4/factory-macs` (or a clearer name such
as `usg-pro-4`) — do not fold it into `main`.

#### Why `usg-pro-4/factory-macs` exists

Shiz’s `device/ubnt-e200` brings up the board, but first boot did not
reliably assign the **factory EEPROM MAC addresses** to the four
front-panel ports. Without that, interfaces get random/local MACs, which
breaks ISP DHCP bindings, license/portal MAC locks, and any expectation
that the unit matches the sticker / UniFi inventory.

This branch started as that fix and has since collected the rest of the
USG-PRO-4 delta for this mirror:

1. **Factory MACs** — `target/linux/octeon/base-files/etc/uci-defaults/99-usg-pro-4-macs`
   reads the base MAC from the EEPROM MTD region (or `/dev/mtd0` @
   `0x140000` on the development NOR layout), validates it, then writes
   named `network` device sections:

   | Port | Offset from base |
   |------|------------------|
   | `lan1` / `br-lan` | +0 |
   | `lan2` | +1 |
   | `wan1` / `br-wan` | +2 |
   | `wan2` | +3 |

2. **Hardware flow offload** — `kmod-octeon-flowtable` + staging hooks
   (see below).
3. **Docs / hygiene** — `AGENTS.md`, README fork notes, gitignore rules.

So the name is historical (“factory MAC topic branch”) but the tip is the
full integration line. Prefer building and PR’ing from this branch (or
rename it when convenient); sync device-only fixes back toward
`device/ubnt-e200` when contributing upstream to Shiz.

## Supported hardware

- Ubiquiti UniFi Security Gateway Pro 4 (marketing: USG-PRO-4)
- OpenWrt board name: `ubnt,usg-pro-4`
- Octeon system identification: `UBNT_E220`
- SoC: Cavium CN6120 (Octeon II / `cn61xx`)
- OpenWrt target: `octeon/generic`

Device configuration symbol:

```text
CONFIG_TARGET_octeon=y
CONFIG_TARGET_octeon_generic=y
CONFIG_TARGET_octeon_generic_DEVICE_ubnt_usg-pro-4=y
```

### Factory MAC addresses

On first boot, `99-usg-pro-4-macs` applies EEPROM-derived MACs (see
[Why `usg-pro-4/factory-macs` exists](#why-usg-pro-4factory-macs-exists)).
Verify on device:

```text
uci show network | grep macaddr
# or
ip link show lan1; ip link show wan1
```

If the script logs `Unable to read a valid factory MAC address`, the
EEPROM MTD layout does not match what the script expects — fix the
partition map or the offset before shipping images.

## Hardware flow offload (octeon-flowtable)

Images for this device include `kmod-octeon-flowtable`: a WQE-level RX
hook + in-buffer NAT/VLAN rewrite + PKO transmit path that claims
nftables hardware flow-offload rules. Misses fall through to normal
Linux forwarding.

Origin: [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable)
(ERLite-3 / CN5020). CN61xx shares the same cn38xx-style WQE layout and
PIP/POW/PKO/FPA/FAU model (PKND / CN68XX_WQE are CN68-only). Clean-room
reimplementation — no Ubiquiti binary, no Cavium SDK.

### Tree integration (already applied)

| Piece | Location |
|-------|----------|
| Staging driver hooks | `target/linux/octeon/patches-*/710-octeon-flowtable-hooks.patch` |
| Kernel module package | `package/kernel/octeon-flowtable/` |
| CVMSEG scratch | `CONFIG_CAVIUM_OCTEON_CVMSEG_SIZE=2` in `config-6.12` / `config-6.18` |
| POW group spreading | USG-PRO-4 cmdline includes `receive_group_order=1` |
| Device package | `kmod-octeon-flowtable` in `DEVICE_PACKAGES` for `ubnt_usg-pro-4` |

Device symbol is **`ubnt_usg-pro-4`** (not `ubnt_unifi-usg-pro-4`).
DTS labels rename netdevs (`lan1`/`lan2`/`wan1`/`wan2`) via
`700-allocate_interface_by_label.patch`; PIP/WQE port numbers still come
from the `pip` DT nodes (`&eth0`…`&eth3`).

### Enable on device

In `/etc/config/firewall` under `config defaults`:

```text
option flow_offloading '1'
option flow_offloading_hw '1'
```

Then `fw4 reload`. Module tunables: `/etc/config/octeon-flowtable`
(init script `/etc/init.d/octeon-flowtable`).

### Verify (basic)

```text
# staging hook present after kernel rebuild
grep cvm_oct_register_rx_hook /proc/kallsyms

# established forwarded flows claimed by HW offload
conntrack -L | grep HW_OFFLOAD

# prove fast-path engagement (delta under load; idle software path can also hit GbE)
cat /sys/module/octeon_flowtable/parameters/tx_ok
```

Useful debug params under `/sys/module/octeon_flowtable/parameters/`:
`flows`, `hits`, `tx_ok`, `tx_fail`, `r_*` reject counters, `aqm_*`,
`vlan_strict`, `verbose`.

### Guided check: WQE ↔ netdev port map (do this on hardware)

**Why:** The flow key assumes WQE ingress port (`cvmx_wqe_get_port`) equals
`priv->port` for the same netdev. On ERLite’s identical ports that is
trivial; on USG-PRO-4 (RJ45 `lan*` + SFP `wan*`, DTS labels via
`allocate_interface_by_label`) it is the one place a multi-interface
Octeon II can drift. Mismatch **fails closed** (safe): flows may install
as `HW_OFFLOAD` but every packet takes the slow path.

**When:** Once per interface class after first flash of an offload-enabled
image — copper (`lan1`/`lan2`) and SFP (`wan1`/`wan2`).

#### Prerequisites

1. Image includes `kmod-octeon-flowtable` and the staging hook
   (`grep cvm_oct_register_rx_hook /proc/kallsyms` shows a symbol).
2. In `/etc/config/firewall` → `config defaults`:
   `flow_offloading '1'` and `flow_offloading_hw '1'`, then `fw4 reload`.
3. Module loaded: `ls /sys/module/octeon_flowtable/parameters`.
4. A client behind the port under test that can open a **forwarded** TCP
   or UDP flow through the USG (LAN→WAN NAT is the usual case). Idle
   local traffic is not enough.

#### Procedure (repeat for copper, then SFP)

**A. Pick the path under test**

| Pass | Ingress class | Example path |
|------|---------------|--------------|
| 1 | RJ45 / copper | client on `lan1` (or `br-lan`) → internet via `wan1`/`br-wan` |
| 2 | SFP | same idea with traffic ingressing `wan1`/`wan2` if you route that way, or swap which side is “inside” so the SFP port is on the forwarded path |

If you only ever forward LAN→WAN with SFPs as WAN uplinks, pass 1 still
exercises copper ingress; for SFP ingress, temporarily put a test host
behind an SFP port (or generate traffic that ingresses that PIP port).

**B. Snapshot counters**

```text
P=/sys/module/octeon_flowtable/parameters
echo 1 > "$P/verbose"
cat "$P/tx_ok" "$P/r_miss" "$P/r_ipoff" "$P/flows" "$P/hits"
```

Write down those five numbers (or paste into a note).

**C. Generate a forwarded flow**

From the test client, start a bulk transfer that must be routed/NATed
(e.g. `iperf3`, a large HTTPS download, or `ping` is **not** enough —
need TCP/UDP that conntrack will offload). On the USG:

```text
conntrack -L | grep HW_OFFLOAD
```

You want at least one established flow showing `HW_OFFLOAD` (or the
offload flag your conntrack build prints).

**D. Re-read counters under load**

```text
P=/sys/module/octeon_flowtable/parameters
cat "$P/tx_ok" "$P/r_miss" "$P/r_ipoff" "$P/hits"
```

**E. Interpret**

| Result | `tx_ok` | `r_miss` / `r_ipoff` | Verdict |
|--------|---------|----------------------|---------|
| Pass | Increases vs snapshot | Flat (or negligible) | WQE port matches netdev — this class is OK |
| Fail (closed) | Flat | `r_miss` climbs while flows show `HW_OFFLOAD` | WQE port ≠ `priv->port` for that class — report with verbose logs |
| No install | Flat | Flat, and no `HW_OFFLOAD` in conntrack | Offload not claimed yet — fix firewall/fw4/module before retesting |

Optional while `verbose=1`: `logread -f` / `dmesg -w` for `octeon_flowtable:`
install lines (`+flow … iif=…`). Confirm `iif` looks like a real PIP
port index for the interface under test.

**F. Clean up**

```text
echo 0 > /sys/module/octeon_flowtable/parameters/verbose
```

Mark copper and SFP each pass/fail in your notes before calling the
port done. If either class fails, open an issue with the counter deltas
and which ifnames were on the path — do not “fix” by disabling the
check; the mapping in DT/driver needs correcting.

### Security / hardening notes

Upstream author review (packerlschupfer) confirmed the port is
byte-for-byte correct for CN61xx (same cn38xx-style WQE; GPL-2.0).
Remaining items:

1. **WQE ↔ netdev port identity** — live check above (must-do on hardware).
2. **Wildcard-VID fallback** (`vlan_strict=0`, default) — required for
   bridged-VLAN (lower-device) offload keys; allows a tagged frame to
   match an untagged-keyed flow on the same ingress port. Set
   `vlan_strict=1` on plain routing / 802.1Q-subinterface-only configs.
3. **FAU register map** — offsets 8/16 (global counters) and 24+
   (per-port AQM); confirm no collision with staging FAU use on CN6120.
4. **Only TCP/UDP** (plus GRE where presented); SYN/FIN/RST, fragments,
   L4_error, multi-buffer WQEs, TTL≤1, and MTU exceeds are punted.
5. **Unsupported actions refused** at install time (never silently ignored).
6. **Stale-entry eviction** + orphan GC after `fw4 reload`.

### CI / releases

Workflow: [`.github/workflows/build-usg-pro-4.yml`](.github/workflows/build-usg-pro-4.yml)
Seeds / feeds: [`ci/`](ci/).

| Trigger | Result |
|---------|--------|
| Actions → **build-usg-pro-4** → Run workflow | Artifacts (`lean` / `router`) |
| `git tag vX.Y.Z && git push origin vX.Y.Z` | Same build + GitHub Release with images + `.apk` tarballs |

Manual run options: `ubuntu-24.04` or `self-hosted` runner; variant
`both` / `lean` / `router`.

Gotchas:

1. No `python3-distutils` on Ubuntu 24.04 — seed uses `python3-setuptools`.
2. No bare `#` lines in `ci/feeds.conf`.
3. `workflow_dispatch` only appears for workflows on the **default**
   branch (`usg-pro-4/factory-macs`).

Adapted from [packerlschupfer/octeon-flowtable CI](https://github.com/packerlschupfer/octeon-flowtable/tree/main/ci).

## What must not be committed / uploaded to GitHub

Build outputs and local state are gitignored. Never force-add:

| Path / pattern | Why |
|----------------|-----|
| `/bin`, `/build_dir`, `/staging_dir`, `/tmp`, `/logs`, `/dl` | Toolchain, images, packages, downloads |
| `/.config`, `/.config.*` | Local menuconfig (may contain paths/secrets layout) |
| `key-build*`, `*.pem` | Signing keys |
| `*.ko`, `*.ipk`, `*.apk` (built) | Binary packages / modules |
| Nested `package/*/.git` clones | Accidental gitlinks (e.g. themes) |
| `*-session.txt`, large local dumps | Scratch / secrets risk |

Source that *does* belong: kernel patches under `target/linux/octeon/patches-*`,
`package/kernel/octeon-flowtable/` source + init/UCI, docs.

If a third-party LuCI theme or feed package is needed, pull it via feeds
or document it — do not commit a bare git submodule/gitlink unless that
is an intentional, reviewed dependency.

## Licensing

Layered licenses — do not collapse them into a single “MIT repo”:

| Component | License | Notes |
|-----------|---------|-------|
| OpenWrt tree (this codebase as OpenWrt) | **GPL-2.0-only** | See root `COPYING` and `LICENSES/GPL-2.0`. All contributions to OpenWrt code remain under that license. |
| Linux kernel + staging patches | **GPL-2.0** | Kernel project norms. |
| `package/kernel/octeon-flowtable` | **GPL-2.0** | Kernel module; follows [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable) (`LICENSE` there). See package `NOTICE`. |
| This file (`AGENTS.md`) and the USG-PRO-4 fork notes in `README.md` | **MIT** | Original documentation for this mirror only. |

MIT here is for **original documentation** authored for this GitHub
mirror. It cannot and does not relicense OpenWrt or the flowtable
driver. When in doubt, the more restrictive (GPL) license of the
touched component applies.

## Agent / contributor workflow

1. Work on `usg-pro-4/factory-macs` (or a topic branch cut from it).
   Rebase onto `upstream/device/ubnt-e200` when Shiz moves. Do not merge
   this line into `main`.
2. Keep octeon-flowtable changes reviewable: module source, staging
   patch, image/cmdline/config, and docs.
3. Do not vendor build artifacts or unrelated nested git repos.
4. After kernel changes that touch staging octeon ethernet, rebuild and
   confirm `cvm_oct_*` symbols in `/proc/kallsyms` before claiming
   offload works.
