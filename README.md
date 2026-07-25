# OpenWrt for USG-PRO-4

**Start here → [`docs/USG-PRO-4.md`](docs/USG-PRO-4.md)**

This repository is a GitHub-maintained [OpenWrt](https://openwrt.org/) tree
for the **Ubiquiti UniFi Security Gateway Pro 4**
(`ubnt,usg-pro-4` / `UBNT_E220` / Cavium CN6120). It is **not** an official
OpenWrt release and not a generic multi-target build.

> SPDX-License-Identifier: MIT *(this README and `docs/USG-PRO-4.md` only —
> OpenWrt sources remain GPL-2.0-only; see [License](#license))*

## What we add

| Piece | Purpose |
|-------|---------|
| Factory EEPROM MACs | Correct `lan1`…`wan2` addresses on first boot |
| `kmod-octeon-flowtable` | Clean-room nftables **hardware** flow offload |
| CI Releases + Pages apk feeds | Flashable **lean** / **router** images and matching packages |
| Proton2025 LuCI theme | Submodule for the router image |

Full detail (versioning `v25.12-usg.N`, testing, signing, apk install):
**[`docs/USG-PRO-4.md`](docs/USG-PRO-4.md)**.

Agent / branch notes: [`AGENTS.md`](AGENTS.md).

## Quick start

1. Download a Release for your tag (e.g.
   [v25.12-usg.2](https://github.com/halcycon/openwrt/releases/tag/v25.12-usg.2))
   — **lean** (minimal) or **router** (LuCI + VPN + gateway apps).
2. Flash the `*-ubnt_usg-pro-4-squashfs-sysupgrade.tar` image.
3. Enable `flow_offloading` + `flow_offloading_hw` in firewall defaults;
   `fw4 reload`.
4. Run the
   [WQE↔netdev port-map check](docs/USG-PRO-4.md#2-guided-check--wqe--netdev-port-map-required-once)
   once on RJ45 and once on SFP.
5. Optional packages:
   [GitHub Pages apk feed](https://halcycon.github.io/openwrt/).

**Branch to use:** `usg-pro-4/factory-macs` (default). Do not merge into
stock OpenWrt `main`.

## Credits

- Device support — [Shiz/openwrt](https://codeberg.org/Shiz/openwrt)
  (`device/ubnt-e200`)
- Hardware flow offload —
  [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable)
- LuCI theme —
  [ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025)
  (Apache-2.0)

## Upstream OpenWrt

The tree retains full OpenWrt history and tracks Codeberg via `upstream`.
The classic project README (About, download, build requirements, support)
is preserved here: **[`docs/OPENWRT-README.md`](docs/OPENWRT-README.md)**.
Live upstream copy:
[openwrt/openwrt README](https://github.com/openwrt/openwrt/blob/main/README.md).

Sunshine!

## License

**OpenWrt** in this tree remains **GPL-2.0-only** — see [`COPYING`](COPYING)
and [`LICENSES/GPL-2.0`](LICENSES/GPL-2.0).

**`kmod-octeon-flowtable`** is **GPL-2.0** (kernel module), following
[packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable).

**Original documentation** for this mirror (`README.md`,
[`docs/USG-PRO-4.md`](docs/USG-PRO-4.md), [`AGENTS.md`](AGENTS.md)) is
**MIT** ([`LICENSES/MIT`](LICENSES/MIT)). MIT does not relicense OpenWrt
or the flowtable driver.
