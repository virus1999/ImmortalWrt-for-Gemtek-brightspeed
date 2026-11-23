#!/bin/bash
# XG2010G 定制固件构建脚本（自用）
# 在哪跑：任意 x86_64 GNU/Linux，Debian/Ubuntu 系，≥4 核 / ≥8GB 内存 / ≥60GB 空闲磁盘
# 用法：bash build.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "== 0. 检查 package/custom 是否齐全 =="
for d in daed luci-app-daed lucky luci-app-lucky; do
  [ -f "package/custom/$d/Makefile" ] || { echo "缺少 package/custom/$d"; exit 1; }
done
grep -q 'PKG_VERSION:=3.5.0' package/custom/lucky/Makefile || { echo "!! package/custom/lucky 不是 3.5.0"; exit 1; }
echo "定制包就位"

echo "== 1. 依赖 =="
# 首次跑需要，Ubuntu/Debian：
# sudo apt update && sudo apt install -y build-essential clang llvm lld gcc g++ binutils \
#   bzip2 gawk gettext git libncurses-dev libssl-dev python3 python3-setuptools rsync \
#   unzip wget xsltproc zlib1g-dev file which perl sed make nodejs npm

echo "== 2. feeds =="
./scripts/feeds update -a
./scripts/feeds install -a
bash scripts/fix-stale-golang-host.sh
FEED_PATCHES_STRICT=1 bash scripts/select-feed-providers.sh
FEED_PATCHES_STRICT=1 bash scripts/apply-feed-patches.sh

echo "== 2b. 移走 feeds 里同名的旧 lucky 包，避免与 package/custom 冲突 =="
for n in lucky luci-app-lucky; do
  find feeds -name Makefile -exec grep -l "PKG_NAME:=$n\$" {} \; 2>/dev/null | while read -r mk; do
    src_dir="$(dirname "$mk")"
    case "$src_dir" in
      */package/custom/*) continue ;;
    esac
    echo "   移走 $src_dir"
    mv "$src_dir" "${src_dir}.disabled-by-custom"
  done
done

echo "== 3. 应用定制配置 =="
cp my-2010.config .config
make defconfig

echo "== 4. 校验关键项没被 defconfig 抹掉 =="
for k in CONFIG_TARGET_airoha_an7581_DEVICE_gemtek_xg2010g-ubi \
         CONFIG_PACKAGE_adguardhome \
         CONFIG_PACKAGE_luci-app-adguardhome \
         CONFIG_PACKAGE_daed \
         CONFIG_PACKAGE_luci-app-daed \
         CONFIG_KERNEL_DEBUG_INFO_BTF \
         CONFIG_KERNEL_BPF_EVENTS \
         CONFIG_KERNEL_XDP_SOCKETS \
         CONFIG_PACKAGE_kmod-sched-bpf \
         CONFIG_PACKAGE_kmod-xdp-sockets-diag; do
  grep -q "^$k=y" .config || { echo "!! $k 没选中，检查 package/custom 是否就位"; exit 1; }
done
grep -q '^CONFIG_PACKAGE_lucky=y' .config || { echo "!! lucky 没选中"; exit 1; }
grep -q '^CONFIG_PACKAGE_luci-app-lucky=y' .config || { echo "!! luci-app-lucky 没选中"; exit 1; }
grep -q '^# CONFIG_PACKAGE_luci-app-passwall is not set' .config || { echo "!! passwall 没关掉"; exit 1; }
grep -q '^# CONFIG_PACKAGE_luci-app-ssr-plus is not set' .config || { echo "!! ssr-plus 没关掉"; exit 1; }
echo "校验通过"

echo "== 5. 版本串 =="
git remote add upstream https://github.com/immortalwrt/immortalwrt.git 2>/dev/null || true
git fetch --no-tags upstream master 2>/dev/null || true
BUILD_DATE=$(TZ=Asia/Shanghai date +'%Y%m%d')
REPO_COMMIT=$(git rev-parse --short=8 HEAD)
UPSTREAM_COMMIT=$(git rev-parse --short=8 "$(git merge-base HEAD upstream/master 2>/dev/null || git rev-parse HEAD)")
BUILD_DATE="$BUILD_DATE" BUILD_ID="$BUILD_DATE-$REPO_COMMIT-$UPSTREAM_COMMIT" \
REPO_COMMIT="$REPO_COMMIT" UPSTREAM_COMMIT="$UPSTREAM_COMMIT" \
VERSION_CODE="$BUILD_DATE-$REPO_COMMIT-$UPSTREAM_COMMIT" \
bash scripts/set-build-version.sh .config
bash scripts/check-distfeeds.sh

echo "== 6. 下载 + 编译 =="
make download -j"$(nproc)" BUILD_LOG=1 2>&1 | tee download.log
make -j"$(nproc)" world BUILD_LOG=1 2>&1 | tee build.log

echo "== 7. 产物 =="
ls -l bin/targets/airoha/an7581/*.itb bin/targets/airoha/an7581/*manifest 2>/dev/null || true

echo "== 8. 只刷 sysupgrade 的 .itb，别碰 .fip / preloader / chainload-uboot =="
