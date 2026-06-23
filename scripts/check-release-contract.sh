#!/usr/bin/env bash
# Release-contract drift guard.
# Single source of truth: docs/adr/0001-image-release-contract.md
# Asserts three invariants so docs/automation cannot silently drift apart.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/.github/workflows/build-image.yml"
COMPOSE="$ROOT/.devcontainer/compose.yaml"
DOCS=("$ROOT/README.md" "$ROOT/devimage-build/README.md" "$ROOT/.devcontainer/README.md")

fail=0
err() { echo "❌ $1"; fail=1; }

# --- Invariant 1: image identity defaults consistent (workflow <-> compose) ---
wf_user=$(grep -oE "vars\.DOCKERHUB_USERNAME \|\| '[^']+'" "$WF" | grep -oE "'[^']+'" | tr -d "'" || true)
wf_image=$(grep -oE "vars\.IMAGE_NAME \|\| '[^']+'" "$WF" | grep -oE "'[^']+'" | tr -d "'" || true)
co_user=$(grep -oE '\$\{DOCKERHUB_USERNAME:-[^}]+\}' "$COMPOSE" | sed -E 's/.*:-([^}]+)\}/\1/' || true)
co_image=$(grep -oE '\$\{IMAGE_NAME:-[^}]+\}' "$COMPOSE" | sed -E 's/.*:-([^}]+)\}/\1/' || true)

[ -n "$wf_user" ]  || err "workflow: missing 'vars.DOCKERHUB_USERNAME || <default>'"
[ -n "$wf_image" ] || err "workflow: missing 'vars.IMAGE_NAME || <default>'"
[ -n "$co_user" ]  || err "compose: missing \${DOCKERHUB_USERNAME:-<default>}"
[ -n "$co_image" ] || err "compose: missing \${IMAGE_NAME:-<default>}"
[ "$wf_user" = "$co_user" ]   || err "image owner default drift: workflow='$wf_user' vs compose='$co_user'"
[ "$wf_image" = "$co_image" ] || err "image name default drift: workflow='$wf_image' vs compose='$co_image'"

# --- Invariant 2: release triggers are exactly {tag v*, workflow_dispatch}, no branch release ---
grep -qE "^[[:space:]]*workflow_dispatch:" "$WF" || err "workflow: missing workflow_dispatch trigger"
grep -qE "^[[:space:]]*tags:" "$WF"              || err "workflow: missing tag trigger"
grep -qE "'v\*'" "$WF"                           || err "workflow: tag filter is not 'v*'"
if grep -qE "^[[:space:]]*branches:" "$WF"; then
  err "workflow: unexpected 'branches:' trigger (contract forbids main-branch release)"
fi

# --- Invariant 3: retired drift claims must not reappear in prose docs ---
scan() { # file pattern message
  if grep -nEi "$2" "$1" >/dev/null 2>&1; then err "$3 -> $1"; fi
}
for f in "${DOCS[@]}"; do
  [ -f "$f" ] || continue
  scan "$f" "推送到[[:space:]]*main|push[[:space:]]+origin[[:space:]]+main" \
    "retired claim: main-branch release trigger"
  scan "$f" "DOCKER_HUB_USERNAME" \
    "retired claim: DOCKER_HUB_USERNAME secret (username is a repo Variable now)"
  scan "$f" "docker/build-push-action" \
    "retired claim: build-push-action (workflow uses the devcontainer CLI)"
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Release-contract check FAILED. See docs/adr/0001-image-release-contract.md"
  exit 1
fi
echo "✅ Release-contract check passed."
