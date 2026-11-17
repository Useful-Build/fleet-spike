#!/usr/bin/env bash
# Runs the router and the task job's decisions against fixtures/ and compares the output with
# fixtures/expected.txt. Needs bash, jq and nothing else: no network, no GitHub token.
#
#   router-test.sh            compare, exit 1 and show the diff on any change
#   router-test.sh --update   rewrite expected.txt (review the diff before committing it)
#
# The clock is fixed at 2026-11-17T12:00:00Z. Scenarios: one issue per case in fixtures/issues.json
# (running, merged, in the queue, dropped from the queue, stopped, failed, past the cap, paused,
# wrong author, blocked, forged markers, two failures in a row, over 48 hours, no free slot,
# auto-merge on, a PR in the list), the fleet:stop event, another label, the task job's checks and
# its outcome classifier (usage limit with and without a reset time, error, step timeout, cancel).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fx="$here/fixtures"
expected="$fx/expected.txt"

export FLEET_FIXTURES="$fx" FLEET_NOW=1794916800 FLEET_OWNER=fleet-owner FLEET_MAX_JOBS=4 FLEET_MAX_STARTS=6
unset GITHUB_OUTPUT FLEET_EVENT_LABEL FLEET_EVENT_ISSUE

run() {
  echo "\$ $*"
  # Failing commands are part of what's tested, so record the exit code instead of stopping.
  local code=0
  "$@" 2>&1 || code=$?
  echo "[exit $code]"
  echo
}

# outcome <execution file> <agent step outcome> <issue> <minutes the agent ran>
outcome() {
  local file=$1 agent=$2 n=$3 minutes=$4
  run env EXECUTION_FILE="${file:+$fx/$file}" AGENT_OUTCOME="$agent" \
    AGENT_STARTED=$((FLEET_NOW - minutes * 60)) AGENT_TIMEOUT_MINUTES=330 \
    RUN_ID=777 SEAT=B JOB_CANCELLED=false bash "$here/task.sh" outcome "$n"
}

actual=$(
  run bash "$here/router.sh"
  run env FLEET_EVENT_LABEL=fleet:stop FLEET_EVENT_ISSUE=101 bash "$here/router.sh"
  run env FLEET_EVENT_LABEL=bug FLEET_EVENT_ISSUE=101 bash "$here/router.sh"
  run bash "$here/task.sh" check 104
  run bash "$here/task.sh" check 105
  run bash "$here/task.sh" check 107
  run bash "$here/task.sh" check 109
  run bash "$here/task.sh" seat 107
  run bash "$here/task.sh" base 104
  run bash "$here/task.sh" base 111
  outcome exec-usage-limit.json failure 111 20
  outcome exec-limit-text-only.json failure 111 20
  outcome exec-error.json failure 111 20
  outcome "" failure 111 330
  outcome "" success 111 90
  outcome exec-error.json failure 112 20
  outcome "" success 103 90
  run env RUN_ID=777 SEAT=B JOB_CANCELLED=true AGENT_OUTCOME=cancelled bash "$here/task.sh" outcome 111
)
# Paths in the output depend on where the repo is checked out.
actual=${actual//$here/.github\/fleet}

if [[ ${1:-} == --update ]]; then
  printf '%s\n' "$actual" >"$expected"
  echo "wrote $expected"
  exit 0
fi
if diff -u "$expected" <(printf '%s\n' "$actual"); then
  echo "router-test: all decisions match expected.txt"
else
  echo "router-test: decisions changed (see the diff above)" >&2
  exit 1
fi
