#!/bin/bash
# ============================================
# agent-compose 容器引导脚本
# ============================================
# 由 compose.yaml 作为容器 command 运行（对应 devcontainer 流程的 post-create.sh）：
#   1. 链接 Agent Home（dev-home volume）里的 agent 配置到 ~
#   2. Startup Install：安装缺失的 coding agent CLI（镜像刻意不烘焙，见 ADR 0001）
#   3. sleep infinity 常驻，等待 `docker compose exec agent <cli>` 进入
set -e

AGENT_HOME=/home/vscode/wsl-home

# ============================================
# 链接 AI agent 配置（与 devcontainer 共享同一 dev-home volume）
# ============================================
for dir in .claude .codex .gemini; do
    mkdir -p "$AGENT_HOME/$dir"
    ln -sfn "$AGENT_HOME/$dir" "$HOME/$dir"
    echo "📦 Linked $dir -> Agent Home"
done

# ============================================
# 安装 AI Agents（Startup Install，幂等）
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

echo "✅ Agent 环境就绪。进入方式：docker compose exec agent claude（或 codex / gemini / bash）"

# 常驻（PID 1 由 compose 的 init: true 托管，可正常响应 stop 信号）
exec sleep infinity
