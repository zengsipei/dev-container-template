# Dev Container Template

通用开发容器模板，预装 AI Agents 和常用开发工具，完全隔离于 Windows/WSL 环境。

## 目录结构

```
dev-container-template/
├── .devcontainer/              # 使用模板（最终用户）
│   ├── devcontainer.json       # 主配置
│   ├── compose.yaml            # Docker Compose 配置
│   ├── post-create.sh          # 初始化脚本
│   ├── hapi-up.sh              # HAPI Local Hub 后台拉起脚本
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
- HAPI (`hapi`) - Local Hub，远程访问容器内的 coding agent（见 [HAPI Local Hub](#hapi-local-hub)）

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

## HAPI Local Hub

[HAPI](https://github.com/tiann/hapi)（`@twsxtd/hapi`）让你从手机/浏览器远程访问容器里的 coding agent。本模板把它作为 **Local Hub** 运行：在容器内启动，仅绑定宿主机回环，**模板自身不会把它暴露到 LAN 或公网**。

**工作方式**：
- **Startup Install**：容器创建时通过 `npm install -g @twsxtd/hapi` 安装/更新，始终保持最新（不烘焙进镜像）。
- **Agent Home 持久化**：状态目录 `~/.hapi`（设置、令牌、SQLite、runner 状态、日志）链接到 `dev-home` volume，重建容器不丢失。
- **自动拉起**：hub 在后台监听 `0.0.0.0:3006`（容器内），端口就绪后自动启动 runner。整个过程不阻塞容器创建。
- **Host Tunnel Port**：`compose.yaml` 将端口绑定为 `127.0.0.1:3006:3006`，只有宿主机本机可访问。

**首次使用：配置令牌**

HAPI 需要 `CLI_API_TOKEN` 才能工作。在容器内执行一次（令牌持久化在 `~/.hapi`，重建容器不丢失）：

```bash
hapi auth login        # 交互式输入并保存令牌
hapi doctor            # 诊断 / 查看 hub 与 runner 状态
hapi runner status     # 查看 runner 状态
```

配置令牌后重建容器（或手动运行 `bash .devcontainer/hapi-up.sh`）即可自动拉起。日志位于 `~/.hapi/logs/`（`hub.log`、`runner.log`）。

**公开访问（用户自行决定）**

模板只把 hub 绑定到宿主回环。若需从公网访问，在**宿主机**侧自行配置隧道，例如 Cloudflare Tunnel：

```bash
# 在宿主机（不是容器内）运行，将本机 3006 暴露为一个公网地址
cloudflared tunnel --url http://127.0.0.1:3006
```

> ⚠️ 公开暴露是一次有意的用户操作。请确保已配置好 `CLI_API_TOKEN` 等访问控制后再开启隧道。

详细说明见 [.devcontainer/README.md](.devcontainer/README.md#hapi-local-hub)

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

## 镜像构建与发布

预构建镜像源码在 `devimage-build/` 目录，通过 GitHub Actions 按 Release Tag 契约发布。

发布契约（触发、`:latest` 语义、pin 策略）见 [docs/adr/0001-image-release-contract.md](docs/adr/0001-image-release-contract.md)；维护者发版操作见 [devimage-build/README.md](devimage-build/README.md)。

## 自定义

### 修改工具配置

编辑 `devimage-build/.devcontainer/configs/` 中的配置文件：
- `tmux.conf` - tmux 配置
- `zshrc-addon` - zsh 配置

### 添加新工具

编辑 `devimage-build/.devcontainer/Dockerfile`，添加安装命令。

### 发布镜像

镜像发布遵循 Release Tag 契约——push 一个 `v*` tag 即构建并移动 `:latest`。详见 [发布契约](docs/adr/0001-image-release-contract.md) 与 [devimage-build/README.md](devimage-build/README.md)。本地构建仅供测试，不发布：

```bash
cd devimage-build
devcontainer build --workspace-folder .   # 本地测试，不推送、不动 :latest
```

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
