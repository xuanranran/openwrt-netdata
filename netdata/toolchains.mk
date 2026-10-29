# SPDX-License-Identifier: GPL-2.0-only

NETDATA_GO_SELECTED:=$(strip $(foreach p,go scripts statsd,$(CONFIG_PACKAGE_netdata-plugin-$(p))))
NETDATA_RUST_SELECTED:=$(strip $(foreach p,otel netflow systemd-journal,$(CONFIG_PACKAGE_netdata-plugin-$(p))))

ifneq ($(NETDATA_GO_SELECTED),)
PKG_BUILD_DEPENDS+=golang1.27/host
include $(TOPDIR)/feeds/packages/lang/golang/golang-values.mk
export GOROOT:=$(STAGING_DIR_HOSTPKG)/lib/go-1.27
export GOOS:=linux
export GOARCH:=$(GO_ARCH)
export GOARM:=$(GO_ARM)
export GOARM64:=$(GO_ARM64)
export GOMIPS:=$(GO_MIPS)
export GOMIPS64:=$(GO_MIPS64)
export GOTOOLCHAIN:=local
export GOCACHE:=$(TMP_DIR)/netdata-go-build
export GOMODCACHE:=$(DL_DIR)/go-mod-cache
export CC:=$(TARGET_CC)
export CXX:=$(TARGET_CXX)
endif

ifneq ($(NETDATA_RUST_SELECTED),)
PKG_BUILD_DEPENDS+=rust/host
include $(TOPDIR)/feeds/packages/lang/rust/rust-values.mk
CMAKE_OPTIONS+=-DRust_CARGO_TARGET=$(RUSTC_TARGET_ARCH)
export CARGO_HOME
export CARGO_TARGET_$(RUSTC_TARGET_UPPER)_LINKER:=$(TARGET_CC_NOCACHE)
export RUSTFLAGS:=$(CARGO_RUSTFLAGS)
export CC:=$(TARGET_CC_NOCACHE)
export TARGET_CC:=$(TARGET_CC_NOCACHE)
export TARGET_CFLAGS:=$(TARGET_CFLAGS) $(RUSTC_CFLAGS)
endif

ifneq ($(NETDATA_GO_SELECTED)$(NETDATA_RUST_SELECTED),)
export PATH:=$(STAGING_DIR_HOSTPKG)/lib/go-1.27/bin:$(STAGING_DIR_HOSTPKG)/bin:$(PATH)
endif
