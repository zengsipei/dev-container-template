#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

# ============================================
# 设置缓存目录（统一 named volume）
# ============================================
echo "📦 Setting up cache directories..."

# 使用 sudo 创建缓存子目录，并修改所有者为 vscode
# 原因：dev-cache 在无目录时，会以 root 挂载
sudo mkdir -p ~/.cache-volumes/{npm,pnpm,pip,poetry,vscode-extensions,tmux,zsh}
sudo chown -R vscode:vscode ~/.cache-volumes

# 创建符号链接的父目录
mkdir -p ~/.local/share/pnpm
mkdir -p ~/.cache/pip
mkdir -p ~/.cache/pypoetry
mkdir -p ~/.vscode-server/extensions

# 创建符号链接（缓存目录）
ln -sf ~/.cache-volumes/npm ~/.npm
ln -sf ~/.cache-volumes/pnpm ~/.local/share/pnpm
ln -sf ~/.cache-volumes/pip ~/.cache/pip
ln -sf ~/.cache-volumes/poetry ~/.cache/pypoetry
ln -sf ~/.cache-volumes/vscode-extensions ~/.vscode-server/extensions

echo "✅ Cache directories configured"

# ============================================
# 配置 tmux（持久化到 dev-cache）
# ============================================
echo "📦 Setting up tmux configuration..."

# 链接 tmux 配置目录
ln -sf ~/.cache-volumes/tmux ~/.tmux

# 安装 tpm（如果不存在）
if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# 创建 tmux 配置文件（如果不存在）
if [ ! -f ~/.tmux.conf ]; then
    cat > ~/.tmux.conf << 'EOF'
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
EOF
fi

echo "✅ tmux configured"

# ============================================
# 配置 zsh（持久化到 dev-cache）
# ============================================
echo "📦 Setting up zsh configuration..."

# 链接 zsh 插件目录
ln -sf ~/.cache-volumes/zsh ~/.zsh

# 安装 zsh 插件（如果不存在）
if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
fi

if [ ! -d ~/.zsh/zsh-syntax-highlighting ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
fi

# 添加 zsh 配置（如果不存在）
if ! grep -q "zsh-autosuggestions" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'EOF'

# zsh 主题（随机）
ZSH_THEME="random"

# zsh 插件
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# 实用别名
alias ll="eza -la"
alias cat="bat"
alias find="fd"
alias grep="rg"

# tmux 快捷键
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'
alias tk='tmux kill-session -t'
EOF
fi

echo "✅ zsh configured"

# ============================================
# 链接 AI agent 配置（从 dev-home volume）
# ============================================
if [ -d "/home/vscode/wsl-home/.claude" ]; then
    echo "📦 Linking Claude Code configuration..."
    ln -sf /home/vscode/wsl-home/.claude ~/.claude
fi

if [ -d "/home/vscode/wsl-home/.codex" ]; then
    echo "📦 Linking Codex configuration..."
    ln -sf /home/vscode/wsl-home/.codex ~/.codex
fi

if [ -d "/home/vscode/wsl-home/.gemini" ]; then
    echo "📦 Linking Gemini configuration..."
    ln -sf /home/vscode/wsl-home/.gemini ~/.gemini
fi

# ============================================
# 安装 AI Agents
# ============================================
if ! command -v claude &> /dev/null; then
    echo "📦 Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
fi

if ! command -v codex &> /dev/null; then
    echo "📦 Installing OpenAI Codex..."
    npm install -g @openai/codex
fi

if ! command -v gemini &> /dev/null; then
    echo "📦 Installing Gemini CLI..."
    npm install -g @google/gemini-cli
fi

echo ""
echo "✅ Development environment ready!"
echo ""
echo "Available AI agents:"
echo "  - claude   (Claude Code)"
echo "  - codex    (OpenAI Codex)"
echo "  - gemini   (Gemini CLI)"
echo ""
echo "Tmux shortcuts:"
echo "  tn <name>  - Create new session"
echo "  ta <name>  - Attach to session"
echo "  tl         - List sessions"
echo "  tk <name>  - Kill session"
echo ""
echo "Note: tmux and zsh configurations are persisted in dev-cache volume"
