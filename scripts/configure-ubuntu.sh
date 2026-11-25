#!/usr/bin/env bash
# Ubuntu 24.04：先装 ca-certificates（用默认官方 http 源），再切清华 https 源
# https 是硬要求：生产环境中间网络可能劫持 http 流量，且后续 apt 全走 https 更稳
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

# 3) 用新 https 源刷新索引并预装 distrobox-init 依赖
apt-get update
apt-get install -y --no-install-recommends sudo curl lsof xauth

# 4) 自检：URIs 均为 https 且证书可用
grep -n '^URIs' /etc/apt/sources.list.d/ubuntu.sources
command -v sudo curl lsof xauth
update-ca-certificates --fresh >/dev/null
