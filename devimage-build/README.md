# Dev Container 镜像构建

预构建镜像源码，通过 GitHub Actions 自动构建并推送到 Docker Hub。

## 目录结构

```
devimage-build/
└── .devcontainer/
    ├── Dockerfile              # 镜像定义
    ├── devcontainer.json       # Features 配置
    ├── devcontainer-lock.json  # Features 锁定文件
    └── configs/                # 配置文件
        ├── tmux.conf           # tmux 配置
        └── zshrc-addon         # zsh 配置追加内容
```

## 镜像信息

- **镜像名称**：`xiao806852034/ai-dev-container:latest`
- **基础镜像**：`mcr.microsoft.com/devcontainers/base:ubuntu`
- **支持架构**：`linux/amd64`, `linux/arm64`

## 预装内容

### Features（通过 devcontainer.json）

- Node.js LTS + pnpm
- Python 3.12 + Poetry
- Rust
- GitHub CLI
- Docker-in-Docker

### 系统工具（通过 Dockerfile）

- jq
- ripgrep (rg)
- fd-find
- bat
- eza
- htop
- tree
- tmux
- xclip

### 用户配置（通过 Dockerfile）

- Git 配置（避免 Windows 换行符问题）
- tmux 配置 + TPM 插件管理器
- zsh 配置 + 插件（autosuggestions, syntax-highlighting）
- 缓存目录符号链接

## 本地构建

### 前置要求

- Docker
- VS Code + Dev Containers 扩展

### 构建命令

```bash
cd devimage-build
devcontainer build --workspace-folder .
```

### 测试镜像

```bash
# 构建完成后，在 devimage-build 目录中
# VS Code: F1 → Dev Containers: Reopen in Container
```

## 自动构建

### GitHub Actions 工作流

`.github/workflows/build-image.yml` 配置了自动构建：

**触发条件**：
- 推送 tag（格式：`v*`）
- 推送到 main 分支

**构建步骤**：
1. 检出代码
2. 设置 QEMU（多架构支持）
3. 设置 Docker Buildx
4. 登录 Docker Hub
5. 构建并推送镜像

### 配置 GitHub Secrets

在 GitHub 仓库设置中添加：

- `DOCKER_HUB_USERNAME`：Docker Hub 用户名
- `DOCKER_HUB_TOKEN`：Docker Hub Access Token

### 触发构建

**方式一：推送 tag**

```bash
git tag v1.0.0
git push origin v1.0.0
```

**方式二：推送到 main**

```bash
git push origin main
```

## 自定义修改

### 添加系统工具

编辑 `Dockerfile`，在 `apt-get install` 中添加：

```dockerfile
RUN apt-get update && apt-get install -y \
    jq \
    ripgrep \
    fd-find \
    <your-tool> \
    && rm -rf /var/lib/apt/lists/*
```

### 添加 Features

编辑 `devcontainer.json`，在 `features` 中添加：

```json
"features": {
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/devcontainers/features/python:1": {},
    "ghcr.io/devcontainers/extra-features/<feature-name>:1": {}
}
```

### 修改 tmux 配置

编辑 `configs/tmux.conf`：

```bash
# tmux 基础配置
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# 启用鼠标
set -g mouse on

# 修改前缀键为 Ctrl-a
set -g prefix C-a
bind C-a send-prefix

# 分屏快捷键
bind | split-window -h
bind - split-window -v

# 窗口导航
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
```

### 修改 zsh 配置

编辑 `configs/zshrc-addon`：

```bash
# zsh 主题（随机）
ZSH_THEME="random"

# zsh 插件
plugins=(git z sudo zsh-autosuggestions zsh-syntax-highlighting)

# 实用别名
alias ll="eza -la"
alias bat="batcat"
alias cat="bat"
alias find="fd"
alias grep="rg"

# tmux 快捷键
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'
alias tk='tmux kill-session -t'
```

## 缓存持久化策略

### 符号链接映射

镜像构建时创建符号链接，将缓存目录映射到 `~/.cache-volumes/`：

```
~/.cache-volumes/          # dev-cache volume 挂载点
├── npm/                   # → ~/.npm
├── pnpm/                  # → ~/.local/share/pnpm
├── pip/                   # → ~/.cache/pip
├── poetry/                # → ~/.cache/pypoetry
├── vscode-extensions/     # → ~/.vscode-server/extensions
├── tmux/                  # → ~/.tmux
└── zsh/                   # → ~/.zsh
```

### 实现方式

```dockerfile
# 创建缓存目录
RUN mkdir -p ~/.cache-volumes/{npm,pnpm,pip,poetry,vscode-extensions,tmux/plugins,zsh}

# 创建符号链接
RUN ln -sf ~/.cache-volumes/npm ~/.npm \
    && ln -sf ~/.cache-volumes/pnpm ~/.local/share/pnpm \
    && ln -sf ~/.cache-volumes/pip ~/.cache/pip \
    && ln -sf ~/.cache-volumes/poetry ~/.cache/pypoetry \
    && ln -sf ~/.cache-volumes/vscode-extensions ~/.vscode-server/extensions
```

### 优势

- 用户级配置独立于镜像
- 重建容器不会丢失配置
- 单个 volume 便于管理

## 构建优化

### 层合并

将相关操作合并到单个 RUN 指令，减少镜像层数：

```dockerfile
# ✅ 推荐：合并相关操作
RUN apt-get update && apt-get install -y \
    jq \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# ❌ 不推荐：分开执行
RUN apt-get update
RUN apt-get install -y jq
RUN apt-get install -y ripgrep
RUN rm -rf /var/lib/apt/lists/*
```

### 缓存利用

将不常变化的层放在前面：

1. 基础镜像
2. 系统依赖
3. Git 配置
4. 用户切换
5. 缓存目录创建
6. 应用配置

### 多架构支持

使用 Docker Buildx 构建多架构镜像：

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
```

## 常见问题

### Q: 如何更新基础镜像？

修改 `Dockerfile` 第一行：

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04
```

### Q: 如何添加新的缓存目录？

1. 在 Dockerfile 中创建目录：
```dockerfile
RUN mkdir -p ~/.cache-volumes/<name>
```

2. 创建符号链接：
```dockerfile
RUN ln -sf ~/.cache-volumes/<name> ~/.<name>
```

### Q: 如何调试构建错误？

```bash
# 本地构建并查看详细输出
devcontainer build --workspace-folder . --log-level trace

# 进入中间容器调试
docker run -it <image-id> /bin/bash
```

### Q: 如何查看镜像大小？

```bash
docker images xiao806852034/ai-dev-container:latest
```

## 相关文档

- [根目录 README](../README.md) - 项目概述
- [.devcontainer README](../.devcontainer/README.md) - 使用指南
- [GitHub Actions 工作流](../.github/workflows/build-image.yml) - 自动构建配置
