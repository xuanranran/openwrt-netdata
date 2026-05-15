#
# Copyright (C) 2026 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=netdata-dashboard-v3
PKG_VERSION:=2.10.3
PKG_RELEASE:=1

PKG_MAINTAINER:=Josef Schlehofer <pepe.schlehofer@gmail.com>, Daniel Engberg <daniel.engberg.lists@pyret.net>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=dist/agent/v3/LICENSE.txt

PKG_SOURCE:=netdata-dashboard-v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://app.netdata.cloud
PKG_SOURCE_URL_FILE:=agent.tar.gz
PKG_HASH:=0a175680392e20c2bb9737c31f4610d4169a144ef93cd60b0626e3d9a23ecda7

include $(INCLUDE_DIR)/package.mk

define Package/netdata-dashboard-v3
  SECTION:=admin
  CATEGORY:=Administration
  DEPENDS:=+netdata
  TITLE:=Local Netdata v3 dashboard
  URL:=https://www.netdata.cloud/
endef

define Package/netdata-dashboard-v3/description
  Local v3 dashboard assets for the Netdata web UI.
endef

define Build/Compile
endef

define Package/netdata-dashboard-v3/install
	$(INSTALL_DIR) $(1)/usr/share/netdata/web
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) \
		-C $(1)/usr/share/netdata/web \
		--strip-components=2 \
		dist/agent
	find $(1)/usr/share/netdata/web/v3 -name '*.map' -delete
	$(INSTALL_DATA) ./files/web-index.html $(1)/usr/share/netdata/web/index.html
endef

$(eval $(call BuildPackage,netdata-dashboard-v3))
