#!/bin/bash
set -e

# ============================================
# 链接 Agent Home（Persistence Manifest 见 scripts/link-agent-home.sh）
# ============================================
bash scripts/link-agent-home.sh


# ============================================
# 安装公共 AI Agent CLI（Startup Install）
# ============================================
# claude/codex/gemini 的安装清单唯一来源是 scripts/install-agent-clis.sh,
# 两个消费方(post-create / bootstrap)都调它,不再各自内联。
# HAPI 的 delta 仍在本脚本(devcontainer-only),见下方。
bash scripts/install-agent-clis.sh


# ============================================
# HAPI Local Hub（@twsxtd/hapi）—— devcontainer-only
# ============================================
# HAPI 作为 Startup Install 在容器创建时从 npm 安装，保持最新；
# 状态目录 ~/.hapi 的持久化由 Persistence Manifest（scripts/link-agent-home.sh）负责；
# hub 与 runner 在后台拉起。

# Startup Install：安装或更新 HAPI（使用官方 registry 确保拉到平台二进制）
echo "📦 Installing/updating HAPI..."
npm install -g @twsxtd/hapi --registry=https://registry.npmjs.org \
    || echo "⚠️  HAPI 安装失败，跳过 Local Hub 启动"

# 后台非阻塞拉起 Local Hub 与 runner（不阻塞容器创建）
if command -v hapi &> /dev/null; then
    echo "🚀 Starting HAPI Local Hub in background..."
    nohup bash .devcontainer/hapi-up.sh >/dev/null 2>&1 &
    disown
fi