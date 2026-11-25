# distrobox-image-builder

用 GitHub Actions（海外 runner）自动制作 **distrobox 离线镜像包**：拉取 `docker.io` 官方镜像 → 换清华 TUNA 源 → 预装 distrobox-init 依赖、`zh_CN.UTF-8` locale、时区数据、`host-spawn` → 打成 `docker-archive` + zstd 的 `.tar.zst` → 发布到 GitHub Release。

解决的核心问题：国内直接拉 docker.io / ghcr 都很慢，而 Release 资产可以走加速前缀一次性下载；同时把「主机是 `LANG=zh_CN.UTF-8` 的中文桌面」场景下每个新容器都会遇到的启动报错提前消掉。

| 产物 | 基础镜像 | 源 | 额外预装 |
|---|---|---|---|
| `archlinux.tar.zst` | docker.io/archlinux:latest | 清华 TUNA (https) | `glibc-locales`（约 +222 MB 解压后体积） |
| `fedora.tar.zst` | docker.io/fedora:latest | 清华 TUNA (https) | `glibc-langpack-zh` |
| `ubuntu.tar.zst` | docker.io/ubuntu:24.04 | 清华 TUNA (https) | `ca-certificates`、`language-pack-zh-hans`、`tzdata` |

三个包共同预装：`sudo` / `curl` / `lsof` / `xauth`、`zh_CN.UTF-8` locale、`/usr/bin/host-spawn`（约 3.8 MB 静态二进制）。首次进容器无需联网。

## 使用方法

### 1. 触发构建

推到自己的 GitHub 仓库后，两种方式：

- **手动**：Actions 页面 → build-distrobox-images → Run workflow
- **自动**：每月 1 号（UTC 03:00）定时重建，保持 `:latest` 内容新鲜

单次构建：三个发行版并行，单 job 约 10-20 分钟；runner 自带 podman，无需额外配置。

### 2. 下载成品（国内加速）

构建完成后到 Releases 页面，资产可直接下载；国内建议拼 gh-proxy 类加速前缀：

```text
# 原始地址
https://github.com/<你的用户名>/<仓库名>/releases/download/vYYYYMMDD/ubuntu.tar.zst
# 加速地址（前缀替换）
https://gh-proxy.com/https://github.com/<你的用户名>/<仓库名>/releases/download/vYYYYMMDD/ubuntu.tar.zst
```

Actions Artifact 是备份通道（需要登录 GitHub 才能下载），保留 14 天。

### 3. 新机器恢复

新机器需要预装：`podman`、`distrobox`、`zstd`。

```bash
zstd -d ubuntu.tar.zst -o ubuntu.tar
podman load --input ubuntu.tar                      # 镜像入库：localhost/distrobox:ubuntu
distrobox create --name ubuntu --image localhost/distrobox:ubuntu
distrobox enter ubuntu
```

> ⚠️ `distrobox create` **不要加 `--pull`**：镜像只在本地，加了会尝试联网拉取。

可选：恢复成原始镜像名，让旧命令/文档照常用：

```bash
podman tag localhost/distrobox:arch   docker.io/archlinux:latest
podman tag localhost/distrobox:fedora docker.io/fedora:latest
podman tag localhost/distrobox:ubuntu docker.io/ubuntu:24.04
```

### 4. 恢复后仍可能看到的一条报错：powerline-bash.sh

如果主机 `~/.bashrc` 里有无条件的 `source /etc/xdg/powerline-bash.sh`，进容器会报
`bash: /etc/xdg/powerline-bash.sh: No such file or directory`。这是主机上的文件，不属于任何发行版镜像，
所以**不会**打进包里。两种处理，任选其一：

```bash
# 方式 A：在每个容器里拷一份
sudo mkdir -p /etc/xdg && sudo cp /run/host/etc/xdg/powerline-bash.sh /etc/xdg/
```

```bash
# 方式 B（一劳永逸）：改主机 ~/.bashrc，让它自动回落到 /run/host 下的主机副本
for _f in /etc/xdg/powerline-bash.sh /run/host/etc/xdg/powerline-bash.sh; do
  [ -r "$_f" ] && source "$_f" && break
done
unset _f
```

## 实现说明与已知坑

- **配置容器不能用 `podman run --rm`**——改完即丢。工作流用 `run -d --name prep` → `exec` 配置脚本 → `commit`。
- **`podman commit` 兜底**：`podman load` 导入的镜像 + keep-id 容器组合下，commit 可能报
  `history lists N non-empty layers, but we have M layers on disk`。CI 是 registry 直拉的干净镜像通常不触发；
  一旦触发，工作流自动改走 `podman export | podman import` 管线（打平为全新单层镜像）。
- **YAML 陷阱**：步骤名里出现 `: ` 会破坏解析，含冒号的步骤名要加引号（如 `"Commit image (fallback: export | import)"`）。
- **Fedora 45+** 的 repo 文件在 `/usr/share/dnf5/repos.d/`（不再是 `/etc/yum.repos.d/`）；
  `fedora-cisco-openh264.repo` 保持官方 metalink（清华不镜像，体积极小）。
- **Ubuntu 用 https**：先借官方 http 源装 `ca-certificates`，再切清华 https；之后 apt 全走 https。
- **Arch 的 locale**：`glibc-locales` 装的是预编译好的 locale 目录，不含 zh_CN 的源定义。
  不要在 `/etc/locale.gen` 里启用 zh_CN，也不要跑 `locale-gen`，否则报 `cannot open locale definition file zh_CN`。
- **Ubuntu 要装 tzdata**：基础镜像没有它，distrobox 的 apt 事务后钩子会在每次 `apt-get install` 末尾
  打印一条 `mount: /etc/localtime ... does not exist`（有回退分支，纯噪音）。
- **host-spawn 的来源与版本**：distrobox 初始化容器时会自动从 GitHub 下载它
  （`https://github.com/1player/host-spawn/releases/download/v1.6.0/host-spawn-<arch>`），
  失败则静默跳过，之后登录 shell 里 `/etc/profile.d/distrobox_profile.sh` 调用不到就报
  `host-spawn: command not found`。这里改为构建时预装，版本固定 `v1.6.0`（distrobox 1.8.x 的期望值，
  可用 `distrobox-host-exec -V` 查看）。目标机器的 distrobox 若期望更新的版本，会提示重新安装；
  需要改版本时调整 `scripts/install-host-spawn.sh` 里的 `HOST_SPAWN_VERSION`。
  注意：这是第三方二进制，上游 release 未提供校验和，构建时只校验了「下载到非空文件且能执行」。
- 自检链：`zstd -t` → tar 结构含 `manifest.json` → 回灌 `podman load` → 容器内验证
  os-release、源配置、`zh_CN.utf8`、时区数据、`host-spawn --version`。
- 包里**不含任何个人数据**：家目录是 distrobox 运行时挂载的，不在镜像文件系统内。
