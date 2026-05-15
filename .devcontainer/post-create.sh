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

