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
  # node is a native Windows binary that rejects Git-Bash's /f/... absolute paths;
  # cd into the file's directory and pass only the basename so node reads it fine.
  local file="$1" dir
  dir="$(cd "$(dirname "$file")" && pwd)"
  with_cwd "$dir" node -e '
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
  ' "$(basename "$file")" "$2"
}

# compose_config <dir> : validate compose.yaml inside <dir> via a *relative* -f.
# A direct `docker compose -f "$ROOT/<dir>/compose.yaml"` would carry a /f/...
# path that Windows' docker binary rejects; cd'ing first avoids that entirely.
compose_config() { ( cd "$1" && exec docker compose -f compose.yaml config -q ); }

# with_cwd <dir> <cmd...> : run a *native* binary (docker/git/node/shellcheck) with cwd
# at <dir>. Git-Bash passes /f/... absolute paths to native Windows binaries, which
# reject them; cd'ing first (so only relative args cross the boundary) avoids the
# failure. This is the single home for the Windows path workaround used by the tiers.
with_cwd() { local d="$1"; shift; ( cd "$d" && exec "$@" ); }

static_tier() {
  echo "── static tier ──"

  # lint all tracked shell scripts with shellcheck
  local scripts=()
  while IFS= read -r f; do scripts+=("$f"); done < <(with_cwd "$ROOT" git ls-files '*.sh')
  if require shellcheck "shellcheck"; then
    run_check "shellcheck (${#scripts[@]} scripts)" with_cwd "$ROOT" shellcheck "${scripts[@]}"
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
    done < <(with_cwd "$ROOT" git ls-files '*.json')
  fi

  # docker compose config for both compose definitions
  # (all interpolated vars carry :- defaults, so no .env is required)
  if require docker "compose config"; then
    # cd into each compose dir so compose.yaml is read by a *relative* -f; an
    # explicit -f "$ROOT/..." would carry a /f/... path Windows' docker rejects.
    run_check "compose config: .devcontainer/compose.yaml" compose_config "$ROOT/.devcontainer"
    run_check "compose config: agent-compose/compose.yaml" compose_config "$ROOT/agent-compose"

    # pull-image.sh derives REF from compose.yaml (ADR 0005): its DRYRUN output must
    # equal `docker compose config --images`. First automated coverage for pull-image.sh.
    local expected_ref dryrun_out
    # cd into .devcontainer so compose.yaml is read by a *relative* -f; an explicit
    # -f "$ROOT/..." would carry a /f/... path that Windows' docker binary rejects.
    expected_ref="$(cd "$ROOT/.devcontainer" && docker compose -f compose.yaml config --images 2>/dev/null | head -n1)"
    if dryrun_out="$(PULL_IMAGE_DRYRUN=1 bash "$ROOT/.devcontainer/pull-image.sh" 2>&1)"; then
      if [ "$dryrun_out" = "DRYRUN would pull: $expected_ref" ]; then
        check_pass "pull-image.sh DRYRUN ref == compose (ADR 0005)"
      else
        check_fail "pull-image.sh DRYRUN ref mismatch"
        printf '%s\n' "$dryrun_out" | sed 's/^/    /'
      fi
    else
      check_fail "pull-image.sh DRYRUN failed"
      printf '%s\n' "$dryrun_out" | sed 's/^/    /'
    fi
  fi

  # ADR 0001 invariants — check-release-contract.sh stays the sole authority
  run_check "release contract (ADR 0001)" bash "$ROOT/scripts/check-release-contract.sh"
}

runtime_tier() {
  echo "── runtime tier ──"
  # not run_check: the runtime check spends minutes on docker + real npm installs,
  # so stream its output live instead of buffering until failure
  if require docker "runtime check"; then
    if bash "$ROOT/scripts/check-runtime.sh"; then
      check_pass "runtime check"
    else
      check_fail "runtime check"
    fi
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
