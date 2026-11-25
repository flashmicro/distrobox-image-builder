# distrobox-image-builder

用 GitHub Actions（海外 runner）自动制作 **distrobox 离线镜像包**：拉取 `docker.io` 官方镜像 → 换清华 TUNA 源 → 预装 distrobox-init 依赖（`sudo`/`curl`/`lsof`/`xauth`）→ 打成 `docker-archive` + zstd 的 `.tar.zst` → 发布到 GitHub Release。

解决的核心问题：国内直接拉 docker.io / ghcr 都很慢，而 Release 资产可以走加速前缀一次性下载。

| 产物 | 基础镜像 | 预期包体 | 源 |
|---|---|---|---|
| `archlinux.tar.zst` | docker.io/archlinux:latest | ~130-160 MB | 清华 TUNA (https) |
| `fedora.tar.zst` | docker.io/fedora:latest | ~70-150 MB | 清华 TUNA (https) |
| `ubuntu.tar.zst` | docker.io/ubuntu:24.04 | ~60-110 MB | 清华 TUNA (https) |

三个包均已预装 distrobox-init 所需依赖，**首次进容器无需联网**。

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

## 实现说明与已知坑

- **配置容器不能用 `podman run --rm`**——改完即丢。工作流用 `run -d --name prep` → `exec` 配置脚本 → `commit`。
- **`podman commit` 兜底**：`podman load` 导入的镜像 + keep-id 容器组合下，commit 可能报
  `history lists N non-empty layers, but we have M layers on disk`。CI 是 registry 直拉的干净镜像通常不触发；
  一旦触发，工作流自动改走 `podman export | podman import` 管线（打平为全新单层镜像）。
- **Fedora 45+** 的 repo 文件在 `/usr/share/dnf5/repos.d/`（不再是 `/etc/yum.repos.d/`）；
  `fedora-cisco-openh264.repo` 保持官方 metalink（清华不镜像，体积极小）。
- **Ubuntu 用 https**：先借官方 http 源装 `ca-certificates`，再切清华 https；之后 apt 全走 https。
- 自检链：`zstd -t` → tar 结构含 `manifest.json` → 回灌 `podman load` → 容器内验证 os-release 与源配置。
- 包里**不含任何个人数据**：家目录是 distrobox 运行时挂载的，不在镜像文件系统内。
