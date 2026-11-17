#!/usr/bin/env bash
# Runs the router and the task and outcome steps against fixtures/ and compares what they decide
# and what they would change with fixtures/expected.txt. Needs bash, jq and nothing else: no
# network, no GitHub token.
#
#   router-test.sh   compare, exit 1 and show the diff on any difference
#
# expected.txt is written by hand from the rules (starts and caps, the PR states, the final PR),
# never generated from this code's output. There is deliberately no option to rewrite it: a test
# that blesses whatever the code prints can't catch a wrong decision. When a rule changes, edit
# expected.txt by hand from the rule first, then change the code until this passes.
#
# Decision lines are compared without their free-text reason ("#104 start", not
# "#104 start: unfinished, ..."): the decision and the commands are what's under test.
# The clock is fixed at 2026-11-17T12:00:00Z. One issue per case in fixtures/issues.json:
#   101 running            102 merged               103 in the merge queue
#   104 auto-merge on, checks failed                105 stopped, with a queued run
#   106 fleet:failed       107 auto-merge on, checks passing
#   108 ready, checks pending, no auto-merge        109 written by someone else
#   110 blocked            111 ready, auto-merge off, passing, not queued (dropped from the queue)
#   112 closed-only PR     113 fork PR named task/113, open, not draft; forged markers
#   114 PR into the wrong base                      115 exactly 5 starts, done among them
#   116 6 starts, done among them                   117 one failed; no Base line
#   118 failed, progress, failed                    119 failed, paused, failed
#   120 paused, retry_after past   121 paused, retry_after empty   122 paused, impossible date
#   123 paused, retry_after future 124 null user    125 owner login in another case, locked
#   126 draft PR           127 merged but stopped   128 a PR in the issue list
#   129 its API reads fail 130 no free job slot
# final.json: fleet/done ready, fleet/demo has open tasks, fleet/has-pr has a PR into main,
# fleet/empty isn't ahead of main.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fx="$here/fixtures"
expected="$fx/expected.txt"

[[ $# == 0 ]] || { echo "usage: router-test.sh (no options; edit expected.txt by hand)" >&2; exit 2; }

export FLEET_FIXTURES="$fx" FLEET_NOW=1794916800 FLEET_OWNER=fleet-owner FLEET_MAX_JOBS=16 FLEET_MAX_STARTS=6
unset GITHUB_OUTPUT FLEET_EVENT_LABEL FLEET_EVENT_ISSUE FLEET_STOP_ALL

run() {
  echo "\$ $*"
  # Failing commands are part of what's tested, so record the exit code instead of stopping.
  local code=0
  "$@" 2>&1 || code=$?
  echo "[exit $code]"
  echo
}

# usage <execution file>
usage() {
  run env EXECUTION_FILE="${1:+$fx/$1}" bash "$here/task.sh" usage 104
}

# outcome <issue> <task result> <checkout ran> <agent> <paused> <retry_after> <minutes since start>
outcome() {
  run env TASK_RESULT="$2" CHECKOUT_RAN="$3" AGENT_OUTCOME="$4" PAUSED="$5" RETRY_AFTER="$6" \
    STARTED="${7:+$((FLEET_NOW - ${7:-0} * 60))}" AGENT_TIMEOUT_MINUTES=330 RUN_ID=777 SEAT=b \
    bash "$here/task.sh" outcome "$1"
}

actual=$(
  run bash "$here/router.sh"
  run env FLEET_EVENT_LABEL=fleet:stop FLEET_EVENT_ISSUE=101 bash "$here/router.sh"
  run env FLEET_EVENT_LABEL=bug FLEET_EVENT_ISSUE=101 bash "$here/router.sh"
  run env FLEET_STOP_ALL=true bash "$here/router.sh"
  run bash "$here/task.sh" check 104
  run bash "$here/task.sh" check 105
  run bash "$here/task.sh" check 116
  run bash "$here/task.sh" check 124
  run bash "$here/task.sh" base 104
  run bash "$here/task.sh" base 117
  run env BASE=fleet/demo bash "$here/task.sh" pr-state 107
  usage exec-usage-limit.json
  usage exec-limit-text-only.json
  usage exec-error.json
  usage exec-overage.json
  usage exec-overage-last.json
  usage exec-bad.json
  usage ""
  outcome 107 success true success false "" 60
  outcome 117 success true failure false "" 20
  outcome 115 success true success false "" 60
  outcome 121 success true failure true 2027-01-01T00:00:00Z 20
  outcome 121 success true failure true 2026-13-45T99:99:99Z 20
  outcome 121 success true failure true 2026-11-17T15:00:00Z 20
  outcome 120 failure "" "" "" "" ""
  outcome 120 skipped "" "" "" "" ""
  outcome 120 cancelled true cancelled false "" 30
  outcome 120 success false "" "" "" 1
  outcome 120 success true failure false "" 331
)
# Paths in the output depend on where the repo is checked out. Reasons are dropped (see above).
actual=${actual//$here/.github\/fleet}
actual=$(sed -E 's/^(#[0-9]+ [a-z-]+): .*/\1/' <<<"$actual")

if diff -u "$expected" <(printf '%s\n' "$actual"); then
  echo "router-test: all decisions match expected.txt"
else
  echo "router-test: decisions differ from expected.txt (see the diff above)" >&2
  exit 1
fi
