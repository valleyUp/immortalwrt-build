#!/usr/bin/env bash
# Prepare feeds and .config, then build the MangoPi M28C firmware.
# The ImmortalWrt tree is a fresh clone. This script only writes ignored files in it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENWRT_DIR="${OPENWRT_DIR:-$ROOT/openwrt}"

if [ ! -f "$OPENWRT_DIR/feeds.conf.default" ]; then
	echo "ImmortalWrt tree not found at $OPENWRT_DIR" >&2
	exit 1
fi

cd "$OPENWRT_DIR"

echo "ImmortalWrt $(git rev-parse HEAD)"

cp feeds.conf.default feeds.conf
if ! grep -q '^src-git qmodem ' feeds.conf; then
	cat "$ROOT/configs/feeds.extra" >> feeds.conf
fi

./scripts/feeds update -a
./scripts/feeds install -a

cp "$ROOT/configs/mangopi-m28c.config" .config
cat >> .config << 'EOF'
CONFIG_DEVEL=y
CONFIG_AUTOREMOVE=y
CONFIG_SIGNED_PACKAGES=y
CONFIG_SIGN_EACH_PACKAGE=y
CONFIG_SIGN_FIRMWARE=y
EOF

make defconfig

check_symbol() {
	local symbol="$1"
	if ! grep -q "^${symbol}=y$" .config; then
		echo "missing ${symbol} after defconfig" >&2
		grep -F "$symbol" .config || true
		exit 1
	fi
}

check_symbol CONFIG_TARGET_rockchip_armv8_DEVICE_widora_mangopi-m28c
check_symbol CONFIG_PACKAGE_luci-app-qmodem-next
check_symbol CONFIG_AUTOREMOVE

if [ -n "${APK_PRIVATE_KEY:-}" ]; then
	printf '%s\n' "$APK_PRIVATE_KEY" > private-key.pem
	chmod 600 private-key.pem
fi
if [ -n "${APK_PUBLIC_KEY:-}" ]; then
	printf '%s\n' "$APK_PUBLIC_KEY" > public-key.pem
fi

jobs="$(nproc)"
mem_mb="$(awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo)"
if [ "$mem_mb" -lt 12288 ]; then
	jobs=2
fi
echo "building with -j${jobs} (${mem_mb} MB available)"

make download -j"$jobs"
if ! make -j"$jobs"; then
	echo "parallel build failed; retrying with -j1 V=s" >&2
	make -j1 V=s BUILD_LOG=1
fi

out="$ROOT/firmware"
rm -rf "$out"
mkdir -p "$out"

shopt -s nullglob
images=(bin/targets/*/*/*sysupgrade.img.gz)
manifests=(bin/targets/*/*/*.manifest)
buildinfo=(bin/targets/*/*/*.buildinfo)
shopt -u nullglob

if [ "${#images[@]}" -eq 0 ]; then
	echo "no sysupgrade image was produced" >&2
	find bin/targets -maxdepth 3 -type f -print >&2 || true
	exit 1
fi

cp -a "${images[@]}" "${manifests[@]}" "${buildinfo[@]}" "$out/"
(
	cd "$out"
	sha256sum -- * > sha256sums
)

{
	echo "ImmortalWrt: $(git rev-parse HEAD)"
	echo
	echo "feeds.buildinfo:"
	echo
	cat bin/targets/*/*/feeds.buildinfo
} > "$ROOT/release-notes.txt"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
	echo "tracked upstream files were modified" >&2
	git status --short --untracked-files=no >&2
	exit 1
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "## MangoPi M28C"
		echo
		echo "- ImmortalWrt: \`$(git rev-parse HEAD)\`"
		echo "- Images:"
		for image in "${images[@]}"; do
			echo "  - \`$(basename "$image")\`"
		done
	} >> "$GITHUB_STEP_SUMMARY"
fi

echo "firmware files:"
ls -lh "$out"
