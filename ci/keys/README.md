# USG APK signing keys

OpenWrt (`CONFIG_SIGN_EACH_PACKAGE` + `CONFIG_SIGNED_PACKAGES`) signs each
`.apk` and the `packages.adb` index with an ECDSA P-256 key:

| File / secret | Role |
|---------------|------|
| `usg-apk-public.pem` (this directory) | Public key — committed. Copied into images as `/etc/apk/keys/` and published on Pages. |
| GitHub Actions secret `USG_APK_PRIVATE_KEY` | Private key — **never** in git. CI writes it to `private-key.pem` before the build. |

## Why this removes `--allow-untrusted`

- Firmware built by CI embeds `usg-apk-public.pem` via `base-files`.
- Packages / indexes from the **same** CI key verify on that firmware with plain `apk add` / `apk update`.
- If you install packages onto an image that does **not** carry this key, either:
  - `cp` the public key to `/etc/apk/keys/` on the device, or
  - keep using `--allow-untrusted`.

## Rotate / regenerate

```bash
openssl ecparam -name prime256v1 -genkey -noout -out /tmp/usg-apk-private.pem
openssl ec -in /tmp/usg-apk-private.pem -pubout -out ci/keys/usg-apk-public.pem
gh secret set USG_APK_PRIVATE_KEY --repo halcycon/openwrt < /tmp/usg-apk-private.pem
shred -u /tmp/usg-apk-private.pem
# commit the new public key, then rebuild images so devices get the new key
```

After rotation, old packages signed with the previous key will not verify
against the new public key (and vice versa).
