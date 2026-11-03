#!/usr/bin/env bash
# FailFirst verdict: check + scan + Markdown report.
# Usage: run.sh --base <ref> [--test-command <cmd>] [--version <fail-first-gate version>]
# Runs against $FAILFIRST_REPO (default: cwd). FAILFIRST_BIN overrides the CLI command (skips the install).
set -u
BASE="" TEST_CMD="" VERSION="0.1.1"
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --test-command) TEST_CMD="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-0.1.1}"; shift 2 ;;
    *) echo "run.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$BASE" ] || { echo "run.sh: --base is required" >&2; exit 2; }

REPO="${FAILFIRST_REPO:-$PWD}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Install the CLI into a private directory and run its bin directly. `npx -p` is not used:
# when the checked-out repository is itself the fail-first-gate package, npx resolves to the
# local project, finds no linked bin, and fails with "failfirst: not found".
if [ -z "${FAILFIRST_BIN:-}" ]; then
  mkdir -p "$TMP/cli" && echo '{"name":"failfirst-runner","private":true}' > "$TMP/cli/package.json"
  if ! npm install --prefix "$TMP/cli" --no-audit --no-fund --loglevel=error "fail-first-gate@$VERSION" >/dev/null; then
    echo "run.sh: could not install fail-first-gate@$VERSION from npm" >&2; exit 2
  fi
  CLI="$TMP/cli/node_modules/fail-first-gate/bin/failfirst.js"
  [ -f "$CLI" ] || { echo "run.sh: fail-first-gate@$VERSION has no bin/failfirst.js" >&2; exit 2; }
  BIN="node $CLI"
else
  BIN="$FAILFIRST_BIN"
fi
cd "$REPO" || exit 2
# Runner settings must not leak into the project's own test command (a project whose tests
# drive FailFirst would otherwise be pointed at the wrong repository).
unset FAILFIRST_REPO FAILFIRST_BIN

# a report left by an earlier run must never stand in for this run's verdict
rm -f "$REPO/.failfirst/report.json"

CHECK_ARGS=(--base "$BASE")
[ -n "$TEST_CMD" ] && CHECK_ARGS+=(--test-cmd "$TEST_CMD")

$BIN check "${CHECK_ARGS[@]}"; check_rc=$?
$BIN scan --base "$BASE" --json > "$TMP/scan.json"; scan_rc=$?
[ -s "$TMP/scan.json" ] || echo "[]" > "$TMP/scan.json"

if ! $BIN report "$REPO/.failfirst/report.json" --scan "$TMP/scan.json" > "$TMP/report.md"; then
  printf '## FailFirst: FAIL\n\nno report was produced (check exit %s)\n' "$check_rc" > "$TMP/report.md"
fi
cat "$TMP/report.md"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$TMP/report.md" >> "$GITHUB_STEP_SUMMARY"

[ "$check_rc" -eq 0 ] && [ "$scan_rc" -eq 0 ] || exit 1
