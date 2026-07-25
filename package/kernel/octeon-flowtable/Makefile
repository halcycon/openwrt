#
# Copyright (c) 2026 cavium-offload-port / octeon-flowtable
# Ported for Ubiquiti USG-PRO-4 (CN6120) OpenWrt tree.
#
# SPDX-License-Identifier: GPL-2.0
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=octeon-flowtable
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=USG-PRO-4 OpenWrt

include $(INCLUDE_DIR)/package.mk

define KernelPackage/octeon-flowtable
  SUBMENU:=Network Devices
  TITLE:=Octeon nftables flow offload (CN50xx/CN61xx)
  DEPENDS:=@TARGET_octeon +kmod-nft-offload +kmod-nf-flow
  FILES:=$(PKG_BUILD_DIR)/octeon_flowtable.ko
  AUTOLOAD:=$(call AutoProbe,octeon_flowtable)
endef

define KernelPackage/octeon-flowtable/description
  WQE-level RX hook + in-buffer NAT/VLAN (retag/push/pop/QinQ) rewrite + PKO
  transmit for Cavium Octeon (CN50xx / CN61xx). Bypasses the Linux stack for
  forwarded flows claimed by nftables hardware flow offload; misses fall
  through to normal routing.

  Requires the staging-driver hook patch
  target/linux/octeon/patches-*/710-octeon-flowtable-hooks.patch.
endef

define KernelPackage/octeon-flowtable/conffiles
/etc/config/octeon-flowtable
endef

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" modules
endef

define KernelPackage/octeon-flowtable/install
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) ./files/octeon-flowtable.init $(1)/etc/init.d/octeon-flowtable
	$(INSTALL_CONF) ./files/octeon-flowtable.config $(1)/etc/config/octeon-flowtable
endef

$(eval $(call KernelPackage,octeon-flowtable))
