# CI seeds for USG-PRO-4 images

Used by [`.github/workflows/build-usg-pro-4.yml`](../.github/workflows/build-usg-pro-4.yml).

| File | Purpose |
|------|---------|
| `config.seed` | Lean image: offload + conntrack/tcpdump |
| `config-router.seed` | Lean + LuCI (HTTPS) + WireGuard |
| `feeds.conf` | `packages` + `luci` feeds (no bare `#` lines) |

This repository **is** the OpenWrt tree (unlike the ERLite overlay repo), so the
workflow builds in-place: seeds → `make defconfig` → `make`. Staging hooks and
`kmod-octeon-flowtable` are already in-tree.

Triggers:

- `workflow_dispatch` (must be run from the default branch)
- push of tags matching `v*` → build both variants and publish a GitHub Release

Adapted from [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable) CI.
