# AGENTS.md

## Repository purpose

This repository is a GitHub-maintained OpenWrt tree based on Shiz's
USG-PRO-4 work hosted on Codeberg.

Upstream repository:

- https://codeberg.org/Shiz/openwrt
- Primary development branch: `device/ubnt-e200`

Git remotes should normally be arranged as:

- `origin`: `git@github.com:halcycon/openwrt.git`
- `upstream`: `https://codeberg.org/Shiz/openwrt.git`

The GitHub repository is not a native GitHub fork because the source
repository is hosted on Codeberg. It retains the complete Git history
and tracks Codeberg through the `upstream` remote.

## Supported hardware

The work in this branch targets:

- Ubiquiti UniFi Security Gateway Pro 4
- Marketing name: USG-PRO-4
- OpenWrt board name: `ubnt,usg-pro-4`
- Octeon system identification: `UBNT_E220`
- OpenWrt target: `octeon/generic`

The development-branch device configuration symbol is:

```text
CONFIG_TARGET_octeon=y
CONFIG_TARGET_octeon_generic=y
CONFIG_TARGET_octeon_generic_DEVICE_ubnt_usg-pro-4=y
