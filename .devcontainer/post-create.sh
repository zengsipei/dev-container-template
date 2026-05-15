#!/bin/bash
set -e

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