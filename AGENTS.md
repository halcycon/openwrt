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
```

## Hardware flow offload (octeon-flowtable)

The USG-PRO-4 SoC is a Cavium CN6120 (Octeon II). Images include
`kmod-octeon-flowtable`, a clean-room nftables flow-offload backend
ported from https://github.com/packerlschupfer/octeon-flowtable (originally
for CN50xx; CN61xx shares the same WQE/PIP/PKO model).

Kernel requirements (already applied in this tree):

- Staging hooks: `target/linux/octeon/patches-*/710-octeon-flowtable-hooks.patch`
- `CONFIG_CAVIUM_OCTEON_CVMSEG_SIZE=2`
- Boot cmdline includes `receive_group_order=1` (POW group spreading)

### Enable on device

In `/etc/config/firewall` under `config defaults`:

```text
option flow_offloading '1'
option flow_offloading_hw '1'
```

Then `fw4 reload`. Verify established forwarded flows show hardware
offload:

```text
conntrack -L | grep HW_OFFLOAD
```

Confirm the staging hook is present after a kernel rebuild:

```text
grep cvm_oct_register_rx_hook /proc/kallsyms
```

Prove fast-path engagement via the module `tx_ok` counter delta under
load (software forwarding can also hit GbE line rate when idle). Module
tunables live in `/etc/config/octeon-flowtable`.
