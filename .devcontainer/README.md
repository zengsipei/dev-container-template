# Dev Container 最佳实践

这是一个完整的开发容器模板，隔离于 Windows 和 WSL 环境。

## 快速开始

1. 安装 VS Code 扩展：`ms-vscode-remote.remote-containers`
2. 打开此目录
3. 按 `F1` → 输入 `Dev Containers: Reopen in Container`
4. 等待镜像拉取和配置完成（首次约 2-3 分钟）

**使用预构建镜像**：无需本地构建，直接从 Docker Hub 拉取。

## 预装工具

### AI Agents
- **Claude Code** - Anthropic 的 AI 编程助手
- **OpenAI Codex** - OpenAI 的代码生成工具
- **Gemini CLI** - Google Gemini 命令行工具

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

### 缓存与用户配置统一管理

所有缓存和用户级配置存储在单个 named volume `dev-cache` 中，通过符号链接映射：

```
~/.cache-volumes/          # named volume 挂载点
├── npm/                   # → ~/.npm
├── pnpm/                  # → ~/.local/share/pnpm
├── pip/                   # → ~/.cache/pip
├── poetry/                # → ~/.cache/pypoetry
├── vscode-extensions/     # → ~/.vscode-server/extensions
├── tmux/                  # → ~/.tmux（tmux 配置和插件）
└── zsh/                   # → ~/.zsh（zsh 插件）
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

### AI Agent 配置管理

配置存储在 `dev-home` volume 中，并自动链接：

- **Volume 名称**：`dev-home`
- **挂载路径**：`/home/vscode/wsl-home`
- **自动链接**：
  - `~/.claude` → `/home/vscode/wsl-home/.claude`
  - `~/.codex` → `/home/vscode/wsl-home/.codex`
  - `~/.gemini` → `/home/vscode/wsl-home/.gemini`

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

### tmux 使用（推荐）

使用 tmux 在多个 AI agent 间切换：

```bash
# 创建新会话
tn claude

# 在会话中运行 claude
claude

# 分屏并运行 codex
Ctrl-a %          # 垂直分屏
codex             # 在新窗格运行

# 切换窗格
Ctrl-a <方向键>

# 分离会话
Ctrl-a d

# 重新连接
ta claude

# 列出所有会话
tl
```

**推荐工作流**：
1. 创建 `tn ai` 会话
2. 分成三个窗格，分别运行 claude、codex、gemini
3. 使用 `Ctrl-a d` 分离，`ta ai` 重新连接

**配置持久化**：
- tmux 配置文件：`~/.tmux.conf`
- tmux 插件目录：`~/.tmux/plugins/`
- 以上配置存储在 `dev-cache` volume 中，重建容器不会丢失

**自定义配置**：
```bash
# 编辑配置文件
vim ~/.tmux.conf

# 安装新插件（在 tmux 会话中）
Ctrl-a I         # 按 Ctrl-a 然后按大写 I
```

## 工作目录说明

### 项目挂载位置

VS Code Dev Containers 会自动将项目目录挂载到容器内：

- **挂载位置**：`/workspaces/<project-name>`
- **工作目录**：自动设置为挂载位置

**示例**：
- 打开 `C:\Users\<username>\projects\my-app`
- 容器内挂载到：`/workspaces/my-app`
- 工作目录自动设置为：`/workspaces/my-app`

### 用户主目录

`/home/vscode` 是用户主目录，用于存放：

- 配置文件（`.zshrc`、`.gitconfig` 等）
- 缓存目录（`.npm`、`.cache` 等）
- AI agent 配置链接（`.claude`、`.codex`、`.gemini`）

**与项目目录的关系**：
- 项目代码：`/workspaces/<project-name>`（自动挂载）
- 用户配置：`/home/vscode`（持久化）
- 两者独立，互不影响

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
└── README.md           # 本文件
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

编辑 `devimage-build/Dockerfile` 和 `devimage-build/devcontainer.json`，然后重新构建镜像。

**方式二：在项目中添加**

编辑 `devimage-build/on-create.sh`，添加安装命令。

### 修改资源限制

编辑 `devcontainer.json`：

```json
"runArgs": [
  "--memory=16g",    // 内存限制
  "--cpus=8"         // CPU 核心数
]
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

所有缓存统一存储在 `dev-cache` named volume 中：

```
dev-cache/
├── npm/              # npm 缓存
├── pnpm/             # pnpm store
├── pip/              # pip 缓存
├── poetry/           # Poetry 缓存
└── vscode-extensions/ # VS Code 扩展
```

其他持久化数据：
- 项目代码
- AI agent 配置（从 WSL 挂载）

**优势**：
- 单个 named volume，便于管理
- 重建容器不会丢失缓存
- 可通过 `docker volume inspect dev-cache` 查看位置

### Q: WSL home 挂载失败？

检查以下几点：

1. **确认 WSL_HOME 环境变量已设置**：
   ```powershell
   echo $env:WSL_HOME
   ```

2. **确认 WSL 正在运行**：
   ```powershell
   wsl --list --verbose
   ```

3. **确认路径正确**：
   ```powershell
   # 测试路径是否存在
   Test-Path $env:WSL_HOME
   ```

如果路径不存在，检查 WSL 发行版名称是否为 `Ubuntu`。

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
