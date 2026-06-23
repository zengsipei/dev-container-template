#!/bin/bash
# ============================================
# HAPI Local Hub 后台拉起脚本
# ============================================
# 由 post-create.sh 在后台调用，负责：
#   1. 启动 Local Hub（监听 0.0.0.0:3006，供 Docker 端口映射到宿主回环）
#   2. 等待 hub 端口就绪后启动 runner
#   3. 日志写入持久化的 Agent Home（~/.hapi/logs）
#
# 幂等性：
#   - hub：端口已被占用则跳过启动，不会重复拉起
#   - runner：`hapi runner start` 会先停掉已有 runner 再启动（内置锁文件），
#     因此重复运行本脚本不会产生重复进程
#
# 注意：HAPI 需要 CLI_API_TOKEN 才能正常工作。用户首次需在容器内执行
#       `hapi auth login` 配置（令牌持久化在 ~/.hapi，重建容器不丢失），
#       或设置 CLI_API_TOKEN 环境变量。未配置令牌时 hub 可能直接退出，
#       本脚本仍保持非阻塞，相关信息写入日志。

set -u

HAPI_LINK="$HOME/.hapi"
LOG_DIR="$HAPI_LINK/logs"
LISTEN_HOST="${HAPI_LISTEN_HOST:-0.0.0.0}"
PORT="${HAPI_LISTEN_PORT:-3006}"
WORKSPACE_ROOT="${HAPI_WORKSPACE_ROOT:-$HOME/workspace}"

mkdir -p "$LOG_DIR"

log() {
    echo "$(date '+%F %T') $*"
}

# 通过 bash /dev/tcp 探测端口是否已在监听（无需额外工具）
port_in_use() {
    (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && exec 3>&- && return 0
    return 1
}

if ! command -v hapi &>/dev/null; then
    log "hapi 未安装，跳过 Local Hub 启动"
    exit 0
fi

# 1) 启动 Local Hub（仅当端口空闲，保证幂等）
if port_in_use; then
    log "hub 已在 $PORT 端口监听，跳过启动"
else
    log "启动 hapi hub（监听 $LISTEN_HOST:$PORT）"
    HAPI_LISTEN_HOST="$LISTEN_HOST" HAPI_LISTEN_PORT="$PORT" \
        nohup hapi hub >>"$LOG_DIR/hub.log" 2>&1 &
    disown
fi

# 2) 等待 hub 就绪（最多约 30s）
for _ in $(seq 1 60); do
    port_in_use && break
    sleep 0.5
done

if ! port_in_use; then
    log "hub 未能在 $PORT 端口就绪，runner 不启动（详见 $LOG_DIR/hub.log）"
    exit 0
fi

# 3) hub 就绪后启动 runner（start 会替换已有 runner，天然幂等）
log "hub 就绪，启动 hapi runner（workspace-root=$WORKSPACE_ROOT）"
nohup hapi runner start --workspace-root "$WORKSPACE_ROOT" >>"$LOG_DIR/runner.log" 2>&1 &
disown

log "HAPI Local Hub 拉起完成"
