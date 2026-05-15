# Dev Container Template

通用开发容器模板，预装 AI Agents 和常用开发工具，完全隔离于 Windows/WSL 环境。

## 目录结构

```
dev-container-template/
├── .devcontainer/              # 使用模板（最终用户）
│   ├── devcontainer.json       # 主配置
│   ├── compose.yaml            # Docker Compose 配置
│   ├── post-create.sh          # 初始化脚本
│   ├── .env.example            # 环境变量示例
│   └── README.md               # 详细使用文档
│
├── devimage-build/             # 镜像构建源码
│   └── .devcontainer/
│       ├── Dockerfile          # 镜像定义
│       ├── devcontainer.json   # Features 配置
│       └── configs/            # 配置文件
│           ├── tmux.conf
│           └── zshrc-addon
│
└── .github/
    └── workflows/
        └── build-image.yml     # 自动构建镜像
```

## 快速开始

### 1. 启动容器

1. 用 VS Code 打开此目录
2. 安装扩展：`ms-vscode-remote.remote-containers`
3. 按 `F1` → `Dev Containers: Reopen in Container`
4. 等待镜像拉取完成（首次约 1-2 分钟）

**使用预构建镜像**：无需本地构建，直接从 Docker Hub 拉取 `xiao806852034/ai-dev-container:latest`

### 2. 可选：绑定 WSL 中的 AI Agent 配置

如果你在 WSL 中已有 AI agent 配置，可以绑定它们：

```bash
# 复制示例文件
cp .devcontainer/.env.example .devcontainer/.env

# 编辑 .env 文件
WSL_HOME=/home/<username>
```

**说明**：
- 有 `WSL_HOME`：bind mount 到指定目录（直接访问 WSL 文件）
- 无 `WSL_HOME`：使用 named volume（数据在 Docker 管理区域）

## 预装工具

### AI Agents
- Claude Code (`claude`)
- OpenAI Codex (`codex`)
- Gemini CLI (`gemini`)

### 开发环境
- Node.js LTS + pnpm
- Python 3.12 + Poetry
- Rust
- GitHub CLI
- zsh + Oh My Zsh

### CLI 工具
- ripgrep (rg) - 快速搜索
- fd - 现代 find 替代
- bat - 带语法高亮的 cat
- eza - 现代 ls 替代
- jq - JSON 处理
- tmux - 终端复用器

## 配置管理

### dev-cache Volume

所有缓存和用户配置存储在单个 named volume 中：

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

**优势**：
- 重建容器不会丢失缓存和配置
- 单个 volume 便于管理
- 减少磁盘碎片

### dev-home Volume

AI agent 配置存储位置：

- **有 `WSL_HOME`**：bind mount 到 WSL 目录
- **无 `WSL_HOME`**：普通 named volume

## tmux 工作流

推荐使用 tmux 同时运行多个 AI agent：

```bash
tn ai              # 创建会话
Ctrl-a |           # 垂直分屏
Ctrl-a -           # 水平分屏
claude / codex / gemini  # 在各窗格运行
Ctrl-a h/j/k/l     # 切换窗格（左/下/上/右）
Ctrl-a d           # 分离会话
ta ai              # 重新连接
```

详细说明见 [.devcontainer/README.md](.devcontainer/README.md)

## 镜像构建

预构建镜像源码在 `devimage-build/` 目录，通过 GitHub Actions 自动构建。

详细说明见 [devimage-build/README.md](devimage-build/README.md)

## 自定义

### 修改工具配置

编辑 `devimage-build/.devcontainer/configs/` 中的配置文件：
- `tmux.conf` - tmux 配置
- `zshrc-addon` - zsh 配置

### 添加新工具

编辑 `devimage-build/.devcontainer/Dockerfile`，添加安装命令。

### 重新构建镜像

```bash
cd devimage-build
devcontainer build --workspace-folder .
docker tag <image-id> xiao806852034/ai-dev-container:latest
docker push xiao806852034/ai-dev-container:latest
```

或推送 tag 到 GitHub，自动触发构建。

## 常见问题

### Q: 脚本报错 `$'\r': command not found`？

Windows CRLF 行尾问题。已在 `.gitattributes` 中配置强制 LF：

```bash
git add .gitattributes
git rm --cached -r .
git reset --hard
```

### Q: 如何更新工具？

重建容器：`F1` → `Dev Containers: Rebuild Container`

### Q: 如何清理缓存？

```bash
docker volume rm dev-cache
```

## 隔离说明

此容器完全独立于：
- Windows 环境
- WSL 发行版
- 其他 Docker 容器

不会污染宿主机环境，不受宿主机软件版本影响。
