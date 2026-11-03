#!/usr/bin/env bash
# FailFirst verdict: check + scan + Markdown report.
# Usage: run.sh --base <ref> [--test-command <cmd>] [--version <fail-first-gate version>]
# Runs against $FAILFIRST_REPO (default: cwd). FAILFIRST_BIN overrides the CLI command.
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

BIN="${FAILFIRST_BIN:-npx -y -p fail-first-gate@$VERSION failfirst}"
REPO="${FAILFIRST_REPO:-$PWD}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$REPO" || exit 2

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
