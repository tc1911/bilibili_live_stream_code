#!/usr/bin/env bash
set -euo pipefail

# 构建 Linux 安装包: deb / rpm / pkg.tar.zst
# 用法: build-packages.sh <版本标签>  (例如 v2.4.0)
# 前置: dist/BiliLiveTool (PyInstaller 产物)、bilibili.png (已由 ICO 转换)、packaging/linux/bilibili-live-tool.desktop
# 产物输出到仓库根目录

VERSION="${1:?usage: build-packages.sh <version-tag>}"
VER="${VERSION#v}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# --- 通用文件布局 ---
STAGE="pkgroot"
rm -rf "$STAGE"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/applications" "$STAGE/usr/share/icons/hicolor/512x512/apps"
install -m755 dist/BiliLiveTool "$STAGE/usr/bin/BiliLiveTool"
install -m644 bilibili.png "$STAGE/usr/share/icons/hicolor/512x512/apps/bilibili-live-tool.png"
install -m644 packaging/linux/bilibili-live-tool.desktop "$STAGE/usr/share/applications/bilibili-live-tool.desktop"

# --- deb (Debian/Ubuntu) ---
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: bilibili-live-tool
Version: $VER
Section: net
Priority: optional
Architecture: amd64
Maintainer: BiliLiveTool Maintainers <noreply@github.com>
Homepage: https://github.com/tc1911/bilibili_live_stream_code
Depends: libnss3, libxcomposite1, libxcursor1, libxdamage1, libxext6, libxfixes3, libxi6, libxrender1, libxtst6, libxcb-glx0, libxcb-icccm4, libxcb-image0, libxcb-keysyms1, libxcb-randr0, libxcb-render-util0, libxcb-render0, libxcb-shape0, libxcb-shm0, libxcb-sync1, libxcb-util1, libxcb-xfixes0, libxcb-xinerama0, libxcb-cursor0, libxcb1, libxkbcommon-x11-0, libxkbcommon0
Description: Bilibili live streaming tool
 Get RTMP/SRT stream keys for third-party broadcasting software (OBS etc.),
 with danmaku monitoring and live room management.
EOF
dpkg-deb --root-owner-group --build "$STAGE" "BiliLiveTool-${VERSION}-linux-amd64.deb"

# --- rpm (Fedora/RHEL) ---
sudo apt-get update -qq
sudo apt-get install -y -qq rpm
mkdir -p rpmbuild/SPECS rpmbuild/SOURCES rpmbuild/RPMS
cp dist/BiliLiveTool rpmbuild/SOURCES/
cp bilibili.png rpmbuild/SOURCES/
cp "$STAGE/usr/share/applications/bilibili-live-tool.desktop" rpmbuild/SOURCES/
cat > rpmbuild/SPECS/bilibili-live-tool.spec <<EOF
Name: bilibili-live-tool
Version: $VER
Release: 1
Summary: Bilibili live streaming tool
License: MIT
URL: https://github.com/tc1911/bilibili_live_stream_code
Source0: BiliLiveTool
Source1: bilibili.png
Source2: bilibili-live-tool.desktop
BuildArch: x86_64
Requires: nss, xcb-util, xcb-util-cursor, xcb-util-wm, xcb-util-image, xcb-util-keysyms, xcb-util-renderutil, libXcomposite, libXcursor, libXdamage, libXext, libXfixes, libXi, libXrender, libXtst, libxcb, libxkbcommon, libxkbcommon-x11
%description
Get RTMP/SRT stream keys for third-party broadcasting software (OBS etc.),
with danmaku monitoring and live room management.
%install
install -Dm755 %{_sourcedir}/BiliLiveTool %{buildroot}%{_bindir}/BiliLiveTool
install -Dm644 %{_sourcedir}/bilibili.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/bilibili-live-tool.png
install -Dm644 %{_sourcedir}/bilibili-live-tool.desktop %{buildroot}%{_datadir}/applications/bilibili-live-tool.desktop
%files
%{_bindir}/BiliLiveTool
%{_datadir}/icons/hicolor/512x512/apps/bilibili-live-tool.png
%{_datadir}/applications/bilibili-live-tool.desktop
EOF
rpmbuild -bb --define "_topdir $ROOT/rpmbuild" rpmbuild/SPECS/bilibili-live-tool.spec
cp rpmbuild/RPMS/x86_64/bilibili-live-tool-${VER}-1.x86_64.rpm "BiliLiveTool-${VERSION}-linux-amd64.rpm"

# --- pkg.tar.zst (Arch Linux, 使用官方 makepkg 保证包结构合法) ---
mkdir -p archbuild
cp dist/BiliLiveTool archbuild/
cp bilibili.png archbuild/
cp "$STAGE/usr/share/applications/bilibili-live-tool.desktop" archbuild/
cat > archbuild/PKGBUILD <<EOF
pkgname=bilibili-live-tool
pkgver=$VER
pkgrel=1
pkgdesc="Bilibili live streaming tool"
arch=('x86_64')
url="https://github.com/tc1911/bilibili_live_stream_code"
license=('MIT')
depends=('nss' 'xcb-util' 'xcb-util-cursor' 'xcb-util-wm' 'xcb-util-image' 'xcb-util-keysyms' 'xcb-util-renderutil' 'libxcomposite' 'libxcursor' 'libxdamage' 'libxext' 'libxfixes' 'libxi' 'libxrender' 'libxtst' 'libxkbcommon' 'libxkbcommon-x11')
options=('!strip' '!debug')
source=('BiliLiveTool' 'bilibili.png' 'bilibili-live-tool.desktop')
sha256sums=('SKIP' 'SKIP' 'SKIP')
package() {
  install -Dm755 "\$srcdir/BiliLiveTool" "\$pkgdir/usr/bin/BiliLiveTool"
  install -Dm644 "\$srcdir/bilibili.png" "\$pkgdir/usr/share/icons/hicolor/512x512/apps/bilibili-live-tool.png"
  install -Dm644 "\$srcdir/bilibili-live-tool.desktop" "\$pkgdir/usr/share/applications/bilibili-live-tool.desktop"
}
EOF
docker run --rm -v "$ROOT/archbuild:/build" archlinux:latest bash -euxo pipefail -c '
  pacman -Syu --noconfirm --needed base-devel
  useradd -m builder
  chown -R builder:builder /build
  su builder -c "cd /build && makepkg -f --noconfirm"
'
cp archbuild/bilibili-live-tool-${VER}-1-x86_64.pkg.tar.zst .

echo "== 构建完成 =="
ls -lh "BiliLiveTool-${VERSION}-linux-amd64.deb" "BiliLiveTool-${VERSION}-linux-amd64.rpm" "bilibili-live-tool-${VER}-1-x86_64.pkg.tar.zst"
