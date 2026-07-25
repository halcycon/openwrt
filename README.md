![OpenWrt logo](include/logo.png)

## USG-PRO-4 fork (this mirror)

> SPDX-License-Identifier: MIT *(this section only — see [License](#license))*

This GitHub tree is maintained for the **Ubiquiti UniFi Security Gateway
Pro 4** (`ubnt,usg-pro-4` / `UBNT_E220`, Cavium CN6120). It is **not** a
drop-in replacement for official OpenWrt releases.

### Credits

- **Device support** — [Shiz/openwrt](https://codeberg.org/Shiz/openwrt)
  on Codeberg (`device/ubnt-e200` and related branches). This mirror tracks
  that work via the `upstream` remote.
- **Hardware flow offload** — port of
  [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable),
  a clean-room nftables flow-offload backend originally for Octeon+ CN50xx
  (EdgeRouter Lite 3). Adapted here for CN61xx on the USG-PRO-4.
- **LuCI theme** — [ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025)
  (Apache-2.0), vendored as `package/luci-theme-proton2025` submodule;
  selected in the **router** CI image.

**Docs:** [`docs/USG-PRO-4.md`](docs/USG-PRO-4.md) (changes, versioning,
testing, packages, GitHub Pages). Agent notes: [`AGENTS.md`](AGENTS.md).

**Branch:** `usg-pro-4/factory-macs` — do **not** merge into `main`
(`main` tracks stock OpenWrt).

### Quick start

1. Flash a **lean** or **router** image from a Release (tags look like
   `v25.12-usg.1` — see [versioning](docs/USG-PRO-4.md#versioning)).
2. Set `flow_offloading` + `flow_offloading_hw` in firewall defaults;
   `fw4 reload`.
3. Run the [WQE↔netdev port-map check](docs/USG-PRO-4.md#2-guided-check--wqe--netdev-port-map-required-once)
   once on RJ45 and once on SFP.
4. Optional: point `apk` at Release tarballs or a
   [GitHub Pages feed](docs/USG-PRO-4.md#publishing-apks-on-github-pages).

CI: **build-usg-pro-4** (`ci/*.seed`) · [`ci/README.md`](ci/README.md).

### What this repository does *not* ship

Do not expect (and do not commit) build products: `bin/`, `build_dir/`,
`staging_dir/`, `dl/`, local `.config*`, signing keys, or prebuilt
`.ipk`/`.apk`/`.ko` artifacts. Those paths are gitignored.

---

OpenWrt Project is a Linux operating system targeting embedded devices. Instead
of trying to create a single, static firmware, OpenWrt provides a fully
writable filesystem with package management. This frees you from the
application selection and configuration provided by the vendor and allows you
to customize the device through the use of packages to suit any application.
For developers, OpenWrt is the framework to build an application without having
to build a complete firmware around it; for users this means the ability for
full customization, to use the device in ways never envisioned.

Sunshine!

## Download

Built firmware images are available for many architectures and come with a
package selection to be used as WiFi home router. To quickly find a factory
image usable to migrate from a vendor stock firmware to OpenWrt, try the
*Firmware Selector*.

* [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/)

If your device is supported, please follow the **Info** link to see install
instructions or consult the support resources listed below.

## 

An advanced user may require additional or specific package. (Toolchain, SDK, ...) For everything else than simple firmware download, try the wiki download page:

* [OpenWrt Wiki Download](https://openwrt.org/downloads)

## Development

To build your own firmware you need a GNU/Linux, BSD or macOS system (case
sensitive filesystem required). Cygwin is unsupported because of the lack of a
case sensitive file system.

### Requirements

You need the following tools to compile OpenWrt, the package names vary between
distributions. A complete list with distribution specific packages is found in
the [Build System Setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem)
documentation.

```
binutils bzip2 diff find flex gawk gcc-6+ getopt grep install libc-dev libz-dev
make4.1+ perl python3.7+ rsync subversion unzip which
```

### Quickstart

1. Run `./scripts/feeds update -a` to obtain all the latest package definitions
   defined in feeds.conf / feeds.conf.default

2. Run `./scripts/feeds install -a` to install symlinks for all obtained
   packages into package/feeds/

3. Run `make menuconfig` to select your preferred configuration for the
   toolchain, target system & firmware packages.

4. Run `make` to build your firmware. This will download all sources, build the
   cross-compile toolchain and then cross-compile the GNU/Linux kernel & all chosen
   applications for your target system.

### Related Repositories

The main repository uses multiple sub-repositories to manage packages of
different categories. All packages are installed via the OpenWrt package
manager called `opkg`. If you're looking to develop the web interface or port
packages to OpenWrt, please find the fitting repository below.

* [LuCI Web Interface](https://github.com/openwrt/luci): Modern and modular
  interface to control the device via a web browser.

* [OpenWrt Packages](https://github.com/openwrt/packages): Community repository
  of ported packages.

* [OpenWrt Routing](https://github.com/openwrt/routing): Packages specifically
  focused on (mesh) routing.

* [OpenWrt Video](https://github.com/openwrt/video): Packages specifically
  focused on display servers and clients (Xorg and Wayland).

## Support Information

For a list of supported devices see the [OpenWrt Hardware Database](https://openwrt.org/supported_devices)

### Documentation

* [Quick Start Guide](https://openwrt.org/docs/guide-quick-start/start)
* [User Guide](https://openwrt.org/docs/guide-user/start)
* [Developer Documentation](https://openwrt.org/docs/guide-developer/start)
* [Technical Reference](https://openwrt.org/docs/techref/start)

### Support Community

* [Forum](https://forum.openwrt.org): For usage, projects, discussions and hardware advise.
* [Support Chat](https://webchat.oftc.net/#openwrt): Channel `#openwrt` on **oftc.net**.

### Developer Community

* [Bug Reports](https://bugs.openwrt.org): Report bugs in OpenWrt
* [Dev Mailing List](https://lists.openwrt.org/mailman/listinfo/openwrt-devel): Send patches
* [Dev Chat](https://webchat.oftc.net/#openwrt-devel): Channel `#openwrt-devel` on **oftc.net**.

## License

**OpenWrt** in this tree remains **GPL-2.0-only** — see [`COPYING`](COPYING)
and [`LICENSES/GPL-2.0`](LICENSES/GPL-2.0). Contributions to OpenWrt code
are subject to that license; this mirror does not relicense the OpenWrt
Project or the Linux kernel.

**`kmod-octeon-flowtable`** is **GPL-2.0** (Linux kernel module), following
[packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable).
See [`package/kernel/octeon-flowtable/NOTICE`](package/kernel/octeon-flowtable/NOTICE).

**Original documentation** unique to this mirror — the USG-PRO-4 section
above and [`AGENTS.md`](AGENTS.md) — is available under the **MIT** License
([`LICENSES/MIT`](LICENSES/MIT)). MIT applies only to that documentation,
not to OpenWrt sources or the flowtable driver.
