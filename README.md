# Dev Container Template

通用开发容器模板，预装 AI Agents 和常用开发工具。

## 使用方法

### 1. 启动容器

1. 用 VS Code 打开此目录
2. 安装扩展：`ms-vscode-remote.remote-containers`
3. 按 `F1` → `Dev Containers: Reopen in Container`
4. 等待构建完成

**注意**：无需任何配置即可启动容器。

### 2. 可选：绑定 WSL 中的现有配置

如果你在 WSL 中已有 AI agent 配置（`.claude`、`.codex`、`.gemini`），可以绑定它们：

**首次启动前执行**：

```bash
# 在项目根目录创建 .env 文件
echo "WSL_HOME=~" > .env
```

**说明**：
- `initialize.sh` 会读取 `.env` 文件中的 `WSL_HOME`
- 如果 `WSL_HOME` 存在且目录有效，创建 bind mount volume
- 如果不设置，创建普通 named volume（数据在 Docker 管理区域）
- volume 创建后类型不会改变，切换需删除：`docker volume rm dev-home`

## 预装工具

### AI Agents
- Claude Code (`claude`)
- OpenAI Codex (`codex`)
- Gemini CLI (`gemini`)

### 开发环境（通过 Features）
- Node.js LTS + pnpm
- Python 3.12 + Poetry
- Rust
- GitHub CLI
- zsh + Oh My Zsh

### CLI 工具
- ripgrep (rg)
- fd
- bat
- eza
- jq
- tmux

## 配置管理

配置存储在 Docker volumes 中：

**dev-home volume**：
- 默认：普通 named volume
- 可选：bind mount 到 WSL home 目录
- 用途：AI agent 配置（`.claude`、`.codex`、`.gemini`）

**dev-cache volume**：
- 统一缓存存储（npm、pnpm、pip、poetry、VS Code 扩展）
- 自动管理，无需手动干预

## 工作目录

项目目录挂载到 `/home/vscode/<project-name>`，例如：
- 打开 `/home/<username>/code/my-app`
- 容器内挂载到：`/home/vscode/my-app`

## tmux 工作流

推荐使用 tmux 同时运行多个 AI agent：

```bash
tn ai              # 创建会话
Ctrl-a %           # 分屏
claude / codex / gemini  # 在各窗格运行
Ctrl-a d           # 分离会话
ta ai              # 重新连接
```

详细说明见 [.devcontainer/README.md](.devcontainer/README.md)
