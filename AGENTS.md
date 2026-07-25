# AGENTS.md

> SPDX-License-Identifier: MIT
>
> This file (fork/agent documentation) is MIT-licensed.
> It does **not** relicense OpenWrt, the Linux kernel, or
> `kmod-octeon-flowtable` — see [Licensing](#licensing).

Human-facing guide (changes, versioning, testing, packages, GitHub Pages):

→ **[`docs/USG-PRO-4.md`](docs/USG-PRO-4.md)**

## Repository purpose

GitHub-maintained OpenWrt tree for the Ubiquiti UniFi Security Gateway
Pro 4 (USG-PRO-4). Tracks Shiz’s device work on Codeberg and adds
hardware flow offload via a port of the clean-room `octeon-flowtable`
driver.

| Role | Repository |
|------|------------|
| OpenWrt device support (`ubnt-e200`) | [codeberg.org/Shiz/openwrt](https://codeberg.org/Shiz/openwrt) — branch `device/ubnt-e200` |
| Clean-room Octeon flow offload (CN50xx) | [github.com/packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable) |
| LuCI theme Proton2025 (submodule) | [ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025) |
| This mirror / CN61xx port | [github.com/halcycon/openwrt](https://github.com/halcycon/openwrt) |

Remotes:

- `origin`: `git@github.com:halcycon/openwrt.git`
- `upstream`: `https://codeberg.org/Shiz/openwrt.git`

### Branches — do not merge into `main`

| Branch | Role |
|--------|------|
| `main` (tracks `upstream/main`) | Stock OpenWrt tip — **not** the USG line |
| `upstream/device/ubnt-e200` / `origin/device/ubnt-e200` | Shiz device baseline |
| **`usg-pro-4/factory-macs`** | Integration tip (MACs + offload + docs + CI) |

**Do not merge `usg-pro-4/factory-macs` into `main`.** Default branch on
GitHub is already this integration branch. Details:
[docs/USG-PRO-4.md](docs/USG-PRO-4.md).

Why the branch name: started as factory EEPROM MAC assignment
(`99-usg-pro-4-macs`); now holds the full USG delta.

## Supported hardware (quick ref)

- Board: `ubnt,usg-pro-4` / `UBNT_E220` / CN6120 / `octeon/generic`
- Symbol: `CONFIG_TARGET_octeon_generic_DEVICE_ubnt_usg-pro-4=y`

## Offload / CI (pointers)

| Topic | Doc |
|-------|-----|
| Enable offload, basic verify | [docs/USG-PRO-4.md § How to test](docs/USG-PRO-4.md#how-to-test) |
| WQE↔netdev port-map check (RJ45 + SFP) | [docs/USG-PRO-4.md § Guided check](docs/USG-PRO-4.md#2-guided-check--wqe--netdev-port-map-required-once) |
| Version tags (`v25.12-usg.N`) | [docs/USG-PRO-4.md § Versioning](docs/USG-PRO-4.md#versioning) |
| lean vs router, Release assets, `apk` install | [docs/USG-PRO-4.md § Releases](docs/USG-PRO-4.md#releases-and-packages) |
| GitHub Pages apk feeds | [docs/USG-PRO-4.md § Pages](docs/USG-PRO-4.md#publishing-apks-on-github-pages) · https://halcycon.github.io/openwrt/ |
| Workflow / seeds | `build-usg-pro-4.yml`, `deploy-apk-pages.yml`, `ci/` |

In-tree offload pieces: `package/kernel/octeon-flowtable/`,
`target/linux/octeon/patches-*/710-octeon-flowtable-hooks.patch`,
`CVMSEG_SIZE=2`, cmdline `receive_group_order=1`.

## What must not be committed / uploaded to GitHub

| Path / pattern | Why |
|----------------|-----|
| `/bin`, `/build_dir`, `/staging_dir`, `/tmp`, `/logs`, `/dl` | Build outputs / downloads |
| `/.config`, `/.config.*` | Local menuconfig |
| `key-build*`, `*.pem` | Signing keys |
| Built `*.ko` / `*.apk` / `*.ipk` | Binaries belong in Releases/Pages, not git |
| Nested `package/*/.git` | Accidental gitlinks |
| `*-session.txt` | Scratch |

## Licensing

| Component | License |
|-----------|---------|
| OpenWrt tree | GPL-2.0-only (`COPYING`) |
| Kernel + staging patches | GPL-2.0 |
| `kmod-octeon-flowtable` | GPL-2.0 (upstream + kernel module) |
| `AGENTS.md`, `docs/USG-PRO-4.md`, README fork notes | MIT (docs only) |

## Agent / contributor workflow

1. Work on `usg-pro-4/factory-macs` (or a branch from it). Rebase onto
   `upstream/device/ubnt-e200` when Shiz moves. Never merge into `main`.
2. Keep offload changes reviewable; update `docs/USG-PRO-4.md` when
   behaviour or release process changes.
3. Do not vendor build artifacts or unrelated nested git repos.
4. After staging-ethernet kernel changes, rebuild and confirm
   `cvm_oct_*` in `/proc/kallsyms` before claiming offload works.
5. Publish with tags like `v25.12-usg.1` (see versioning doc).
