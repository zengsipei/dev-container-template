#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

# ============================================
# 设置缓存目录（统一 named volume）
# ============================================
echo "📦 Setting up cache directories..."

# 使用 sudo 创建缓存子目录，并修改所有者为 vscode，原因是 dev-cache 在无 ~/.cache-volumes 目录时，会以 root 挂载
sudo mkdir -p ~/.cache-volumes/{npm,pnpm,pip,poetry,vscode-extensions}
sudo chown -R vscode:vscode ~/.cache-volumes

# 创建符号链接（确保符号链接的父目录存在）
mkdir -p ~/.local/share/pnpm
mkdir -p ~/.cache/pip
mkdir -p ~/.cache/pypoetry
mkdir -p ~/.vscode-server/extensions

# 创建符号链接
ln -sf ~/.cache-volumes/npm ~/.npm
ln -sf ~/.cache-volumes/pnpm ~/.local/share/pnpm
ln -sf ~/.cache-volumes/pip ~/.cache/pip
ln -sf ~/.cache-volumes/poetry ~/.cache/pypoetry
ln -sf ~/.cache-volumes/vscode-extensions ~/.vscode-server/extensions

echo "✅ Cache directories configured"

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

# ============================================
# 配置 tmux 快捷键
# ============================================
echo "" >> ~/.zshrc
echo "# tmux shortcuts" >> ~/.zshrc
echo "alias ta='tmux attach -t'" >> ~/.zshrc
echo "alias tn='tmux new -s'" >> ~/.zshrc
echo "alias tl='tmux ls'" >> ~/.zshrc
echo "alias tk='tmux kill-session -t'" >> ~/.zshrc

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
