#!/usr/bin/env bash
# Arch Linux：仅保留清华 TUNA 源 + 预装 distrobox-init 依赖 + zh_CN locale
# 在 prep 容器内以 root 执行（podman exec prep bash /tmp/configure.sh）
set -euo pipefail

# 1) mirrorlist 只保留清华 TUNA
cat > /etc/pacman.d/mirrorlist <<'EOF'
## China
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
EOF

# 2) 先刷新 keyring，避免签名过期问题，再全量升级
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm

# 3) 预装 distrobox-init 依赖（目标是首次进容器不联网）
pacman -S --noconfirm --needed sudo curl lsof xauth

# 4) zh_CN.UTF-8 locale
# Arch 的 glibc-locales 装的是预编译好的 locale 目录（/usr/lib/locale/zh_CN.utf8），
# 不含 zh_CN 的源定义。不要在 /etc/locale.gen 里启用 zh_CN，也不要跑 locale-gen，
# 否则会报 "cannot open locale definition file zh_CN"。
pacman -S --noconfirm --needed glibc-locales

# 5) 自检
grep -Hn 'tuna' /etc/pacman.d/mirrorlist
command -v sudo curl lsof xauth
locale -a | grep -x 'zh_CN.utf8'
