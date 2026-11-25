#!/usr/bin/env bash
# Ubuntu 24.04：先装 ca-certificates（用默认官方 http 源），再切清华 https 源
# https 是硬要求：生产环境中间网络可能劫持 http 流量，且后续 apt 全走 https 更稳
# 在 prep 容器内以 root 执行（podman exec prep bash /tmp/configure.sh）
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# 1) 用镜像自带的官方 http 源先装证书包
apt-get update
apt-get install -y --no-install-recommends ca-certificates

# 2) archive 与 security 全部指向清华 TUNA（https）
sed -i \
  -e 's|http://archive.ubuntu.com/ubuntu/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|' \
  -e 's|http://security.ubuntu.com/ubuntu/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|' \
  /etc/apt/sources.list.d/ubuntu.sources

# 3) 用新 https 源刷新索引，预装 distrobox-init 依赖 + zh_CN locale + 时区数据
#    ubuntu 基础镜像没有 tzdata：缺它时 distrobox 的 apt 事务后钩子
#    （/etc/distrobox-post-hook.sh）会在每次 apt-get install 末尾打印一条
#    "mount: /etc/localtime: special device /usr/share/zoneinfo/... does not exist"。
apt-get update
apt-get install -y --no-install-recommends sudo curl lsof xauth language-pack-zh-hans tzdata

# 4) 自检：URIs 均为 https，locale 与时区数据就位
grep -n '^URIs' /etc/apt/sources.list.d/ubuntu.sources
command -v sudo curl lsof xauth
locale -a | grep -x 'zh_CN.utf8'
test -e /usr/share/zoneinfo/Asia/Shanghai
update-ca-certificates --fresh >/dev/null
