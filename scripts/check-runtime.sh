#!/usr/bin/env bash
# ============================================
# 运行时验证层（ADR 0004 决策 5-6）—— agent-compose 端到端检查
# ============================================
# 以 fresh Agent Home 起 agent-compose 服务,等 bootstrap 走完真实路径
# （Startup Install 的 npm install 不跳过、不 mock）,然后断言三组:
#   1. Persistence Manifest:清单每个 dotdir 在容器 $HOME 是符号链接,
#      readlink 精确指进 Agent Home 挂载
#   2. 幂等性:restart 让 bootstrap 在链接已存在的 FS 上重跑,再验 readlink
#      精确不变且无嵌套链接（ln -sf 嵌套类 bug 只在这一步暴露）
#   3. Startup Install:共享安装清单里的 CLI 都在 PATH 上。HAPI 刻意不断言——
#      agent-compose 有意不装它（devcontainer-only,见 agent-compose/README.md）
#
# 断言来源是两份共享脚本的 --print-* 数据接口（在容器内调 compose 挂载的同一份文件）,
# 本检查不自带清单副本——新工具进清单即自动被覆盖（ADR 0004 §5）。
#
# 安全约束（ADR 0004 决策 6,违反任一条会毁掉真实登录态）:
#   - compose 的 volume 是固定名（dev-home / dev-cache）,不随 -p 项目前缀隔离。
#     fresh home 必须用 Host-Backed 临时目录（WSL_HOME=<临时目录>）实现,
#     真实 dev-home 从不挂载进检查容器。
#   - teardown 永不带 -v。dev-cache 仍共享挂载:它是 Rebuildable Cache,
#     npm 写缓存是其设计用途,且共享能加速本地检查;不删即安全。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/agent-compose/compose.yaml"
# 固定项目名:与真实使用（默认项目名 agent-compose）隔离,重跑可清理上次残留
PROJECT=template-runtime-check
# bootstrap.sh 收尾输出的稳定子串,作为「引导完成」信号;改 bootstrap 的完成消息需同步这里
READY_MARKER="Agent 环境就绪"

compose() { docker compose -p "$PROJECT" -f "$COMPOSE_FILE" "$@"; }

command -v docker >/dev/null 2>&1 || { echo "❌ 运行时检查需要 docker"; exit 1; }

# fresh Agent Home:Host-Backed 临时目录（见文件头安全约束）
TMP_HOME="$(mktemp -d)"
WSL_HOME="$TMP_HOME"
# Windows（git-bash）下 compose 是 Windows 二进制,把 POSIX 临时路径转成它认识的形式
if command -v cygpath >/dev/null 2>&1; then WSL_HOME="$(cygpath -m "$TMP_HOME")"; fi
export WSL_HOME
# 固定 workspace 指向本仓库,免受本地 agent-compose/.env 的 WORKSPACE_DIR 影响
export WORKSPACE_DIR="$ROOT"

cleanup() {
  # 容器以 vscode 用户清空临时 Agent Home 内容,避免宿主（尤其 CI runner）对
  # 容器属主文件 rm 失败;检查已失败时容器可能不在,忽略即可
  # shellcheck disable=SC2016  # $(...) 必须在容器内展开,单引号是刻意的
  compose exec -T agent bash -c \
    'find "$(bash /usr/local/bin/link-agent-home --print-agent-home)" -mindepth 1 -delete' \
    >/dev/null 2>&1 || true
  # 永不带 -v:volume 是固定名,-v 会删掉真实 dev-home / dev-cache（ADR 0004 决策 6）
  compose down --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TMP_HOME" 2>/dev/null || echo "⚠️  临时 Agent Home 未能完全清理: $TMP_HOME"
}
trap cleanup EXIT

# wait_bootstrap <期望完成次数> <超时秒> <阶段标签>
# 轮询日志中 READY_MARKER 的出现次数;容器退出（bootstrap 失败）立即报错
wait_bootstrap() {
  local expected=$1 timeout=$2 label=$3 waited=0 count
  while :; do
    count=$(compose logs agent 2>/dev/null | grep -cF "$READY_MARKER" || true)
    count=${count:-0}
    if [ "$count" -ge "$expected" ]; then
      echo "✅ bootstrap 完成（$label）"
      return 0
    fi
    if [ -z "$(compose ps --status running -q agent 2>/dev/null)" ]; then
      echo "❌ agent 容器已退出,bootstrap 未完成（$label）;最近日志:"
      compose logs --tail 50 agent || true
      return 1
    fi
    if [ "$waited" -ge "$timeout" ]; then
      echo "❌ 等待 bootstrap 超时 ${timeout}s（$label）;最近日志:"
      compose logs --tail 50 agent || true
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

# 断言 1 + 2 共用:清单每个 dotdir 的链接存在、readlink 精确、无嵌套。
# 清单与 Agent Home 路径读自容器内挂载的链接脚本本体——与 bootstrap 执行的是同一份文件
assert_persistence() {
  local label=$1
  compose exec -T agent bash -s <<'EOF' || { echo "❌ Persistence Manifest 断言失败（$label）"; return 1; }
set -euo pipefail
agent_home=$(bash /usr/local/bin/link-agent-home --print-agent-home)
mapfile -t manifest < <(bash /usr/local/bin/link-agent-home --print-manifest)
[ "${#manifest[@]}" -gt 0 ] || { echo "❌ Persistence Manifest 为空"; exit 1; }
for dir in "${manifest[@]}"; do
  link="$HOME/$dir"
  [ -L "$link" ] || { echo "❌ $link 不是符号链接（漏链清单条目 / 条件链接类 bug）"; exit 1; }
  target=$(readlink "$link")
  [ "$target" = "$agent_home/$dir" ] || { echo "❌ $link -> $target,期望 $agent_home/$dir"; exit 1; }
  nested="$agent_home/$dir/$dir"
  if [ -L "$nested" ] || [ -e "$nested" ]; then
    echo "❌ 嵌套链接 $nested 存在（ln -sf 类 bug）"; exit 1
  fi
  echo "ok: $link -> $target"
done
EOF
  echo "✅ Persistence Manifest 断言通过（$label）"
}

# 断言 3:共享安装清单里的每个 CLI 都在 PATH 上
assert_startup_install() {
  compose exec -T agent bash -s <<'EOF' || { echo "❌ Startup Install 断言失败"; return 1; }
set -euo pipefail
mapfile -t clis < <(bash /usr/local/bin/install-agent-clis --print-clis)
[ "${#clis[@]}" -gt 0 ] || { echo "❌ Startup Install 清单为空"; exit 1; }
for cli in "${clis[@]}"; do
  command -v "$cli" >/dev/null || { echo "❌ $cli 不在 PATH 上"; exit 1; }
  echo "ok: $cli -> $(command -v "$cli")"
done
EOF
  echo "✅ Startup Install 断言通过"
}

echo "── 运行时检查:fresh Agent Home = $WSL_HOME ──"
compose up -d --force-recreate --quiet-pull
# 首次引导包含真实 npm install,给足网络时间
wait_bootstrap 1 600 "首次启动"

assert_persistence "首次启动"
assert_startup_install

echo "── 幂等性:restart 让 bootstrap 在链接已存在的 FS 上重跑 ──"
compose restart agent
# 第二遍很便宜:容器 FS 未重建,CLI 仍在,安装守卫直接跳过
wait_bootstrap 2 300 "restart 重跑"
assert_persistence "restart 重跑"

echo ""
echo "✅ check-runtime: 运行时三组断言全部通过"
