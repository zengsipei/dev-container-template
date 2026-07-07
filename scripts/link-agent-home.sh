#!/bin/bash
# ============================================
# Agent Home 链接脚本 —— Persistence Manifest 的唯一运行时来源
# ============================================
# 政策见 docs/adr/0003-persistence-policy.md:home 短命,清单点名持久。
# 清单里的每个 dotdir 链入 Agent Home(Volume-Backed 或 Host-Backed),
# 其余 home 内容每次 rebuild 重置到镜像基线。
#
# 两个消费方共同调用,不得各自复制链接逻辑:
#   - .devcontainer/post-create.sh(从 workspace 直接调用)
#   - agent-compose/bootstrap.sh(经 compose.yaml 挂载为 /usr/local/bin/link-agent-home,
#     因 WORKSPACE_DIR 可指向任意项目,仓库文件不保证在容器内)
#
# 布线跟随安装层(ADR 0003 §4):本清单只管 Startup Install 工具的 Agent Home;
# 镜像烘焙工具的 Rebuildable Cache 链接由 devimage-build/.devcontainer/Dockerfile
# 烘焙,不要搬进本脚本。
set -e

AGENT_HOME=/home/vscode/wsl-home

# Persistence Manifest:要让一个新工具的状态在 rebuild 后存活,在此加一行 dotdir。
# 判据是丢失代价——丢了需要人工恢复(重登录/重配置/历史不可再生)才进清单;
# 丢了只损失时间的进 Rebuildable Cache(ADR 0003 §1)。粒度是 dotdir 整体,不拆内部。
PERSISTENCE_MANIFEST=(
    .claude
    .codex
    .gemini
    .hapi
)

for dir in "${PERSISTENCE_MANIFEST[@]}"; do
    # 无条件 mkdir -p:全新 Volume-Backed 用户的 dotdir 尚不存在,
    # 条件链接会让登录态写进容器 FS、rebuild 即丢
    mkdir -p "$AGENT_HOME/$dir"
    # -n:目标已是指向目录的符号链接时整体替换,而非把新链接嵌进目录里
    ln -sfn "$AGENT_HOME/$dir" "$HOME/$dir"
    echo "📦 Linked $dir -> Agent Home"
done
