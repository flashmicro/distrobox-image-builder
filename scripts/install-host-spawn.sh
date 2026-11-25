#!/usr/bin/env bash
# 把 host-spawn 预装进镜像（容器内 /usr/bin/host-spawn，静态二进制）。
# 在 prep 容器内以 root 执行（podman exec prep bash /tmp/install-host-spawn.sh）
#
# 背景：distrobox 初始化容器时会自动做这一步（distrobox-host-exec -Y），
# 从 GitHub 下载 host-spawn；下载失败会被静默忽略，之后登录 shell 里
# /etc/profile.d/distrobox_profile.sh 在图形变量为空时调用它，就会报
# "host-spawn: command not found"。构建时预装好，离线恢复的机器就不会再遇到。
set -euo pipefail

# 与 distrobox 自带期望值保持一致（distrobox-host-exec -V 可查看；1.8.x 为 v1.6.0）。
# 目标机器的 distrobox 期望更新版本时会提示重新安装，可改用环境变量覆盖。
HOST_SPAWN_VERSION="${HOST_SPAWN_VERSION:-v1.6.0}"

architecture="$(uname -m)"
url="https://github.com/1player/host-spawn/releases/download/${HOST_SPAWN_VERSION}/host-spawn-${architecture}"

# 上游 release 未提供校验和，这里只校验能下载到一个非空的可执行文件
curl -fsSL -o /usr/bin/host-spawn "$url"
chmod +x /usr/bin/host-spawn
test -s /usr/bin/host-spawn

# 自检
/usr/bin/host-spawn --version
ls -la /usr/bin/host-spawn
