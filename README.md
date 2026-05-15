# openwrt-netdata

![GitHub Release](https://img.shields.io/github/v/release/xuanranran/openwrt-netdata)
![Build Status](https://img.shields.io/github/actions/workflow/status/xuanranran/openwrt-netdata/build.yml)

📊 Real-time performance monitoring for OpenWrt — Netdata v2.10.3 + LuCI interface.

## How to build

- Enter in your OpenWrt dir

- OpenWrt official Snapshots or ImmortalWrt

  *1. get netdata code & building*
  ```shell
  git clone https://github.com/xuanranran/openwrt-netdata package/netdata-feed
  make menuconfig # choose Administration -> netdata / LUCI -> Applications -> luci-app-netdata
  make package/netdata-feed/netdata/compile V=s
  make package/netdata-feed/luci-app-netdata/compile V=s
  ```

--------------

## How to install prebuilt packages

- Login OpenWrt terminal (SSH)

- Install `curl` package on OpenWrt SNAPSHOT
  ```shell
  apk update
  apk add curl
  ```

- Execute install script (Multi-architecture support)
  ```shell
  sh -c "$(curl -ksS https://raw.githubusercontent.com/xuanranran/openwrt-netdata/master/install.sh)"
  ```

  Install via ghproxy (recommended for China):
  ```shell
  sh -c "$(curl -ksS https://gh-proxy.com/https://raw.githubusercontent.com/xuanranran/openwrt-netdata/master/install.sh)"
  ```

--------------

## Supported architectures

| Architecture | SDK |
|---|---|
| x86_64 | SNAPSHOT |
| aarch64_generic | SNAPSHOT |

--------------

## Notes

- Netdata web interface is available at `http://<router-ip>:19999/v3/`
- Access via LuCI: `System → Netdata`
- Health monitoring is disabled by default to reduce resource usage
- Python/cgroups/apps plugins are disabled by default
