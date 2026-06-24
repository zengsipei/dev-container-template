#!/usr/bin/env bash
# 宿主侧镜像预拉取（消费 Latest Pointer 的更新机制）。
# 契约见 docs/adr/0001-image-release-contract.md。
#
# 为什么在这里而不是 compose 的 pull_policy: always：
#   VS Code Dev Containers 生成临时合并 compose 时会把 service 的 image 改写成本地派生镜像引用
#   （从上游镜像 FROM 出来、叠加 features/labels 后的本地 tag）。compose 的 pull_policy: always
#   会试图去 registry 拉这个只存在于本地的名字而失败。
#   devcontainer.json 的 initializeCommand 在宿主机上、在 VS Code 处理 compose / 派生构建之前运行
#   （含每次 Rebuild），此时拉取的是真正的上游 tag，不受临时 compose 改写影响。VS Code 随后的派生
#   构建会 FROM 这个刚刷新的本地 :latest，于是 rebuild 就跑到了新发布的镜像上。
#
# 行为：
#   - 仅当消费的 tag 是 latest（Latest Pointer）时拉取；pin 到 :vX.Y.Z 的用户跳过，不被强制拉取。
#   - best-effort：拉取失败（离线等）不阻塞容器创建，回退到本地已缓存镜像。
#   - PULL_IMAGE_DRYRUN=1 时只打印决策、不调用 docker（用于本地验证逻辑）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# 与 compose.yaml 一致的默认值（单一真相在 ADR 0001；此处仅为本地消费端）
DEFAULT_USER="xiao806852034"
DEFAULT_IMAGE="ai-dev-container"
DEFAULT_TAG="latest"

# 从 .env 读取镜像标识变量（仅取需要的 key，避免 source 任意内容）。
read_env() {
  local key="$1"
  [ -f "$ENV_FILE" ] || return 0
  # 取最后一个非注释赋值，去掉可能的引号与首尾空白
  grep -E "^[[:space:]]*${key}=" "$ENV_FILE" 2>/dev/null \
    | grep -vE "^[[:space:]]*#" \
    | tail -n1 \
    | sed -E "s/^[[:space:]]*${key}=//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]*$//"
}

# 环境变量优先，其次 .env，最后默认值
USERNAME="${DOCKERHUB_USERNAME:-$(read_env DOCKERHUB_USERNAME)}"
IMAGE="${IMAGE_NAME:-$(read_env IMAGE_NAME)}"
TAG="${IMAGE_TAG:-$(read_env IMAGE_TAG)}"

USERNAME="${USERNAME:-$DEFAULT_USER}"
IMAGE="${IMAGE:-$DEFAULT_IMAGE}"
TAG="${TAG:-$DEFAULT_TAG}"

REF="${USERNAME}/${IMAGE}:${TAG}"

# pin 的版本是不可变的，不强制拉取，保持在固定 digest 上。
if [ "$TAG" != "latest" ]; then
  echo "🔒 Pinned image tag '$TAG' — 跳过自动拉取（$REF）"
  exit 0
fi

if [ "${PULL_IMAGE_DRYRUN:-0}" = "1" ]; then
  echo "DRYRUN would pull: $REF"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "⚠️  未找到 docker，跳过镜像预拉取（$REF）"
  exit 0
fi

echo "⬇️  Pulling Latest Pointer: $REF"
if docker pull "$REF"; then
  echo "✅ 已是最新基线：$REF"
else
  echo "⚠️  拉取失败（离线？），回退到本地已缓存镜像：$REF"
fi

exit 0
