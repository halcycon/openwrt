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
CONFIG_TARGET_octeon_generic_DEVICE_ubnt_unifi-usg-pro-4=y
```

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
| Device package | `kmod-octeon-flowtable` in `DEVICE_PACKAGES` for `ubnt_unifi-usg-pro-4` |

### Enable on device

In `/etc/config/firewall` under `config defaults`:

```text
option flow_offloading '1'
option flow_offloading_hw '1'
```

Then `fw4 reload`. Module tunables: `/etc/config/octeon-flowtable`
(init script `/etc/init.d/octeon-flowtable`).

### Verify

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

### Security / hardening notes (for review)

The original `octeon-flowtable` author is reviewing this port for
hardening. Known intentional trade-offs and review targets:

1. **Wildcard-VID fallback** (`vlan_strict=0`, default) — required for
   bridged-VLAN (lower-device) offload keys; allows a tagged frame to
   match an untagged-keyed flow on the same ingress port. Set
   `vlan_strict=1` on plain routing / 802.1Q-subinterface-only configs.
2. **FAU register map** — module uses FAU offsets 8/16 (global counters)
   and 24+ (per-port AQM). Confirm no collision with the staging driver's
   FAU allocation on CN6120 boards.
3. **Only TCP/UDP** (plus GRE at the flowtable layer where presented);
   SYN/FIN/RST, fragments, L4_error, multi-buffer WQEs, TTL≤1, and MTU
   exceeds are punted to the slow path.
4. **Unsupported actions are refused** at install time (never silently
   ignored) so the fast path cannot forward misbuilt packets.
5. **Stale-entry eviction** + orphan GC after `fw4 reload` — watch for
   races with DESTROY/STATS on multi-core softirq.

Do not treat this document as a security audit; it is a checklist for
the upcoming review.

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

1. Prefer `upstream/device/ubnt-e200` (or the active `device/ubnt-e200-*`
   branch) as the device baseline; keep `origin` for this mirror's work.
2. Keep octeon-flowtable changes reviewable: module source, staging
   patch, image/cmdline/config, and docs.
3. Do not vendor build artifacts or unrelated nested git repos.
4. After kernel changes that touch staging octeon ethernet, rebuild and
   confirm `cvm_oct_*` symbols in `/proc/kallsyms` before claiming
   offload works.
