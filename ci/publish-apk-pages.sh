#!/usr/bin/env bash
# Unpack Release package tarballs into a GitHub Pages apk feed tree.
#
# Usage:
#   publish-apk-pages.sh <tag> <artifact-root> <out-dir>
#
# artifact-root: directory tree containing release assets (may be nested,
#   e.g. dist/image-lean/lean-packages.tar.gz from download-artifact).
# out-dir: site root to deploy (will contain apk/ and index.html).
#
# Layout:
#   apk/<tag>/<variant>/targets/     <- target packages.adb + .apks
#   apk/<tag>/<variant>/<feed>/      <- base, luci, packages, …
#   apk/current/<variant>/…          <- copy of this tag (Pages size policy)
set -euo pipefail

TAG="${1:?tag required (e.g. v25.12-usg.1)}"
SRC="${2:?artifact root required}"
OUT="${3:?output site root required}"
PAGES_HOST="${PAGES_HOST:-https://halcycon.github.io/openwrt}"

rm -rf "$OUT"
mkdir -p "$OUT/apk/$TAG"

find_asset() {
	local name="$1"
	find "$SRC" -type f -name "$name" | head -n1
}

# Copy feed dirs that contain packages.adb up to $dest/<feed>/.
# Handles both packages/<feed>/ and packages/<arch>/<feed>/.
install_feeds_from() {
	local root="$1"
	local dest="$2"
	local adb feed_dir feed

	while IFS= read -r -d '' adb; do
		feed_dir="$(dirname "$adb")"
		feed="$(basename "$feed_dir")"
		# Skip arch containers that only hold feeds (no packages.adb of their own
		# at this level — find only returns dirs that contain packages.adb).
		mkdir -p "$dest/$feed"
		cp -a "$feed_dir/." "$dest/$feed/"
	done < <(find "$root" -type f -name packages.adb -print0)
}

write_customfeeds() {
	local dest="$1"
	local variant="$2"
	local adb feed

	{
		echo "# USG-PRO-4 apk feed — $TAG / $variant"
		echo "# Paste into /etc/apk/repositories.d/customfeeds.list"
		echo "# Use --allow-untrusted until a signing key is published."
		if [ -f "$dest/targets/packages.adb" ]; then
			echo "$PAGES_HOST/apk/$TAG/$variant/targets/packages.adb"
		fi
		while IFS= read -r -d '' adb; do
			feed="$(basename "$(dirname "$adb")")"
			[ "$feed" = "targets" ] && continue
			echo "$PAGES_HOST/apk/$TAG/$variant/$feed/packages.adb"
		done < <(find "$dest" -mindepth 2 -maxdepth 2 -type f -name packages.adb -print0 | sort -z)
	} > "$dest/customfeeds.list"
}

publish_variant() {
	local variant="$1"
	local dest="$OUT/apk/$TAG/$variant"
	local target_tar feed_tar tmp

	target_tar="$(find_asset "${variant}-target-packages.tar.gz" || true)"
	feed_tar="$(find_asset "${variant}-packages.tar.gz" || true)"

	if [ -z "$target_tar" ] && [ -z "$feed_tar" ]; then
		echo "skip $variant: no package tarballs found"
		return 0
	fi

	mkdir -p "$dest"
	tmp="$(mktemp -d)"

	if [ -n "$target_tar" ]; then
		echo "unpack $target_tar → $dest/targets"
		mkdir -p "$tmp/target"
		tar -xzf "$target_tar" -C "$tmp/target"
		mkdir -p "$dest/targets"
		if [ -d "$tmp/target/packages" ]; then
			cp -a "$tmp/target/packages/." "$dest/targets/"
		else
			cp -a "$tmp/target/." "$dest/targets/"
		fi
	fi

	if [ -n "$feed_tar" ]; then
		echo "unpack $feed_tar → $dest/{base,luci,…}"
		mkdir -p "$tmp/feed"
		tar -xzf "$feed_tar" -C "$tmp/feed"
		if [ -d "$tmp/feed/packages" ]; then
			install_feeds_from "$tmp/feed/packages" "$dest"
		else
			install_feeds_from "$tmp/feed" "$dest"
		fi
	fi

	rm -rf "$tmp"
	write_customfeeds "$dest" "$variant"

	echo "published $variant:"
	find "$dest" -name 'packages.adb' | sort
	echo "--- customfeeds.list ---"
	cat "$dest/customfeeds.list"
}

for variant in lean router; do
	publish_variant "$variant"
done

if [ -d "$OUT/apk/$TAG" ]; then
	rm -rf "$OUT/apk/current"
	cp -a "$OUT/apk/$TAG" "$OUT/apk/current"
fi

REPO_URL="https://github.com/${GITHUB_REPOSITORY:-halcycon/openwrt}"
LEAN_FEEDS=""
if [ -f "$OUT/apk/$TAG/lean/customfeeds.list" ]; then
	LEAN_FEEDS="$(grep -v '^#' "$OUT/apk/$TAG/lean/customfeeds.list" | grep -v '^$' || true)"
fi
if [ -z "$LEAN_FEEDS" ]; then
	LEAN_FEEDS="# (lean feed not in this deploy)"
fi

# Use HTML_EOF so a line containing EOF inside the example does not terminate us.
cat > "$OUT/index.html" <<HTML_EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>USG-PRO-4 OpenWrt</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 52rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    code, pre { background: #f4f4f4; padding: 0.1em 0.35em; border-radius: 4px; }
    pre { padding: 0.75rem 1rem; overflow-x: auto; }
    .hero { border-left: 4px solid #1a7a3a; padding-left: 1rem; margin: 1.5rem 0; }
    a.primary { font-weight: 600; }
  </style>
</head>
<body>
  <h1>OpenWrt for USG-PRO-4</h1>
  <div class="hero">
    <p><strong>First time here?</strong> Read the project guide first:</p>
    <p><a class="primary" href="${REPO_URL}/blob/usg-pro-4/factory-macs/docs/USG-PRO-4.md">docs/USG-PRO-4.md</a>
      — what this fork adds, versioning, how to flash, offload testing, and apk feeds.</p>
    <p>Repo: <a href="${REPO_URL}">${GITHUB_REPOSITORY:-halcycon/openwrt}</a> ·
      <a href="${REPO_URL}/releases">Releases</a></p>
  </div>
  <h2>apk package feeds</h2>
  <p>This Pages site hosts <code>packages.adb</code> + <code>.apk</code> trees
    for CI builds. Firmware images stay on GitHub Releases.</p>
  <p>Latest deploy: <strong>${TAG}</strong>
    (<a href="apk/${TAG}/">apk/${TAG}/</a>,
     also <a href="apk/current/">apk/current/</a>) ·
    public key: <a href="keys/usg-apk.pem">keys/usg-apk.pem</a></p>
  <h3>On the device</h3>
  <p>Flash the matching Release image first, then (example for <code>lean</code>):</p>
  <pre>wget -O /etc/apk/keys/usg-apk.pem ${PAGES_HOST}/keys/usg-apk.pem   # if needed
cat &gt; /etc/apk/repositories.d/customfeeds.list &lt;&lt;'END'
${LEAN_FEEDS}
END

apk update
apk add kmod-octeon-flowtable</pre>
  <p>Ready-made lists:
    <a href="apk/${TAG}/lean/customfeeds.list">lean</a> ·
    <a href="apk/${TAG}/router/customfeeds.list">router</a></p>
</body>
</html>
HTML_EOF

# Publish the APK public key so devices can trust the feed without
# --allow-untrusted (also baked into CI-built images via base-files).
if [ -f ci/keys/usg-apk-public.pem ]; then
	mkdir -p "$OUT/keys"
	cp ci/keys/usg-apk-public.pem "$OUT/keys/usg-apk.pem"
elif [ -f "$OUT/../ci/keys/usg-apk-public.pem" ]; then
	mkdir -p "$OUT/keys"
	cp "$OUT/../ci/keys/usg-apk-public.pem" "$OUT/keys/usg-apk.pem"
fi
# When script is run from repo root after checkout:
if [ ! -f "$OUT/keys/usg-apk.pem" ] && [ -f "$(dirname "$0")/keys/usg-apk-public.pem" ]; then
	mkdir -p "$OUT/keys"
	cp "$(dirname "$0")/keys/usg-apk-public.pem" "$OUT/keys/usg-apk.pem"
fi

touch "$OUT/.nojekyll"

echo "Site root ready at $OUT"
du -sh "$OUT" "$OUT/apk"/* 2>/dev/null || true
