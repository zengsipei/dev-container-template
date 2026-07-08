#!/bin/bash
# ============================================
# Agent CLI 安装脚本 —— Startup Install 的唯一运行时来源
# ============================================
# 政策见 docs/adr/0004-template-validation-policy.md:dedupe 优先于 check(决策 1)。
# claude/codex/gemini 的三段 npm install 块原本被 .devcontainer/post-create.sh 与
# agent-compose/bootstrap.sh 各复制一份(#5 暴露的分叉类问题,#10 的 .hapi 链接漂移即同类),
# 现收拢到本脚本,两个消费方都来调它,不得各自复制安装逻辑。
#
# 两个消费方调用方式不同:
#   - .devcontainer/post-create.sh:从 workspace 直接 `bash scripts/install-agent-clis.sh`
#   - agent-compose/bootstrap.sh:经 compose.yaml 挂载为 /usr/local/bin/install-agent-clis,
#     因 WORKSPACE_DIR 可指向任意项目,仓库文件不保证在容器内,不能按相对路径调用
#
# 安装清单(AGENT_CLI_INSTALL)是运行时验证检查的真实来源(ADR 0004 §5)——
# 必须可读作数据(列表),而非散落的 if 条件。新增一个公共 agent CLI 只需在此加一行。
#
# 幂等:每个 CLI 先 `command -v` 探 PATH,已存在则跳过,重复跑是秒级 no-op。
# HAPI 不在本清单:它是有意 devcontainer-only 的 delta,留在 post-create.sh(见 agent-compose README)。
# 对齐仓库约定(check-release-contract.sh 亦用 set -euo pipefail):未定义变量即失败、管道任一环节失败即失败。
set -euo pipefail

# Startup Install 清单:每个条目为 "PATH命令名|npm包|展示名"。
# 想让一个新公共 agent CLI 被两个消费方安装,在此加一行即可。
AGENT_CLI_INSTALL=(
    "claude|@anthropic-ai/claude-code|Claude Code"
    "codex|@openai/codex|OpenAI Codex"
    "gemini|@google/gemini-cli|Gemini CLI"
)

# 数据查询接口:运行时检查(scripts/check-runtime.sh)从这里读断言来源(PATH 命令名),
# 不得自带清单副本(ADR 0004 §5)。只打印、不安装,对消费方(无参调用)零影响。
if [ "${1:-}" = "--print-clis" ]; then
    for entry in "${AGENT_CLI_INSTALL[@]}"; do echo "${entry%%|*}"; done
    exit 0
fi

for entry in "${AGENT_CLI_INSTALL[@]}"; do
    cli="${entry%%|*}"          # PATH 上探测的命令名
    rest="${entry#*|}"
    pkg="${rest%%|*}"           # 要 npm install -g 的包
    label="${rest#*|}"          # 日志展示名

    if ! command -v "$cli" &> /dev/null; then
        echo "📦 Installing $label ($pkg)..."
        npm install -g "$pkg"
    fi
done
