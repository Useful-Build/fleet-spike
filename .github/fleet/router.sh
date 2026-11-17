#!/usr/bin/env bash
# The fleet router: decides, from real GitHub state, which task issues to start, and starts them.
#
#   router.sh             act: dispatch task runs, close done issues, label capped ones
#   router.sh --dry-run   print every decision and the commands it would run, change nothing
#
# Env: FLEET_OWNER (required), FLEET_MAX_JOBS (16), FLEET_MAX_STARTS (6), FLEET_REPO (from the
# checkout), FLEET_EVENT_LABEL and FLEET_EVENT_ISSUE (the label event that started the run, if any).
# FLEET_FIXTURES=<dir> reads fixture JSON instead of the API and implies --dry-run. FLEET_NOW fixes
# the clock (epoch seconds). The failure list this answers is FAILURES.md next to this file.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "$here/lib.sh"

DRY_RUN=0
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=1 ;;
    *) die "unknown argument: $arg (usage: router.sh [--dry-run])" ;;
  esac
done
fleet_init

# Cancels every active run of one task.
cancel_task_runs() {
  local n=$1 active=$2 ids id
  ids=$(jq -r --arg t "task #$n" '.[] | select(.displayTitle == $t) | .databaseId' <<<"$active")
  for id in $ids; do
    echo "#$n stop: cancel run $id"
    act gh run cancel "$id" -R "$FLEET_REPO"
  done
  if [[ -z $ids ]]; then echo "#$n stop: no active run"; fi
}

case ${FLEET_EVENT_LABEL:-} in
  "" | fleet) ;;
  fleet:stop)
    n=${FLEET_EVENT_ISSUE:-}
    is_number "$n" || die "fleet:stop event without an issue number"
    cancel_task_runs "$n" "$(api_active_runs)"
    exit 0
    ;;
  *)
    echo "label ${FLEET_EVENT_LABEL}: nothing to do"
    exit 0
    ;;
esac

issues=$(api_issues)
if [[ $(jq length <<<"$issues") == 0 ]]; then
  echo "nothing to do"
  exit 0
fi

active=$(api_active_runs)
running=$(jq '[.[] | select(.displayTitle | test("^task #[0-9]+$"))] | length' <<<"$active")
slots=$((FLEET_MAX_JOBS - running))
echo "task runs active: $running, cap $FLEET_MAX_JOBS"

failures=0
started=0
for n in $(jq -r '.[].number' <<<"$issues"); do
  issue=$(jq -c --argjson n "$n" '.[] | select(.number == $n)' <<<"$issues")
  decide "$n" "$issue" "$active"
  if [[ $DECISION == start ]] && ((slots <= 0)); then
    DECISION=skip-full REASON="no free job slot"
  fi
  echo "#$n $DECISION: $REASON"
  case $DECISION in
    start)
      if act gh workflow run fleet.yml -R "$FLEET_REPO" -f "issue=$n"; then
        slots=$((slots - 1))
        started=$((started + 1))
      else
        echo "::error::#$n dispatch failed"
        failures=$((failures + 1))
      fi
      ;;
    done)
      act gh issue close "$n" -R "$FLEET_REPO" --comment "Done: the PR from task/$n has merged."
      ;;
    failed-cap)
      act gh issue edit "$n" -R "$FLEET_REPO" --add-label fleet:failed
      ;;
    skip-stopped)
      # The stop event's own run can be dropped by the router's concurrency group, so every round
      # also cancels whatever a stopped task still has running.
      if jq -e --arg t "task #$n" 'any(.[]; .displayTitle == $t)' <<<"$active" >/dev/null; then
        cancel_task_runs "$n" "$active"
      fi
      ;;
  esac
done

echo "started: $started"
if ((failures > 0)); then die "$failures dispatches failed"; fi
