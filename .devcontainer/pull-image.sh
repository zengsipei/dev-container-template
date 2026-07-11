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
# 镜像标识单一真相源 = .devcontainer/compose.yaml（ADR 0001）。本脚本不再自带默认值字面量，
# 而是直接用 `docker compose config --images` 让 compose 自己的解析器落定 ${...:-} 默认值，
# 因此 fork / 改默认值只需改 compose 一处（见 ADR 0005）。
# 行为：
#   - 仅当消费的 tag 是 latest（Latest Pointer）时拉取；pin 到 :vX.Y.Z 的用户跳过，不被强制拉取。
#   - best-effort：派生失败（docker 缺失 / compose 解析报错）不阻塞容器创建，回退到本地已缓存镜像。
#   - PULL_IMAGE_DRYRUN=1 时只打印决策、不调用 docker（用于本地验证逻辑）。
set -uo pipefail

# 进入脚本所在目录，docker compose 以相对路径读取 compose.yaml。
# 规避 Windows Git Bash 下绝对路径（/f/...）不被 Windows 版 docker 识别、导致静默跳过拉取的坑。
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 0

# 单一真相源：compose.yaml 的 image 字段，由 compose 解析器落定 ${...:-} 默认值。
# 派生失败（docker 缺失 / compose 解析报错 / 无镜像输出）时回退本地缓存，best-effort 非阻塞。
REF="$(docker compose -f compose.yaml config --images 2>/dev/null | head -n1)"
if [ -z "$REF" ]; then
  echo "⚠️  无法从 compose 派生镜像引用（docker 缺失或 compose 解析失败），跳过镜像预拉取"
  exit 0
fi

# pin 的版本是不可变的，不强制拉取，保持在固定 digest 上。
# tag 从完整 ref 末段取：image@sha256:... 的 digest pin 也落入「非 latest」分支而跳过。
TAG="${REF##*:}"
if [ "$TAG" != "latest" ]; then
  echo "🔒 Pinned image tag '$TAG' — 跳过自动拉取（$REF）"
  exit 0
fi

if [ "${PULL_IMAGE_DRYRUN:-0}" = "1" ]; then
  echo "DRYRUN would pull: $REF"
  exit 0
fi

echo "⬇️  Pulling Latest Pointer: $REF"
if docker pull "$REF"; then
  echo "✅ 已是最新基线：$REF"
else
  echo "⚠️  拉取失败（离线？），回退到本地已缓存镜像：$REF"
fi

exit 0
