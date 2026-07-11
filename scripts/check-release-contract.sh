#!/usr/bin/env bash
# Release-contract drift guard.
# Single source of truth: docs/adr/0001-image-release-contract.md
# Asserts three invariants so docs/automation cannot silently drift apart.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/.github/workflows/build-image.yml"
COMPOSE="$ROOT/.devcontainer/compose.yaml"
AGENT_COMPOSE="$ROOT/agent-compose/compose.yaml"
PULL="$ROOT/.devcontainer/pull-image.sh"
DOCS=("$ROOT/README.md" "$ROOT/devimage-build/README.md" "$ROOT/.devcontainer/README.md")

fail=0
err() { echo "❌ $1"; fail=1; }

# Extract the default value of an interpolated variable from a file.
#   $1 = file   $2 = variable name
#   $3 = form:  'compose'   -> ${VAR:-default} (compose interpolation)
#               'workflow'  -> vars.VAR || 'default' (GitHub Actions expression)
# On no match the pipeline yields empty + non-zero; the caller's [ -n ... ] checks catch it.
extract_default() {
  local file="$1" var="$2" form="$3" pat=''
  case "$form" in
    # printf keeps the backslashes in \${..\} intact for grep -E: the var is a
    # separate argument, so bash never mistakes \${ for a parameter expansion.
    compose)
      # \${ is an intentional literal for grep -E, not a shell expansion (hence SC2016 is muted)
      # shellcheck disable=SC2016
      printf -v pat '\${%s:-[^}]+\}' "$var"
      grep -oE "$pat" "$file" | sed -E 's/.*:-([^}]+)\}/\1/' | head -n1 || true ;;
    workflow)
      grep -oE "vars\.${var} \|\| '[^']+'" "$file" | grep -oE "'[^']+'" | tr -d "'" | head -n1 || true ;;
  esac
}

# --- Invariant 1: image identity defaults consistent across all three non-eliminable
#     declaration sites (workflow <-> .devcontainer/compose <-> agent-compose/compose) ---
wf_user=$(extract_default "$WF" DOCKERHUB_USERNAME workflow)
wf_image=$(extract_default "$WF" IMAGE_NAME workflow)
co_user=$(extract_default "$COMPOSE" DOCKERHUB_USERNAME compose)
co_image=$(extract_default "$COMPOSE" IMAGE_NAME compose)
ac_user=$(extract_default "$AGENT_COMPOSE" DOCKERHUB_USERNAME compose)
ac_image=$(extract_default "$AGENT_COMPOSE" IMAGE_NAME compose)

[ -n "$wf_user" ]  || err "workflow: missing 'vars.DOCKERHUB_USERNAME || <default>'"
[ -n "$wf_image" ] || err "workflow: missing 'vars.IMAGE_NAME || <default>'"
[ -n "$co_user" ]  || err "compose: missing \${DOCKERHUB_USERNAME:-<default>}"
[ -n "$co_image" ] || err "compose: missing \${IMAGE_NAME:-<default>}"
[ -n "$ac_user" ]  || err "agent-compose: missing \${DOCKERHUB_USERNAME:-<default>}"
[ -n "$ac_image" ] || err "agent-compose: missing \${IMAGE_NAME:-<default>}"
[ "$wf_user" = "$co_user" ]   || err "image owner default drift: workflow='$wf_user' vs compose='$co_user'"
[ "$wf_image" = "$co_image" ] || err "image name default drift: workflow='$wf_image' vs compose='$co_image'"
[ "$wf_user" = "$ac_user" ]   || err "image owner default drift: workflow='$wf_user' vs agent-compose='$ac_user'"
[ "$wf_image" = "$ac_image" ] || err "image name default drift: workflow='$wf_image' vs agent-compose='$ac_image'"
[ "$co_user" = "$ac_user" ]   || err "image owner default drift: compose='$co_user' vs agent-compose='$ac_user'"
[ "$co_image" = "$ac_image" ] || err "image name default drift: compose='$co_image' vs agent-compose='$ac_image'"

# --- Invariant 1b: pull-image.sh must derive identity from compose, NOT hardcode ---
# (it switched to `docker compose config --images` in ADR 0005; a DEFAULT_* literal here
#  would re-introduce the very drift this ADR guards against)
if grep -nE "DEFAULT_(USER|IMAGE|TAG)=" "$PULL" >/dev/null 2>&1; then
  err "pull-image.sh must derive image identity from compose, not hardcode DEFAULT_* (ADR 0005)"
fi

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
