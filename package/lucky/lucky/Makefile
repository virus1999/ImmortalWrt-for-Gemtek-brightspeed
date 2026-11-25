# SPDX-License-Identifier: MIT

include $(TOPDIR)/rules.mk

PKG_NAME:=lucky
PKG_VERSION:=3.8.1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=GDY666 <gdy666@foxmail.com>

LUCKY_ARCH:=

ifeq ($(ARCH),aarch64)
  LUCKY_ARCH:=arm64
endif
ifeq ($(ARCH),arm)
  ifeq ($(CONFIG_arm_v7),y)
    LUCKY_ARCH:=armv7
  else ifeq ($(CONFIG_arm_v6),y)
    LUCKY_ARCH:=armv6
  else ifneq ($(filter arm_arm926ej-s arm_xscale,$(ARCH_PACKAGES)),)
    LUCKY_ARCH:=armv5
  endif
endif
ifeq ($(ARCH),i386)
  LUCKY_ARCH:=i386
endif
ifeq ($(ARCH),x86_64)
  LUCKY_ARCH:=x86_64
endif
ifeq ($(ARCH),riscv64)
  LUCKY_ARCH:=riscv64
endif
ifeq ($(ARCH),mips)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    LUCKY_ARCH:=mips_softfloat
  else
    LUCKY_ARCH:=mips_hardfloat
  endif
endif
ifeq ($(ARCH),mipsel)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    LUCKY_ARCH:=mipsle_softfloat
  else
    LUCKY_ARCH:=mipsle_hardfloat
  endif
endif

PKG_SOURCE:=lucky_$(PKG_VERSION)_Linux_$(LUCKY_ARCH).tar.gz
# 2026-11-25：官方 GitHub release 只发到 v3.5.0，3.8.x 只在作者的发布站。
# 该站目录结构为 /v<ver>/<ver>_lucky/lucky_<ver>_Linux_<arch>.tar.gz，与 PKG_SOURCE 命名一致。
PKG_SOURCE_URL:=https://release.66666.host/v$(PKG_VERSION)/$(PKG_VERSION)_lucky
PKG_HASH:=skip
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/lucky
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Lucky network utility
  DEPENDS:=@(aarch64||arm||i386||mips||mipsel||riscv64||x86_64) @(!TARGET_gemini)
  URL:=https://github.com/gdy666/lucky
endef

define Package/lucky/description
 Lucky provides IPv4/IPv6 port forwarding, DDNS, Wake-on-LAN,
 reverse proxy, ACME automation and related network services.
endef

# 2026-11-25 出厂化：本包不再安装 /etc/config/lucky。
# 以前的 ./files/luckyuci 会在出厂就写一份 enabled='1' 的配置，
# 等于“刷完就带别人的配置、还默认开着”。现在只装二进制与 init，
# 配置由用户在 LuCI 里自己建（lucky.init 的 enabled 默认值就是 0）。
# conffiles 一并去掉，避免声明了一个不存在的文件。

define Build/Prepare
	gzip -dc $(DL_DIR)/$(PKG_SOURCE) | $(HOST_TAR) -C $(PKG_BUILD_DIR) -xf -
	$(Build/Patch)
endef

define Build/Compile
endef

define Package/lucky/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lucky $(1)/usr/bin/lucky
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/lucky-call $(1)/usr/libexec/lucky-call
	$(INSTALL_BIN) ./files/lucky-watchdog $(1)/usr/libexec/lucky-watchdog
	$(INSTALL_DIR) $(1)/usr/share/lucky
	echo '$(LUCKY_ARCH)' > $(1)/usr/share/lucky/arch
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/lucky.init $(1)/etc/init.d/lucky
endef

define Package/lucky/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /usr/libexec/lucky-watchdog sync
endef

define Package/lucky/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ] && [ "$${PKG_UPGRADE}" != 1 ]; then
	/etc/init.d/lucky stop
	/usr/libexec/lucky-watchdog remove
fi
endef

$(eval $(call BuildPackage,lucky))
