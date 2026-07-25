# CI seeds for USG-PRO-4 images

Used by [`.github/workflows/build-usg-pro-4.yml`](../.github/workflows/build-usg-pro-4.yml).

## Variants

| Seed | Variant | Includes (beyond device defaults + offload) |
|------|---------|-----------------------------------------------|
| `config.seed` | **lean** | conntrack, tcpdump |
| `config-router.seed` | **router** | LuCI HTTPS, WireGuard, Tailscale, Proton2025 theme, mwan3, pbr, adblock-fast, https-dns-proxy, htop/nano/curl/iperf3 |

Signing: both seeds set `CONFIG_SIGNED_PACKAGES` + `CONFIG_SIGN_EACH_PACKAGE`.
CI injects `USG_APK_PRIVATE_KEY` + [`keys/usg-apk-public.pem`](keys/usg-apk-public.pem).

Theme submodule: `package/luci-theme-proton2025` →
[ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025).

Full docs: [`docs/USG-PRO-4.md`](../docs/USG-PRO-4.md).

## Triggers

- `workflow_dispatch` (default branch) → artifacts
- tag `v*` → lean + router Release + GitHub Pages apk feed
- **deploy-apk-pages** → republish Pages from an existing Release

Pages: https://halcycon.github.io/openwrt/
