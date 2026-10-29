# openwrt-netdata

![GitHub Release](https://img.shields.io/github/v/release/xuanranran/openwrt-netdata)
![Build Status](https://img.shields.io/github/actions/workflow/status/xuanranran/openwrt-netdata/build.yml)

📊 Real-time performance monitoring for OpenWrt — Netdata v2.12.2 + LuCI interface.

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

## Package Modules

Select packages under `Administration -> Netdata`. All native components share
one source build; only selected optional collectors are enabled in CMake.

| Package | Contents |
|---|---|
| `netdata` | Agent, built-in system collectors, DBENGINE and cloud support |
| `netdata-dashboard-v3` | V3 web assets, downloaded separately with hash checking skipped |
| `netdata-plugin-logread` | OpenWrt logd, kernel and application file Logs function |
| `netdata-plugin-apps` | Per-process CPU, memory and I/O monitoring |
| `netdata-plugin-debugfs` | DebugFS collectors |
| `netdata-plugin-perf` | Linux performance counters |
| `netdata-plugin-slabinfo` | Kernel SLAB allocator monitoring |
| `netdata-plugin-python` | Python collectors and their stock configuration |
| `netdata-plugin-charts` | Bash chart collectors and their stock configuration |
| `netdata-plugin-network-viewer` | Network connection viewer |
| `netdata-plugin-local-listeners` | Local listening socket helper |
| `netdata-plugin-cgroup-network` | Cgroup network namespace helper |
| `netdata-plugin-nfacct` | Netfilter accounting |
| `netdata-plugin-cups` | CUPS print server monitoring |
| `netdata-plugin-go` | Go collector engine; install individual collector profiles below |
| `netdata-plugin-scripts` | Nagios-compatible external scripts |
| `netdata-plugin-statsd` | StatsD receiver |
| `netdata-plugin-otel` | OpenTelemetry metrics, logs and traces |
| `netdata-plugin-netflow` | NetFlow, IPFIX and sFlow receiver |
| `netdata-plugin-systemd-journal` | Read journal files using the Rust provider; no journald daemon required |
| `netdata-plugin-ebpf` | 64-bit kernel eBPF CO-RE monitoring |
| `netdata-tools-log2journal` | Convert text logs to journal export format |

`luci-app-netdata` selects the agent, V3 dashboard and logread plugin. Installing
the agent alone does not require the dashboard download or a Rust/Go toolchain.
Go and Rust toolchains are build dependencies only when their plugins are selected.
Rust receivers and eBPF currently target x86_64/aarch64; kernel support, privileges
and suitable source data are still required at runtime. The journal reader reads
existing journal files; it does not turn OpenWrt logd into journald. OpenWrt Logs
continues to use `netdata-plugin-logread`.

### Individual Go Collectors

`Administration -> Netdata Go collectors` contains individual
`netdata-collector-*` configuration packages. Examples include:

| Function | Examples |
|---|---|
| Network devices | `snmp`, `snmp-traps`, `snmp-topology`, `panos` |
| Routers and DNS | `dnsmasq`, `dnsmasq-dhcp`, `dns-query`, `unbound`, `pihole` |
| VPN | `wireguard`, `openvpn`, `openvpn-status-log` |
| Databases | `mysql`, `postgres`, `redis`, `mongodb`, `mssql`, `oracledb` |
| Web servers | `nginx`, `apache`, `lighttpd`, `phpfpm`, `web-log` |
| Containers | `docker`, `docker-engine`, `k8s-state`, `k8s-kubelet` |
| Hardware | `smartctl`, `nvme`, `redfish`, `upsd`, `smbios-memory` |
| Endpoint checks | `ping`, `httpcheck`, `portcheck`, `x509check`, `s3check` |
| Generic metrics | `prometheus`, `cloudwatch`, `azure-monitor` |

These packages contain stock configuration templates, not separate Go binaries.
They enable their module in generated stock `go.d.conf`; removing a profile
disables it there. The Go engine still contains all upstream Go collector code.
`/etc/netdata/go.d.conf` remains a user override. Configure jobs, credentials and
any external commands required by a collector under `/etc/netdata/go.d/`.
Local `logind` and `systemdunits` collectors are excluded on procd systems.

Package definitions live in `netdata/packages/*.mk`; common CMake options live
in `netdata/build-options.mk`. Collector definitions are grouped by function in
`netdata/packages/collectors/`. DBENGINE storage and libunwind stack traces can be
selected under the agent's `Core features` menu. ML anomaly detection, Prometheus
remote-write, WebRTC, the cgroup lookup server and the MCP stdio bridge also have
individual options. They are compiled into the agent
rather than shipped as separate executables. Installation uses CMake components to
keep files owned by exactly one package. Optional collectors may also need to
be enabled in `/etc/netdata/netdata.conf` after installation.
Built-in proc, diskspace, timex, cgroups, TC, idlejitter, health, registry and
exporting defaults have their own menu. These set the initial stock configuration;
they do not remove compiled code or overwrite an existing user configuration.

### Scope and Build Requirements

Go requires the feed's Go 1.27 host compiler. Rust modules use the feed's Rust
target mapping and target linker. Some optional upstream components fetch their
pinned build dependencies (Corrosion, Cargo/Go modules, dlib, libbpf, eBPF objects,
snappy or libdatachannel); their builds need network access. Full cross compilation
and runtime compatibility have not yet been verified on this development branch.

Windows/macOS plugins and systemd units are not applicable to OpenWrt/procd.
FreeIPMI, Xen and the MongoDB exporter are not exposed as selectable builds yet:
the official feed lacks the required libipmimonitoring, Xen host libraries or
libmongoc packaging. IBM collectors require additional vendor libraries/CGO and
are also excluded. Monitoring a remote MongoDB server is supported by the Go
`netdata-collector-mongodb` profile. These exclusions are dependency limitations,
not a claim that those features are impossible to port.

The SDK workflow builds all listed modules for x86_64 and aarch64 SNAPSHOT.
It downloads and verifies the official SDK, builds target code and dependencies,
and publishes after both architectures succeed. Only x86_64 persists an SDK
cache, scoped to the SDK archive hash; older reference caches are pruned per branch.
Completed SDK dependencies are cached even after a package build fails so retries
do not rebuild them. Netdata itself is cleaned before each build.
SDK CI uses official prebuilt Go and Rust host toolchains with the matching musl
Rust target. Normal OpenWrt builds default to the feeds toolchains; both modes
pass explicit compiler paths to avoid picking up an unrelated system Rust.
The source archive is pinned by SHA256; the rolling V3 dashboard is not pinned.
The installer upgrades optional modules already installed on the device and skips
new optional modules. Install their APK/IPK files separately to add collectors.

## Runtime Notes

- Netdata web interface is available at `http://<router-ip>:19999/v3/`
- Access via LuCI: `System → Netdata`
- Health monitoring is enabled by default and can be disabled in the feature menu
- Python/cgroups/apps plugins are disabled by default
