# Dev Container Template

通用开发容器模板，预装 AI Agents 和常用开发工具。

## 使用方法

### 1. 启动容器

1. 用 VS Code 打开此目录
2. 安装扩展：`ms-vscode-remote.remote-containers`
3. 按 `F1` → `Dev Containers: Reopen in Container`
4. 等待构建完成

**注意**：现在无需任何配置即可启动容器。

### 2. 可选：绑定现有配置

如果你在 WSL 中已有 AI agent 配置，可以在首次启动前设置 `WSL_HOME` 环境变量：

**在 WSL 中使用**（推荐）：

```bash
# 创建 .env 文件
echo "WSL_HOME=~" > .env
```

**在 Windows 中使用**：

```powershell
# 永久设置
[Environment]::SetEnvironmentVariable("WSL_HOME", "\\wsl.localhost\Ubuntu\home\dev", "User")

# 或临时设置
$env:WSL_HOME = "\\wsl.localhost\Ubuntu\home\dev"
```

**注意**：`WSL_HOME` 仅在首次启动时生效。volume 创建后，类型不会改变。

## 预装工具

### AI Agents
- Claude Code (`claude`)
- OpenAI Codex (`codex`)
- Gemini CLI (`gemini`)

### 开发环境（通过 Features）
- Node.js LTS + pnpm
- Python 3.12 + Poetry
- Rust
- Git + GitHub CLI
- zsh + Oh My Zsh

### CLI 工具
- ripgrep (rg)
- fd
- bat
- exa
- jq
- tmux

## 配置管理

配置存储在 `dev-home` volume 中，并自动链接：

- `~/.claude` ← `/home/dev/wsl-home/.claude`
- `~/.codex` ← `/home/dev/wsl-home/.codex`
- `~/.gemini` ← `/home/dev/wsl-home/.gemini`

**Volume 类型**（首次创建时决定）：
- **有 `WSL_HOME`**：bind mount，直接使用 WSL_HOME 目录
- **无 `WSL_HOME`**：普通 named volume，数据存储在 Docker 管理的区域

**切换类型**：删除 volume 后重启 `docker volume rm dev-home`

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
