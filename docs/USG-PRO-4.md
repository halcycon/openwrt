# USG-PRO-4 OpenWrt fork — changes, versioning, testing, packages

> SPDX-License-Identifier: MIT
>
> Original documentation for this GitHub mirror. Does **not** relicense
> OpenWrt (GPL-2.0-only) or `kmod-octeon-flowtable` (GPL-2.0).

This document is the human-facing guide for the USG-PRO-4 work in
[halcycon/openwrt](https://github.com/halcycon/openwrt). Agent/repo
orientation lives in [`AGENTS.md`](../AGENTS.md).

## What this fork adds (delta)

Baseline device support comes from
[Shiz/openwrt](https://codeberg.org/Shiz/openwrt) (`device/ubnt-e200`).
On top of that, this mirror adds:

| Change | Where | Why |
|--------|-------|-----|
| Factory EEPROM MACs on first boot | `target/linux/octeon/base-files/etc/uci-defaults/99-usg-pro-4-macs` | Ports get sticker/UniFi MACs (`lan1`+0 … `wan2`+3), not random |
| Hardware flow offload | `package/kernel/octeon-flowtable/`, staging patch `710-octeon-flowtable-hooks.patch` | Clean-room nftables offload (port of [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable)) |
| Offload tuning | `CVMSEG_SIZE=2`, cmdline `receive_group_order=1`, `kmod-octeon-flowtable` in `DEVICE_PACKAGES` | Match upstream offload requirements |
| CI images | `.github/workflows/build-usg-pro-4.yml`, `ci/*.seed` | Build lean/router firmware + matching `.apk`s |

Board: `ubnt,usg-pro-4` / `UBNT_E220` / CN6120. Config symbol:
`CONFIG_TARGET_octeon_generic_DEVICE_ubnt_usg-pro-4=y` (not
`ubnt_unifi-usg-pro-4`).

Integration branch: **`usg-pro-4/factory-macs`** (do not merge into stock
OpenWrt `main` — see AGENTS.md).

## Versioning

**Do not** reuse bare OpenWrt tags like `v25.12.0` — that implies an
official OpenWrt release. **Do** keep the OpenWrt release *line* visible
so users know the kernel/userspace era.

### Tag format

```text
v<openwrt-line>-usg.<N>
```

Examples:

| Tag | Meaning |
|-----|---------|
| `v25.12-usg.1` | First public USG build based on the OpenWrt **25.12** line |
| `v25.12-usg.2` | Second iteration on the same line (docs, MAC fix, offload tweak, …) |
| `v26.xx-usg.1` | First build after rebasing onto a newer OpenWrt line |

Rules:

1. **`<openwrt-line>`** — major.minor of the OpenWrt tree you built from
   (e.g. `25.12`), not necessarily a specific point release number.
2. **`usg.<N>`** — monotonic fork revision for that line; bump on every
   published Release.
3. When you rebase onto a new OpenWrt line, reset `usg.N` to `1` and note
   the base commit/Shiz tip in the Release notes.
4. Git tags must match `v*` so
   [build-usg-pro-4.yml](../.github/workflows/build-usg-pro-4.yml)
   publishes a Release.

Optional Release-notes footer:

```text
OpenWrt base: <git describe / commit>
Shiz device tip: <upstream/device/ubnt-e200 commit>
octeon-flowtable: in-tree port of packerlschupfer/octeon-flowtable
```

### What not to do

- Don’t tag `v25.12.0` alone (collides mentally with openwrt.org).
- Don’t bump `usg.N` without rebuilding images (kmod hashes must match).
- Don’t ship kmods from `v25.12-usg.2` onto a box still running
  `v25.12-usg.1` firmware.

## Image variants (lean / router)

| | **lean** | **router** |
|--|----------|------------|
| Seed | `ci/config.seed` | `ci/config-router.seed` |
| Offload | yes | yes |
| Extra | conntrack, tcpdump | + LuCI HTTPS + WireGuard |
| Use | minimal / DIY | turnkey gateway |

Same device profile. Neither is “build all packages.”

## How to test

### 1. Basic bring-up

```text
grep cvm_oct_register_rx_hook /proc/kallsyms   # staging hook present
uci show network | grep macaddr                # factory MACs applied
```

Enable offload in `/etc/config/firewall` → `config defaults`:

```text
option flow_offloading '1'
option flow_offloading_hw '1'
```

Then `fw4 reload`. Confirm:

```text
conntrack -L | grep HW_OFFLOAD
cat /sys/module/octeon_flowtable/parameters/tx_ok
```

### 2. Guided check — WQE ↔ netdev port map (required once)

**Why:** Flow keys assume WQE ingress port == netdev `priv->port`. On
USG-PRO-4 (RJ45 + SFP, DTS labels) that mapping can drift. Mismatch
**fails closed**: flows may show `HW_OFFLOAD` but every packet misses
the fast path.

**When:** Once per interface class after first flash — copper (`lan*`)
and SFP (`wan*`).

**Prerequisites:** hook present, offload enabled, module loaded, a client
that can open a **forwarded** TCP/UDP flow (not just LAN-local ping).

#### A. Path under test

| Pass | Class | Example |
|------|-------|---------|
| 1 | RJ45 | client on `br-lan` / `lan1` → WAN |
| 2 | SFP | traffic ingressing `wan1`/`wan2` (or a host behind an SFP port) |

#### B. Snapshot

```text
P=/sys/module/octeon_flowtable/parameters
echo 1 > "$P/verbose"
cat "$P/tx_ok" "$P/r_miss" "$P/r_ipoff" "$P/flows" "$P/hits"
```

#### C. Load

Start iperf3 / a large download through the USG. Check:

```text
conntrack -L | grep HW_OFFLOAD
```

#### D. Re-read and interpret

```text
cat "$P/tx_ok" "$P/r_miss" "$P/r_ipoff" "$P/hits"
```

| Result | `tx_ok` | `r_miss` / `r_ipoff` | Meaning |
|--------|---------|----------------------|---------|
| Pass | Rising | Flat | Port map OK |
| Fail closed | Flat | `r_miss` rising with `HW_OFFLOAD` flows | WQE ≠ `priv->port` — file an issue |
| No install | Flat | Flat, no `HW_OFFLOAD` | Fix fw4/module first |

```text
echo 0 > /sys/module/octeon_flowtable/parameters/verbose
```

### 3. Security / hardening checklist

1. WQE↔netdev check above (must-do).
2. `vlan_strict=1` on plain routing (no bridged-VLAN offload).
3. FAU offsets 8/16/24+ vs staging driver on CN6120.
4. SYN/FIN/RST and unsupported actions stay on slow path.

## Releases and packages

CI: [build-usg-pro-4.yml](../.github/workflows/build-usg-pro-4.yml).

| Trigger | Output |
|---------|--------|
| Actions → Run workflow | Artifacts |
| `git tag v25.12-usg.1 && git push origin v25.12-usg.1` | GitHub Release |

### Release asset map

For tag `v25.12-usg.1`, assets are prefixed `lean-` or `router-`:

| Pattern | Contents |
|---------|----------|
| `*-ubnt_usg-pro-4-squashfs-sysupgrade.tar` | Flashable image |
| `*-ubnt_usg-pro-4-initramfs-kernel.bin` | Initramfs kernel |
| `*-kmod-octeon-flowtable-*.apk` | Offload kmod |
| `*-target-packages.tar.gz` | Target packages + `packages.adb` |
| `*-packages.tar.gz` | Feed packages (`base` / `luci` / …) |
| `sha256sums-*.txt` | Checksums |

Only install packages from the **same tag and same variant** as the
running firmware.

### Install on a live USG (`apk`)

This tree uses **apk**, not opkg.

**A — Flash image (preferred)**

```text
sysupgrade -n /tmp/lean-openwrt-octeon-generic-ubnt_usg-pro-4-squashfs-sysupgrade.tar
```

**B — Sideload one `.apk` from the Release** (same tag/variant only)

```text
apk add --allow-untrusted ./kmod-octeon-flowtable-*.apk
```

**C — Local feed from tarball**

```text
tar -xzf lean-target-packages.tar.gz
tar -xzf lean-packages.tar.gz
# add file:///…/packages.adb lines to /etc/apk/repositories.d/customfeeds.list
apk update
apk add --allow-untrusted <pkg>
```

**D — HTTP feed (GitHub Pages or R2)** — see next section.

## Publishing `.apk`s on GitHub Pages

**Yes — you can.** Pages can serve the unpacked feed trees so devices
run `apk update` over HTTPS. It is a good fit for a **small community
feed**; watch the soft limits.

### Limits (soft, public Pages)

| Limit | Value |
|-------|--------|
| Published site size | ~1 GB recommended |
| Bandwidth | ~100 GB / month |
| Deploy via Actions | Preferred (10 builds/hour Jekyll limit does not apply) |

A full `lean` + `router` package set for several tags will blow past 1 GB
quickly. Practical policy:

- Publish **one “current”** tag under `/current/{lean,router}/…`, **or**
- Keep only the latest `usg.N` per OpenWrt line and delete older trees, **or**
- Publish **target packages + kmods only** on Pages; leave large optional
  feeds on Release tarballs / R2.

Firmware images (sysupgrade `.tar`) are better left on **GitHub Releases**
(not Pages) — Releases are meant for binaries; Pages for the apk index.

### Suggested URL layout

```text
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/targets/packages.adb
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/base/packages.adb
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/packages/packages.adb
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/luci/packages.adb
```

(Project site: enable Pages from the `gh-pages` branch or Actions artifact.)

### Device config

```text
cat > /etc/apk/repositories.d/customfeeds.list <<'EOF'
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/targets/packages.adb
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/base/packages.adb
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/packages/packages.adb
https://halcycon.github.io/openwrt/apk/v25.12-usg.1/lean/luci/packages.adb
EOF

apk update
apk add --allow-untrusted kmod-octeon-flowtable   # until you ship a signing key
```

Pin the path to the firmware tag you flashed. Mixing tags or lean/router
breaks kmods.

### How publishing works (wired)

1. Tag `v25.12-usg.N` → **build-usg-pro-4** builds images, creates a
   GitHub Release, then the **pages** job unpacks package tarballs via
   [`ci/publish-apk-pages.sh`](../ci/publish-apk-pages.sh) and deploys
   with `actions/deploy-pages`.
2. Site URL: https://halcycon.github.io/openwrt/  
   Feeds: `apk/<tag>/{lean,router}/…` and `apk/current/…` (latest deploy).
3. Redeploy without rebuilding: Actions → **deploy-apk-pages** → enter
   an existing Release tag.

Each deploy **replaces** the Pages site (versioned tree for that tag +
`current/`) so the soft ~1 GB limit stays manageable. Older tags’ feeds
remain downloadable as Release tarballs (methods A–C).

Optional later: ship a signing key under `/etc/apk/keys/` and drop
`--allow-untrusted`.

### Pages vs R2

| | GitHub Pages | Cloudflare R2 |
|--|--------------|---------------|
| Setup | Native to this repo | Extra account / wrangler |
| Size comfort | ~1 GB soft | Larger free tier |
| Best for | Latest tag feed + docs | Multi-version full feeds |
| Images | Prefer Releases | Either |

**Recommendation:** Releases for firmware + full tarballs; Pages for the
**latest** apk index (or R2 if the feed grows).

## Credits

- Device tree / board work: [Shiz/openwrt](https://codeberg.org/Shiz/openwrt)
- Flow offload: [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable)
- CI patterns adapted from that project’s `build-image.yml` / `ci/`
