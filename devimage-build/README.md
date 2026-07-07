# Dev Container 镜像构建

预构建镜像源码，通过 GitHub Actions 自动构建并推送到 Docker Hub。

> 本文档面向模板维护者，是**镜像内容与发布**的单一所有者。使用容器见 [.devcontainer/README.md](../.devcontainer/README.md)，项目概览见[根 README](../README.md)。

## 目录结构

```
devimage-build/
└── .devcontainer/
    ├── Dockerfile              # 镜像定义
    ├── devcontainer.json       # Features 配置
    └── devcontainer-lock.json  # Features 锁定文件
```

## 镜像信息

- **镜像名称**：`xiao806852034/ai-dev-container:latest`
- **基础镜像**：`debian:trixie-slim`
- **支持架构**：`linux/amd64`, `linux/arm64`

## 预装内容

### Features（通过 devcontainer.json）

- Node.js LTS + pnpm / yarn
- Python 3.13（os-provided）+ pipx
- Rust
- GitHub CLI
- Docker-in-Docker

### 系统工具（通过 Dockerfile）

镜像走 **agent-first** 基线（见 [ADR 0002](../docs/adr/0002-agent-first-baseline.md)）：只烘焙 AI Agent Toolchain 与 Human Supervisor debug 双方都需要的工具。基础镜像用**裸 `debian:trixie-slim`** 而非 `devcontainers/base:*`——后者预烘焙了 common-utils 默认配置，自带 zsh / oh-my-zsh 等交互工效层。devcontainer 必需品（非 root 用户、sudo、locale 等）由 Dockerfile 自建 `vscode` 用户 + `common-utils` Feature（`installZsh: false`）补齐；`tmux` / `bat` / `eza` / `xclip`、zsh 插件与 tmux 配置均不安装（`htop` / `tree` 随 common-utils 基础包进入，算 debug 工具的 keep 侧，不视为泄漏）。基线由 CI 把关：`.github/workflows/image-build-check.yml` 在 PR 上构建镜像并断言上述工具的存在/缺席。

- jq
- ripgrep (rg)
- fd-find（以 `fd` 暴露：`fdfind` 在 `PATH` 上符号链接为 `fd`）

### 用户配置（通过 Dockerfile）

- Git 配置（避免 Windows 换行符问题）
- 包管理器缓存目录符号链接（npm / pnpm / pip / poetry / vscode-extensions）

> 默认登录 shell 为 `bash`（Dockerfile `useradd --shell /bin/bash` 创建 `vscode` 用户）：`common-utils` Feature 设 `installZsh: false` / `installOhMyZsh: false` 且不 `configureZshAsDefaultShell`。Human Supervisor 进容器即得到可用的 `bash`；模板侧终端 profile（`.devcontainer/devcontainer.json`）同样默认 `bash`。

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

## 发布（Release）

> 本节是 Prebuilt Image 发布的**维护者向单一散文所有者**。持久决策与 why 见
> [docs/adr/0001-image-release-contract.md](../docs/adr/0001-image-release-contract.md)；
> 机制的可执行真相是 [`.github/workflows/build-image.yml`](../.github/workflows/build-image.yml)。
> 其它文档只链接到这里，不复述发布事实。

### 契约速览

- **Release Trigger**：镜像只由两种事件发布——push 一个 `v*` **Release Tag**，或一次指名已存在 tag 的 **Manual Rebuild**（`workflow_dispatch`）。**排除** main 分支 push。
- **Latest Pointer**：`:latest` ＝ 最近一个 Release Tag 的别名；**只有 Release Tag push 会移动它**，Manual Rebuild 不会。
- **慢变基线**：镜像只烘焙慢变内容；AI Agent Toolchain 走 Startup Install（容器创建时装），不进镜像。所以发布是低频、有意为之的动作。

### 前置配置

在 GitHub 仓库 **Settings → Secrets and variables → Actions** 配置：

| 类型 | 名称 | 必需 | 说明 |
|------|------|------|------|
| Secret | `DOCKER_HUB_TOKEN` | 是 | Docker Hub Access Token（必须是 secret） |
| Variable | `DOCKERHUB_USERNAME` | 否 | 不设则用默认 `xiao806852034`；fork 发到自己 registry 时设置 |
| Variable | `IMAGE_NAME` | 否 | 不设则用默认 `ai-dev-container` |

### 发布新版本（会移动 :latest）

```bash
git tag v1.0.0
git push origin v1.0.0
```

push 后 workflow 构建多架构 `:(v1.0.0)` 并把 `:latest` 指向它。

### Manual Rebuild（重建已存在版本，不动 :latest）

GitHub **Actions → Build and Push Docker Image → Run workflow**，在 `tag` 输入框填一个已存在的 Release Tag（如 `v1.0.0`）。用于重跑失败的发布构建；**不**新建版本、**不**移动 `:latest`（从分支误触发分支构建的漏洞已就此堵死）。

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

## 缓存持久化策略

### 符号链接映射

镜像构建时创建符号链接，将缓存目录映射到 `~/.cache-volumes/`：

```
~/.cache-volumes/          # dev-cache volume 挂载点
├── npm/                   # → ~/.npm
├── pnpm/                  # → ~/.local/share/pnpm
├── pip/                   # → ~/.cache/pip
├── poetry/                # → ~/.cache/pypoetry
└── vscode-extensions/     # → ~/.vscode-server/extensions
```

### 实现方式

```dockerfile
# 创建缓存目录
RUN mkdir -p ~/.cache-volumes/{npm,pnpm,pip,poetry,vscode-extensions}

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

QEMU + Docker Buildx 提供多架构能力，实际构建与推送由 devcontainer CLI 完成（详见 workflow）：

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push the Release Tag image
  run: |
    npm install -g @devcontainers/cli
    devcontainer build \
      --workspace-folder ./devimage-build \
      --image-name "$DOCKERHUB_USERNAME/$IMAGE_NAME:$VERSION" \
      --platform linux/amd64,linux/arm64 \
      --push
```

## 常见问题

### Q: 如何更新基础镜像？

修改 `Dockerfile` 第一行：

```dockerfile
FROM debian:trixie-slim
```

> 注意保持裸发行版镜像：换成 `devcontainers/base:*` 会重新引入预烘焙的 zsh / oh-my-zsh 等工效层，违背 ADR 0002 的 agent-first 基线。

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
