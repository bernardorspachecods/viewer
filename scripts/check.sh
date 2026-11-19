#!/usr/bin/env bash
# Runs every check that works on this machine, in order:
#   swift build, ViewerContractRunner, ViewerFoundationRunner,
#   file and function size limits, bkf validate (repo and repo-library), swift test.
#
# Stops at the first failing step, prints the step's last output lines and a
# summary, and exits 1. Exits 0 only when every step passes.
#
#   scripts/check.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

PASSED=()
STEP_NUMBER=0

# Prints the step's final output line (its result) on success.
run_step() {
  local name="$1"
  shift
  STEP_NUMBER=$((STEP_NUMBER + 1))
  local log="$LOG_DIR/step-$STEP_NUMBER.log"
  echo "==> [$STEP_NUMBER] $name"
  "$@" >"$log" 2>&1
  local status=$?
  if [ "$status" -eq 0 ]; then
    local passes
    passes="$(grep -c '^PASS ' "$log")"
    if [ "$passes" -gt 0 ]; then
      echo "    ok: $passes checks passed"
    else
      echo "    ok: $(grep -v '^[[:space:]]*$' "$log" | tail -n 1)"
    fi
    PASSED+=("$name")
    return 0
  fi
  echo "    FAILED (exit $status): $name"
  echo "    last output:"
  tail -n 40 "$log" | sed 's/^/      | /'
  summary "$name"
  exit 1
}

summary() {
  local failed="${1:-}"
  echo
  echo "Summary: ${#PASSED[@]} passed"
  for name in "${PASSED[@]}"; do
    echo "  ok      $name"
  done
  if [ -n "$failed" ]; then
    echo "  FAILED  $failed (steps after it did not run)"
  fi
}

run_step "swift build" swift build
run_step "ViewerContractRunner" swift run ViewerContractRunner
run_step "ViewerFoundationRunner" swift run ViewerFoundationRunner
run_step "file size limit" scripts/check-file-size.sh
run_step "function size limit" scripts/check-function-size.sh
run_step "bkf validate ." bkf validate .
run_step "bkf validate repo-library" bash -c 'cd repo-library && bkf validate .'
run_step "swift test" swift test

echo
summary ""
echo "All checks passed."
