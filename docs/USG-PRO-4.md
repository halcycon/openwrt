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
| Extra | conntrack, tcpdump | LuCI (HTTPS) + WireGuard + Tailscale + Proton2025 theme + mwan3/pbr/adblock-fast/https-dns-proxy + htop/nano/curl/iperf3 |
| Use | minimal / DIY | turnkey gateway (matches maintainer `.config` extras) |

Same device profile. Neither is `CONFIG_ALL` (that would pull every feed
package).

### What `v25.12-usg.1` actually shipped

Measured from the Release tarballs:

- **lean:** ~65 feed `.apk`s — base system + conntrack/tcpdump toolkit
  (no LuCI).
- **router (that tag):** ~99 feed `.apk`s — lean set **plus** the LuCI
  stack (bootstrap theme), WireGuard userspace, and their dependencies.
  **Not** yet Proton2025 / mwan3 / adblock / etc. (those land in the
  next tag after the expanded `ci/config-router.seed`).

Router is “LuCI + WireGuard (+ deps)”, not a mysterious second OS.

### Recommended extras (now in router seed)

From the maintainer `.config`, worth shipping in **router**:

| Package | Why |
|---------|-----|
| `luci-theme-proton2025` | Default polished LuCI theme ([ChesterGoodiny](https://github.com/ChesterGoodiny/luci-theme-proton2025), Apache-2.0) |
| `mwan3` + `luci-app-mwan3` | Multi-WAN on a 4-port USG |
| `pbr` + `luci-app-pbr` | Policy routing |
| `adblock-fast` + LuCI app | DNS adblocking |
| `https-dns-proxy` + LuCI app | DNS-over-HTTPS |
| `tailscale` | Easy mesh/VPN overlay |
| `htop`, `nano`, `curl`, `iperf3` | Ops / diagnostics |

Still optional / not in seed (add if you need them): SQM/QoS, OpenVPN,
collectd/prometheus, USB gadget extras beyond device defaults, full
`avahi` stack.

### LuCI theme: Proton2025

In-tree as a **git submodule**:

- Path: `package/luci-theme-proton2025`
- Upstream: https://github.com/ChesterGoodiny/luci-theme-proton2025
- Author / copyright: **ChesterGoodiny** (Apache-2.0; see theme `LICENSE` / `NOTICE`)
- Selected in the **router** seed (`CONFIG_PACKAGE_luci-theme-proton2025`)

```bash
git submodule update --init --recursive
```

CI checks out submodules automatically.

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
| Pass | Rising under load | `r_ipoff` flat; `r_miss` may still tick (non-offloaded traffic) | Port map OK for this path |
| Fail closed | Flat | `r_miss` rising while flows claim offload | WQE ≠ `priv->port` — file an issue |
| No install | Flat | Flat, and no fast-path hits | Fix fw4/module first |

`tx_ok` delta under forwarded load is the definitive fast-path proof
(software forwarding can also hit line rate when idle). `conntrack` may
not always print `HW_OFFLOAD` depending on timing/flags — don’t fail the
check on that alone if `tx_ok` climbed.

```text
echo 0 > /sys/module/octeon_flowtable/parameters/verbose
```

#### Hardware validation log

| Date | Unit | Path | `tx_ok` Δ | `r_miss` | `r_ipoff` | `tx_fail` / `aqm_drops` | Result |
|------|------|------|-----------|----------|-----------|-------------------------|--------|
| 2026-07-25 | GW1 | forwarded load (iperf3); confirm RJ45 vs SFP class | +180 874 (470 079 456 → 470 260 330) | rose (background OK) | 0 | 0 / 0 | **Pass** (fast path engaged) |

Repeat for the other interface class (RJ45 vs SFP) if only one was tested.

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

### Package / index signing (no `--allow-untrusted`)

OpenWrt signs `.apk` files and `packages.adb` with ECDSA P-256 when
`CONFIG_SIGN_EACH_PACKAGE=y` and `CONFIG_SIGNED_PACKAGES=y` (enabled in
our seeds).

| Piece | Location |
|-------|----------|
| Public key (git) | [`ci/keys/usg-apk-public.pem`](../ci/keys/usg-apk-public.pem) |
| Private key | GitHub Actions secret `USG_APK_PRIVATE_KEY` (never committed) |
| In firmware | `/etc/apk/keys/` (via `base-files` from `public-key.pem`) |
| On Pages | https://halcycon.github.io/openwrt/keys/usg-apk.pem |

CI writes the secret to `private-key.pem` and the committed public key to
`public-key.pem` before `make`. Rotation notes:
[`ci/keys/README.md`](../ci/keys/README.md).

On a **CI-built** image with matching feeds: plain `apk update` / `apk add`.
On a foreign image: install the public key into `/etc/apk/keys/` first.

### Install on a live USG (`apk`)

This tree uses **apk**, not opkg.

**A — Flash image (preferred)**

```text
sysupgrade -n /tmp/lean-openwrt-octeon-generic-ubnt_usg-pro-4-squashfs-sysupgrade.tar
```

**B — Sideload one `.apk` from the Release** (same tag/variant only)

```text
apk add ./kmod-octeon-flowtable-*.apk
# --allow-untrusted only if the running image lacks ci/keys public key
```

**C — Local feed from tarball**

```text
tar -xzf lean-target-packages.tar.gz
tar -xzf lean-packages.tar.gz
# add file:///…/packages.adb lines to /etc/apk/repositories.d/customfeeds.list
apk update
apk add <pkg>
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

# if this image was not built by our CI, install the public key first:
# wget -O /etc/apk/keys/usg-apk.pem https://halcycon.github.io/openwrt/keys/usg-apk.pem

apk update
apk add kmod-octeon-flowtable
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

The `github-pages` environment must allow **tag** deploys matching `v*`
(plus the integration branch). If Pages fails with “not allowed to deploy
… protection rules,” add a deployment-branch policy of type **tag** /
name `v*` under Settings → Environments → github-pages.

Each deploy **replaces** the Pages site (versioned tree for that tag +
`current/` + `keys/usg-apk.pem`) so the soft ~1 GB limit stays
manageable. Older tags’ feeds remain downloadable as Release tarballs
(methods A–C). Signing uses `USG_APK_PRIVATE_KEY` +
`ci/keys/usg-apk-public.pem`.

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
- LuCI theme Proton2025: [ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025) (Apache-2.0)
- CI patterns adapted from packerlschupfer’s `build-image.yml` / `ci/`
