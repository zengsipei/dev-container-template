#!/usr/bin/env bash
# Template validation umbrella (ADR 0004 decisions 3-4).
# Usage: check-template.sh [static|runtime|build|all]   (default: static)
# Orchestrates the validation tiers; each tier's checks stay independently
# runnable (e.g. scripts/check-release-contract.sh, scripts/check-runtime.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIER="${1:-static}"

fail=0
check_pass() { echo "✅ PASS  $1"; }
check_fail() { echo "❌ FAIL  $1"; fail=1; }

# run_check <label> <cmd...> : run one check, print pass/fail, show output on failure
run_check() {
  local label="$1"; shift
  local out
  if out=$("$@" 2>&1); then
    check_pass "$label"
  else
    check_fail "$label"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
  fi
  return 0
}

# require <cmd> <label> : record a clear FAIL when a prerequisite tool is absent
require() {
  if command -v "$1" >/dev/null 2>&1; then return 0; fi
  check_fail "$2 (prerequisite '$1' not installed)"
  return 1
}

# JSONC-aware syntax validation. devcontainer.json is JSONC per the devcontainer
# spec (comments and trailing commas are legal); mode=json parses strictly.
validate_json() { # <file> <json|jsonc>
  node -e '
    const fs = require("fs");
    const [file, mode] = process.argv.slice(1);
    let s = fs.readFileSync(file, "utf8");
    if (mode === "jsonc") {
      // strip comments, then trailing commas — both string-aware, so string
      // contents like "," or "//" are never touched
      const stripComments = (s) => {
        let out = "", i = 0, str = false;
        while (i < s.length) {
          const c = s[i];
          if (str) {
            out += c;
            if (c === "\\") { out += s[i + 1] ?? ""; i += 2; continue; }
            if (c === "\"") str = false;
            i++; continue;
          }
          if (c === "\"") { str = true; out += c; i++; continue; }
          if (c === "/" && s[i + 1] === "/") { while (i < s.length && s[i] !== "\n") i++; continue; }
          if (c === "/" && s[i + 1] === "*") { i += 2; while (i < s.length && !(s[i] === "*" && s[i + 1] === "/")) i++; i += 2; continue; }
          out += c; i++;
        }
        return out;
      };
      const stripTrailingCommas = (s) => {
        let out = "", i = 0, str = false;
        while (i < s.length) {
          const c = s[i];
          if (str) {
            out += c;
            if (c === "\\") { out += s[i + 1] ?? ""; i += 2; continue; }
            if (c === "\"") str = false;
            i++; continue;
          }
          if (c === "\"") { str = true; out += c; i++; continue; }
          if (c === ",") {
            let j = i + 1;
            while (j < s.length && /\s/.test(s[j])) j++;
            if (s[j] === "}" || s[j] === "]") { i++; continue; }
          }
          out += c; i++;
        }
        return out;
      };
      s = stripTrailingCommas(stripComments(s));
    }
    JSON.parse(s);
  ' "$1" "$2"
}

static_tier() {
  echo "── static tier ──"

  # lint all tracked shell scripts with shellcheck
  local scripts=()
  while IFS= read -r f; do scripts+=("$ROOT/$f"); done < <(git -C "$ROOT" ls-files '*.sh')
  if require shellcheck "shellcheck"; then
    run_check "shellcheck (${#scripts[@]} scripts)" shellcheck "${scripts[@]}"
  fi

  # JSON / JSONC syntax (devcontainer.json is JSONC; the lock file is plain JSON)
  local f mode
  if require node "json syntax"; then
    while IFS= read -r f; do
      case "$f" in
        */devcontainer.json|devcontainer.json) mode=jsonc ;;
        *) mode=json ;;
      esac
      run_check "$mode syntax: $f" validate_json "$ROOT/$f" "$mode"
    done < <(git -C "$ROOT" ls-files '*.json')
  fi

  # docker compose config for both compose definitions
  # (all interpolated vars carry :- defaults, so no .env is required)
  if require docker "compose config"; then
    run_check "compose config: .devcontainer/compose.yaml" \
      docker compose -f "$ROOT/.devcontainer/compose.yaml" config -q
    run_check "compose config: agent-compose/compose.yaml" \
      docker compose -f "$ROOT/agent-compose/compose.yaml" config -q
  fi

  # ADR 0001 invariants — check-release-contract.sh stays the sole authority
  run_check "release contract (ADR 0001)" bash "$ROOT/scripts/check-release-contract.sh"
}

runtime_tier() {
  echo "── runtime tier ──"
  if [ -f "$ROOT/scripts/check-runtime.sh" ]; then
    run_check "runtime check" bash "$ROOT/scripts/check-runtime.sh"
  else
    echo "⏭️  SKIP  runtime tier (scripts/check-runtime.sh not implemented)"
  fi
}

build_tier() {
  echo "── build tier ──"
  echo "⏭️  SKIP  build tier (CI-only: .github/workflows/image-build-check.yml)"
}

case "$TIER" in
  static)  static_tier ;;
  runtime) runtime_tier ;;
  build)   build_tier ;;
  all)     static_tier; runtime_tier; build_tier ;;
  *)       echo "usage: $0 [static|runtime|build|all]" >&2; exit 2 ;;
esac

echo ""
if [ "$fail" -ne 0 ]; then
  echo "check-template ($TIER): FAILED"
  exit 1
fi
echo "check-template ($TIER): all checks passed"
