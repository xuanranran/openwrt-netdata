#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-build}"
TARGET="${2:?target required}"
SUBTARGET="${3:?subtarget required}"
case "$TARGET/$SUBTARGET" in
    x86/64|armsr/armv8) ;;
    *) echo "Unsupported SDK target: $TARGET/$SUBTARGET" >&2; exit 2 ;;
esac
BASE="https://downloads.openwrt.org/snapshots/targets/$TARGET/$SUBTARGET"

if [ "$MODE" = resolve ]; then
    CHECKSUMS="$(mktemp)"
    trap 'rm -f "$CHECKSUMS"' EXIT
    curl -fsSL --retry 3 --connect-timeout 20 --max-time 120 "$BASE/sha256sums" -o "$CHECKSUMS"
    SDK_ENTRY="$(awk '$2 ~ /openwrt-sdk-.*Linux-x86_64\.tar\.(zst|xz)$/ { print $1, $2 }' "$CHECKSUMS")"
    [ "$(printf '%s\n' "$SDK_ENTRY" | wc -l)" -eq 1 ] && [ -n "$SDK_ENTRY" ]
    read -r SDK_HASH SDK_FILE <<< "$SDK_ENTRY"
    SDK_FILE="${SDK_FILE#\*}"
    [[ "$SDK_HASH" =~ ^[a-f0-9]{64}$ ]]
    [[ "$SDK_FILE" != */* ]]
    printf 'file=%s\nhash=%s\n' "$SDK_FILE" "$SDK_HASH"
    exit 0
fi
[ "$MODE" = build ]
: "${SDK_FILE:?Run resolve first}"
: "${SDK_HASH:?Run resolve first}"
: "${EXPECTED_PKG_ARCH:?Package architecture required}"
[[ "$SDK_HASH" =~ ^[a-f0-9]{64}$ ]]
[[ "$SDK_FILE" != */* ]]

# Python wheel installers reject interpreter paths longer than 124 characters.
# A short physical path is needed; a symlink into the checkout is insufficient.
SDK_CACHE_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/netdata-sdk"
mkdir -p "$SDK_CACHE_ROOT"
SDK_CACHE_ROOT="$(cd "$SDK_CACHE_ROOT" && pwd -P)"
SDK_DIR="$SDK_CACHE_ROOT/$TARGET-$SUBTARGET/${SDK_HASH:0:12}"
DIST="$ROOT/dist/$EXPECTED_PKG_ARCH"
mkdir -p "$SDK_DIR" "$DIST"
if [ -f "$SDK_DIR/.netdata-sdk-ready" ] && \
    [ "$(< "$SDK_DIR/.netdata-sdk-ready")" != "$SDK_HASH" ]; then
    echo "SDK cache checksum mismatch: $SDK_DIR" >&2; exit 1
fi
if [ ! -f "$SDK_DIR/.netdata-sdk-ready" ]; then
    ARCHIVE="$(mktemp)"
    trap 'rm -f "$ARCHIVE"' EXIT
    curl -fLsS --retry 3 --connect-timeout 20 --max-time 900 "$BASE/$SDK_FILE" -o "$ARCHIVE"
    printf '%s  %s\n' "$SDK_HASH" "$ARCHIVE" | sha256sum -c -
    tar -xf "$ARCHIVE" -C "$SDK_DIR" --strip-components=1
    printf '%s\n' "$SDK_HASH" > "$SDK_DIR/.netdata-sdk-ready"
fi

cd "$SDK_DIR"
cleanup() {
    if [ "${CURL_PATCHED:-0}" = 1 ]; then
        patch -s -R -d feeds/packages -p1 < "$ROOT/scripts/sdk-patches/curl-menu-visibility.patch"
    fi
    if [ -n "${ARCHIVE:-}" ]; then rm -f "$ARCHIVE"; fi
}
trap cleanup EXIT
./scripts/feeds update base packages luci
# Avoid a feature -> package -> feature Kconfig cycle in the upstream curl
# menu when conditional library constraints are propagated by SDK metadata.
if grep -qx 'if PACKAGE_libcurl' feeds/packages/net/curl/Config.in; then
    patch -d feeds/packages -p1 < "$ROOT/scripts/sdk-patches/curl-menu-visibility.patch"
    CURL_PATCHED=1
fi
# Clear feed links from older cached builds, not the compiled dependencies.
./scripts/feeds uninstall -a
# Install only the sources needed by the enabled Netdata modules. The feeds
# installer recursively installs their runtime and host build dependencies.
./scripts/feeds install \
    zlib libuuid libuv libmnl liblz4 libjson-c libyaml libopenssl libcurl \
    protobuf libzstd libunwind libelf libnetfilter-acct libcups \
    python3 python3-yaml python3-urllib3 bash libpcre2 golang1.27 rust luci-base

# Replace only this feed's copy; cached dependencies remain available.
PACKAGE_ROOT="$SDK_DIR/package/netdata-feed"
case "$(realpath -m "$PACKAGE_ROOT")" in "$SDK_DIR/package/netdata-feed") ;; *) exit 2 ;; esac
rm -rf "$PACKAGE_ROOT"
mkdir -p "$PACKAGE_ROOT"
cp -a "$ROOT/netdata" "$ROOT/luci-app-netdata" "$PACKAGE_ROOT/"
rm -f package/feeds/packages/netdata

cat > .config <<'EOF'
# CONFIG_ALL is not set
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL_NONSHARED is not set
# CONFIG_SIGN_EACH_PACKAGE is not set
CONFIG_PACKAGE_netdata=m
CONFIG_PACKAGE_netdata-dashboard-v3=m
CONFIG_PACKAGE_netdata-plugin-logread=m
CONFIG_PACKAGE_netdata-tools-log2journal=m
CONFIG_PACKAGE_luci-app-netdata=m
CONFIG_LUCI_LANG_zh_Hans=y
EOF
printf 'CONFIG_TARGET_%s=y\nCONFIG_TARGET_%s_%s=y\n' "$TARGET" "$TARGET" "$SUBTARGET" >> .config
MODULES="$(sed -n 's/^NETDATA_PLUGIN_PACKAGES:=//p' "$ROOT/netdata/Makefile")"
for MODULE in $MODULES; do
    printf 'CONFIG_PACKAGE_netdata-plugin-%s=m\n' "$MODULE" >> .config
done
COLLECTORS="$(sed -n 's/^NETDATA_GO_COLLECTORS:=//p' "$ROOT/netdata/packages/go-collectors.mk")"
for COLLECTOR in $COLLECTORS; do
    printf 'CONFIG_PACKAGE_netdata-collector-%s=m\n' "${COLLECTOR//_/-}" >> .config
done
cp .config .config.netdata-seed
make defconfig 2>&1 | tee netdata-defconfig.log
python3 "$ROOT/scripts/check-sdk-config.py" .config .config.netdata-seed \
    netdata-defconfig.log "$EXPECTED_PKG_ARCH"
JOBS="${BUILD_JOBS:-$(nproc)}"
make package/netdata-feed/netdata/clean
make package/netdata-feed/luci-app-netdata/clean
make package/netdata-feed/netdata/download -j"$JOBS" V=s
make package/netdata-feed/netdata/compile -j"$JOBS" V=sc
make package/netdata-feed/luci-app-netdata/compile -j"$JOBS" V=sc

# Include runtime dependencies, but omit development packages and kernel modules.
find bin/packages -type f \( -name '*.apk' -o -name '*.ipk' \) \
    ! -name '*-dev-*' ! -name '*-dev_*' ! -name 'kmod-*' \
    -exec cp -f {} "$DIST/" \;
PACKAGES="netdata netdata-dashboard-v3 netdata-plugin-logread netdata-tools-log2journal luci-app-netdata"
for MODULE in $MODULES; do PACKAGES="$PACKAGES netdata-plugin-$MODULE"; done
for COLLECTOR in $COLLECTORS; do PACKAGES="$PACKAGES netdata-collector-${COLLECTOR//_/-}"; done
for PACKAGE in $PACKAGES; do
    find "$DIST" -maxdepth 1 -type f \( -name "$PACKAGE-[0-9]*.apk" -o -name "${PACKAGE}_*.ipk" \) \
        -print -quit | grep -q . || { echo "Missing package: $PACKAGE" >&2; exit 1; }
done
(cd "$DIST" && sha256sum ./*.apk > SHA256SUMS)
mkdir -p "$ROOT/upload"
tar -czf "$ROOT/upload/netdata-$EXPECTED_PKG_ARCH-SNAPSHOT.tar.gz" -C "$DIST" .
