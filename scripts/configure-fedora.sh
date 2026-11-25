#!/usr/bin/env bash
# Fedora 45+：repo 文件位于 /usr/share/dnf5/repos.d/（不是 /etc/yum.repos.d/）
# 把 metalink 换成清华 TUNA baseurl + 预装 distrobox-init 依赖
set -euo pipefail

for f in /usr/share/dnf5/repos.d/fedora.repo /usr/share/dnf5/repos.d/fedora-updates.repo; do
  sed -i \
    -e 's|^metalink=|#metalink=|' \
    -e 's|^#baseurl=http://download.example/pub/fedora/linux/|baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora/|' \
    "$f"
done
# fedora-cisco-openh264.repo 保持官方 metalink（清华不镜像该仓库，且体积极小）

# 预装 distrobox-init 依赖
dnf -y install sudo curl lsof xauth ca-certificates

# 自检：baseurl 已启用且指向清华
grep -Hn '^baseurl' /usr/share/dnf5/repos.d/fedora.repo /usr/share/dnf5/repos.d/fedora-updates.repo
command -v sudo curl lsof xauth
