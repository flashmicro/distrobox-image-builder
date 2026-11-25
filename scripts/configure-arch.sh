#!/usr/bin/env bash
# Arch Linux：仅保留清华 TUNA 源 + 预装 distrobox-init 依赖
# 在 prep 容器内以 root 执行（podman exec prep bash /tmp/configure.sh）
set -euo pipefail

# 1) mirrorlist 只保留清华 TUNA
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
EOF

# 2) 先刷新 keyring，避免签名过期问题，再全量升级
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm

# 3) 预装 distrobox-init 依赖（目标是首次进容器不联网）
pacman -S --noconfirm --needed sudo curl lsof xauth

# 4) 自检
grep -Hn 'tuna' /etc/pacman.d/mirrorlist
command -v sudo curl lsof xauth
