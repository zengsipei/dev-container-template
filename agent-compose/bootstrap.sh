#!/bin/bash
# ============================================
# agent-compose 容器引导脚本
# ============================================
# 由 compose.yaml 作为容器 command 运行（对应 devcontainer 流程的 post-create.sh）：
#   1. 链接 Agent Home（dev-home volume）里的 agent 配置到 ~
#   2. Startup Install：安装缺失的 coding agent CLI（镜像刻意不烘焙，见 ADR 0001）
#   3. sleep infinity 常驻，等待 `docker compose exec agent <cli>` 进入
set -e

# ============================================
# 链接 Agent Home（Persistence Manifest 见仓库 scripts/link-agent-home.sh）
# ============================================
# 脚本由 compose.yaml 挂载进来——WORKSPACE_DIR 可指向任意项目，
# 仓库文件不保证在容器内，不能按相对路径调用。
bash /usr/local/bin/link-agent-home

# ============================================
# 安装公共 AI Agents（Startup Install，幂等）
# ============================================
# claude/codex/gemini 的安装清单唯一来源是 scripts/install-agent-clis.sh,
# 经 compose.yaml 挂载为 /usr/local/bin/install-agent-clis 调用——与 link-agent-home 同方式。
# HAPI 有意不在此装(见 agent-compose README),保持 devcontainer-only。
bash /usr/local/bin/install-agent-clis

echo "✅ Agent 环境就绪。进入方式：docker compose exec agent claude（或 codex / gemini / bash）"

# 常驻（PID 1 由 compose 的 init: true 托管，可正常响应 stop 信号）
exec sleep infinity
