# Dev Container 使用指南

完整的开发容器使用文档。

## 快速开始

1. 安装 VS Code 扩展：`ms-vscode-remote.remote-containers`
2. 打开项目目录
3. 按 `F1` → `Dev Containers: Reopen in Container`
4. 等待镜像拉取完成（首次约 1-2 分钟）

**使用预构建镜像**：无需本地构建，直接从 Docker Hub 拉取。

## 预装工具

### AI Agents
- **Claude Code** - Anthropic 的 AI 编程助手
- **OpenAI Codex** - OpenAI 的代码生成工具
- **Gemini CLI** - Google Gemini 命令行工具
- **HAPI** - Local Hub，远程访问容器内的 coding agent（见 [HAPI Local Hub](#hapi-local-hub)）

### 开发环境
- Node.js LTS + pnpm
- Python 3.12 + Poetry
- Rust
- Git + GitHub CLI
- zsh + Oh My Zsh

### CLI 工具
- `ripgrep` (rg) - 快速搜索
- `fd` - 现代 find 替代
- `bat` - 带语法高亮的 cat
- `eza` - 现代 ls 替代
- `jq` - JSON 处理
- `tmux` - 终端复用器

## 环境变量配置

### 可选：设置 WSL_HOME

**重要**：`WSL_HOME` 是可选的。即使不设置，容器也能正常启动。

**设置方式**：在 `.devcontainer/.env` 文件中设置

```bash
# 复制示例文件
cp .devcontainer/.env.example .devcontainer/.env

# 编辑 .env 文件
WSL_HOME=/home/<username>
```

**工作原理**：
- **有 WSL_HOME**：bind mount 到指定目录（直接访问 WSL 文件）
- **无 WSL_HOME**：使用 named volume（数据在 Docker 管理区域）
- compose.yaml 会自动处理，无需手动创建 volume

## 配置管理

### dev-cache Volume

所有缓存和用户配置存储在单个 named volume `dev-cache` 中：

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
- 单个 volume 便于管理和备份
- 重建容器不会丢失缓存和配置
- 减少磁盘碎片
- 用户级配置独立于镜像，可自定义

**管理命令**：
```bash
# 查看缓存大小
docker volume inspect dev-cache

# 清理缓存（删除 volume）
docker volume rm dev-cache

# 备份缓存
docker run --rm -v dev-cache:/data -v $(pwd):/backup alpine tar czf /backup/dev-cache.tar.gz /data
```

### dev-home Volume

AI agent 配置存储位置：

- **Volume 名称**：`dev-home`
- **挂载路径**：`/home/vscode/wsl-home`
- **自动链接**：
  - `~/.claude` → `/home/vscode/wsl-home/.claude`
  - `~/.codex` → `/home/vscode/wsl-home/.codex`
  - `~/.gemini` → `/home/vscode/wsl-home/.gemini`
  - `~/.hapi` → `/home/vscode/wsl-home/.hapi`（HAPI 状态目录，见下文）

**Volume 类型**（首次创建时决定）：
- **有 `WSL_HOME`**：bind mount，直接使用 WSL_HOME 目录
  - 修改会同步到 WSL
  - 适合已有配置的用户
- **无 `WSL_HOME`**：普通 named volume
  - 数据存储在 Docker 管理的区域
  - 适合从零开始的用户

**切换类型**：
```bash
# 删除 volume
docker volume rm dev-home

# 重启容器，会根据当前 WSL_HOME 重新创建
```

## HAPI Local Hub

[HAPI](https://github.com/tiann/hapi)（npm 包 `@twsxtd/hapi`）是一个让你从手机或浏览器远程访问 coding agent 的工具。本模板把它作为 **Local Hub** 运行：进程在容器内启动，可从宿主机本机访问，但**模板自身不会把它发布到 LAN 或公网**——公开访问是用户的一次有意操作。

### 行为概览

| 方面 | 做法 |
|------|------|
| 安装方式 | **Startup Install**：`post-create.sh` 里 `npm install -g @twsxtd/hapi --registry=https://registry.npmjs.org`，每次创建容器都安装/更新，保持最新（不烘焙进镜像） |
| 状态持久化 | `~/.hapi` 链接到 `dev-home` volume 的 `.hapi` 目录，与 `.claude`/`.codex`/`.gemini` 一致 |
| hub 启动 | 后台监听 `0.0.0.0:3006`（容器内全接口，便于 Docker 端口映射） |
| runner 启动 | hub 端口就绪后自动启动 runner，工作目录为 `/home/vscode/workspace` |
| 宿主映射 | `compose.yaml`：`127.0.0.1:3006:3006`（Host Tunnel Port，仅本机回环） |
| 端口转发 | `devcontainer.json` 的 `forwardPorts` 含 `3006` |
| 日志 | `~/.hapi/logs/hub.log`、`~/.hapi/logs/runner.log` |

### 启动流程

容器创建时，`post-create.sh`：

1. `mkdir -p /home/vscode/wsl-home/.hapi` 并 `ln -sfn ... ~/.hapi`（持久化）
2. 安装/更新 HAPI
3. 后台调用 `.devcontainer/hapi-up.sh`（不阻塞容器创建）

`hapi-up.sh` 负责实际拉起，且**幂等**：

- hub：先用 `/dev/tcp` 探测 3006 端口，已被占用则跳过启动
- runner：`hapi runner start` 会先停掉已有 runner 再启动（内置锁文件），重复运行不会产生重复进程

可手动重新拉起：

```bash
bash .devcontainer/hapi-up.sh
```

### 首次使用：配置令牌

HAPI 需要 `CLI_API_TOKEN` 才能正常工作。在容器内执行一次即可（令牌保存在 `~/.hapi`，已持久化，重建容器不丢失）：

```bash
hapi auth login        # 交互式输入并保存令牌
hapi auth status       # 查看认证状态
hapi doctor            # 系统诊断
hapi runner status     # 查看 runner 状态
```

未配置令牌时 hub 可能直接退出，启动脚本仍保持非阻塞，相关信息写入 `~/.hapi/logs/hub.log`。配置好令牌后重建容器或重新运行 `hapi-up.sh` 即可。

### 自定义

通过环境变量调整（在调用 `hapi-up.sh` 前设置）：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HAPI_LISTEN_HOST` | `0.0.0.0` | hub 在容器内监听的接口 |
| `HAPI_LISTEN_PORT` | `3006` | hub 端口（同时需同步 `compose.yaml` 与 `forwardPorts`） |
| `HAPI_WORKSPACE_ROOT` | `~/workspace` | runner 创建新会话的工作目录 |

### 公开访问：宿主侧 Cloudflare Tunnel

模板只把 hub 绑定到 `127.0.0.1:3006`。若要从公网访问，在**宿主机**（不是容器内）自行配置隧道。以 Cloudflare Tunnel 为例：

```bash
# 快速试用（临时随机域名）
cloudflared tunnel --url http://127.0.0.1:3006

# 或绑定到自有域名的命名隧道
cloudflared tunnel create hapi
cloudflared tunnel route dns hapi hapi.example.com
cloudflared tunnel run --url http://127.0.0.1:3006 hapi
```

> ⚠️ 公开暴露是一次有意的用户操作，不在模板职责范围内。开启隧道前请确认已配置 `CLI_API_TOKEN` 等访问控制。

## tmux 使用指南

使用 tmux 在多个 AI agent 间切换：

### 基本操作

```bash
# 创建新会话
tn ai

# 在会话中运行 claude
claude

# 分屏并运行 codex
Ctrl-a |          # 垂直分屏
codex             # 在新窗格运行

# 切换窗格
Ctrl-a h/j/k/l    # 左/下/上/右

# 分离会话
Ctrl-a d

# 重新连接
ta ai

# 列出所有会话
tl
```

### 推荐工作流

1. 创建 `tn ai` 会话
2. 分成三个窗格，分别运行 claude、codex、gemini
3. 使用 `Ctrl-a d` 分离，`ta ai` 重新连接

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl-a \|` | 垂直分屏 |
| `Ctrl-a -` | 水平分屏 |
| `Ctrl-a h` | 切换到左侧窗格 |
| `Ctrl-a j` | 切换到下方窗格 |
| `Ctrl-a k` | 切换到上方窗格 |
| `Ctrl-a l` | 切换到右侧窗格 |
| `Ctrl-a d` | 分离会话 |
| `Ctrl-a c` | 创建新窗口 |
| `Ctrl-a n/p` | 切换窗口 |

### 配置持久化

- tmux 配置文件：`~/.tmux.conf` → `~/.cache-volumes/tmux/.tmux.conf`
- tmux 插件目录：`~/.tmux/plugins/` → `~/.cache-volumes/tmux/plugins/`
- 以上配置存储在 `dev-cache` volume 中，重建容器不会丢失

### 自定义配置

修改 `devimage-build/.devcontainer/configs/tmux.conf` 后重新构建镜像：

```bash
cd devimage-build
devcontainer build --workspace-folder .
```

或在容器内临时修改（重建容器会重置）：

```bash
vim ~/.tmux.conf
```

## 工作目录说明

### 项目挂载位置

项目目录通过 `compose.yaml` 手动配置挂载：

- **挂载位置**：`/home/vscode/workspace`
- **配置方式**：`compose.yaml` 中的 `..:/home/vscode/workspace`

**说明**：
- `..` 表示项目根目录（`.devcontainer` 的上级目录）
- 所有项目文件在容器内可通过 `/home/vscode/workspace` 访问

### 用户主目录

`/home/vscode` 是用户主目录，包含：

**持久化内容**（通过 dev-cache volume）：
- 缓存目录（`.npm`、`.cache/pip` 等）
- tmux 配置和插件（`~/.tmux`）
- zsh 插件（`~/.zsh`）
- VS Code 扩展（`~/.vscode-server/extensions`）

**非持久化内容**（重建容器会重置）：
- `.zshrc`（由镜像提供默认配置）
- `.gitconfig`（由镜像提供默认配置）
- 其他用户配置文件

**AI agent 配置**：
- 通过符号链接从 `wsl-home` 目录链接
- 持久化在 `dev-home` volume 或 WSL 目录中

## 端口转发说明

### 重要：修改端口不需要重构镜像

`forwardPorts` 配置变更**不会触发镜像重建**，只会重启容器。

**原理**：
- 镜像构建：只执行 Dockerfile 和 Features
- 容器启动：读取 devcontainer.json 的运行时配置

**修改端口后**：
1. VS Code 检测到 devcontainer.json 变化
2. 自动重启容器（几秒钟）
3. 新端口立即生效

**需要重构镜像的情况**：
- 修改 Dockerfile
- 添加/删除 Features
- 修改系统包（apt-get）
- 修改全局 npm 包

## 目录结构

```
.devcontainer/
├── devcontainer.json    # 主配置（运行时配置）
├── compose.yaml         # Docker Compose 配置
├── post-create.sh       # 初始化脚本（容器首次创建时执行）
├── hapi-up.sh           # HAPI Local Hub 后台拉起脚本（由 post-create.sh 调用）
├── .env.example         # 环境变量示例
└── README.md            # 本文件
```

## 预构建镜像

此项目使用预构建镜像 `xiao806852034/ai-dev-container:latest`，包含所有工具和配置。

**镜像构建源码**：见 `devimage-build/` 目录

**优势**：
- 无需本地构建，启动速度快
- 多项目复用同一镜像
- 统一的开发环境

**更新镜像**：
```bash
# 拉取最新镜像
docker pull xiao806852034/ai-dev-container:latest

# 重建容器
# VS Code: F1 → Dev Containers: Rebuild Container
```

## 自定义配置

### 添加新工具

**方式一：修改预构建镜像**（推荐）

编辑 `devimage-build/Dockerfile`，然后重新构建镜像。

**方式二：在项目中添加**

编辑 `.devcontainer/post-create.sh`，添加安装命令。

### 修改资源限制

编辑 `compose.yaml`：

```yaml
services:
  devcontainer:
    deploy:
      resources:
        limits:
          memory: 16G    # 内存限制
        reservations:
          memory: 8G     # 内存预留
```

### 添加端口转发

```json
"forwardPorts": [3000, 8080, 5173, 9000]
```

修改后容器会自动重启，无需重构镜像。

## 常见问题

### Q: 脚本报错 `$'\r': command not found`？

这是 Windows CRLF 行尾问题。已在 `.gitattributes` 中配置强制 LF，但首次克隆后需要重新规范化：

```bash
# 在 WSL 中执行
cd /path/to/dev-container-template
git add .gitattributes
git rm --cached -r .
git reset --hard
```

或重新克隆仓库：

```bash
git clone https://github.com/zengsipei/dev-container-template.git
```

### Q: 文件权限问题？

容器内使用 UID 1000，确保宿主机项目目录权限匹配：
```bash
# Windows 上通常无需处理
# Linux/Mac 上：
sudo chown -R 1000:1000 your-project/
```

### Q: 性能慢？

1. 使用 named volume 存储缓存（已配置）
2. Docker Desktop 设置中使用 WSL2 后端
3. 排除项目目录的 Windows Defender 扫描

### Q: 如何更新工具？

重建容器：`F1` → `Dev Containers: Rebuild Container`

### Q: 如何保留数据？

**持久化数据**：

1. **项目代码**：存储在宿主机，不受容器影响
2. **缓存和插件**：存储在 `dev-cache` volume
3. **AI agent 配置**：存储在 `dev-home` volume 或 WSL 目录（取决于 WSL_HOME 配置）

**非持久化数据**（重建容器会重置）：
- `.zshrc`、`.gitconfig` 等用户配置文件
- 这些文件由镜像提供默认配置

**管理缓存**：
```bash
# 查看缓存大小
docker volume inspect dev-cache

# 清理缓存
docker volume rm dev-cache

# 清理 AI agent 配置
docker volume rm dev-home
```

### Q: WSL home 挂载失败？

检查以下几点：

1. **确认 .env 文件已创建**：
   ```bash
   ls .devcontainer/.env
   ```

2. **确认 WSL_HOME 已设置**：
   ```bash
   cat .devcontainer/.env
   ```

3. **确认 WSL 正在运行**：
   ```bash
   wsl --list --verbose
   ```

4. **确认路径正确**：
   ```bash
   # 在 WSL 中测试路径是否存在
   ls /home/<username>
   ```

如果路径不存在，检查 WSL 中的用户名是否正确。

## 隔离说明

此容器完全独立于：
- Windows 环境
- WSL 发行版
- 其他 Docker 容器

不会：
- 污染宿主机环境
- 受宿主机软件版本影响
- 与其他项目依赖冲突

## 团队协作

将 `.devcontainer/` 目录提交到 Git，团队成员可一键获得相同开发环境。

```bash
git add .devcontainer/
git commit -m "Add dev container configuration"
```
