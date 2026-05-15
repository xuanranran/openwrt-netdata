#
# Copyright (C) 2026 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=netdata-dashboard-v1
PKG_VERSION:=2.2.6
PKG_RELEASE:=1

PKG_MAINTAINER:=Josef Schlehofer <pepe.schlehofer@gmail.com>, Daniel Engberg <daniel.engberg.lists@pyret.net>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=COPYING

PKG_SOURCE:=netdata-dashboard-v1-v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/netdata/netdata/releases/download/v$(PKG_VERSION)
PKG_SOURCE_URL_FILE:=netdata-v$(PKG_VERSION).tar.gz
PKG_HASH:=bd98c146aa6d0c25f80cb50b1447b8aca8a17f0995b28a11a23e843b8f210f42

include $(INCLUDE_DIR)/package.mk

define Package/netdata-dashboard-v1
  SECTION:=admin
  CATEGORY:=Administration
  DEPENDS:=+netdata
  TITLE:=Local Netdata v1 dashboard
  URL:=https://www.netdata.cloud/
endef

define Package/netdata-dashboard-v1/description
  Local legacy v1 dashboard assets for the Netdata web UI.
endef

define Build/Compile
endef

define Package/netdata-dashboard-v1/install
	$(INSTALL_DIR) $(1)/usr/share/netdata/web
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) \
		-C $(1)/usr/share/netdata/web \
		--strip-components=4 \
		netdata-v$(PKG_VERSION)/src/web/gui/dashboard_info.js
	$(INSTALL_DIR) $(1)/usr/share/netdata/web/v1
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) \
		-C $(1)/usr/share/netdata/web/v1 \
		--strip-components=5 \
		netdata-v$(PKG_VERSION)/src/web/gui/v1
	find $(1)/usr/share/netdata/web/v1 -name '*.map' -delete
	rm -f $(1)/usr/share/netdata/web/v1/dashboard_v1.cmake
	rm -f $(1)/usr/share/netdata/web/v1/README.md
endef

$(eval $(call BuildPackage,netdata-dashboard-v1))
