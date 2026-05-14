#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

# ============================================
# 设置缓存目录（统一 named volume）
# ============================================
echo "📦 Setting up cache directories..."

# 创建缓存子目录
mkdir -p ~/.cache-volumes/{npm,pnpm,pip,poetry,vscode-extensions}

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
if [ -d "/home/dev/wsl-home/.claude" ]; then
    echo "📦 Linking Claude Code configuration..."
    ln -sf /home/dev/wsl-home/.claude ~/.claude
fi

if [ -d "/home/dev/wsl-home/.codex" ]; then
    echo "📦 Linking Codex configuration..."
    ln -sf /home/dev/wsl-home/.codex ~/.codex
fi

if [ -d "/home/dev/wsl-home/.gemini" ]; then
    echo "📦 Linking Gemini configuration..."
    ln -sf /home/dev/wsl-home/.gemini ~/.gemini
fi

# ============================================
# 安装 AI Agents
# ============================================
if ! command -v claude &> /dev/null; then
    echo "📦 Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | sh
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
fi

if ! command -v codex &> /dev/null; then
    echo "📦 Installing OpenAI Codex..."
    npm install -g @openai/codex
fi

if ! command -v gemini &> /dev/null; then
    echo "📦 Installing Gemini CLI..."
    npm install -g @anthropic/gemini-cli
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
