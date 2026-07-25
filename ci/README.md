# CI seeds for USG-PRO-4 images

Used by [`.github/workflows/build-usg-pro-4.yml`](../.github/workflows/build-usg-pro-4.yml).

## Variants

| Seed | Variant | Includes (beyond device defaults + offload) |
|------|---------|-----------------------------------------------|
| `config.seed` | **lean** | `conntrack`, `tcpdump` — minimal verify toolkit |
| `config-router.seed` | **router** | lean + LuCI (HTTPS) + WireGuard |

Same device profile: `ubnt_usg-pro-4`. Full comparison, Release asset
names, and how to point a live USG’s `apk` at those packages:
[`AGENTS.md`](../AGENTS.md#image-variants-lean-vs-router).

## Files

| File | Purpose |
|------|---------|
| `config.seed` | Lean image seed |
| `config-router.seed` | Router image seed |
| `feeds.conf` | `packages` + `luci` only (no bare `#` lines) |

## Triggers

- `workflow_dispatch` (from the **default** branch) → artifacts
- tag `v*` → build both variants + GitHub Release (images + `.apk` tarballs)

This repository **is** the OpenWrt tree, so the workflow builds in-place.
Adapted from [packerlschupfer/octeon-flowtable](https://github.com/packerlschupfer/octeon-flowtable) CI.
