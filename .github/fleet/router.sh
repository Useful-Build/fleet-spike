#!/usr/bin/env bash
# The fleet router: decides, from real GitHub state, which task issues to start, and starts them.
#
#   router.sh             act: lock and dispatch task runs, close done issues, label capped ones,
#                         open the final PR of a finished fleet/<topic> branch
#   router.sh --dry-run   print every decision and the commands it would run, change nothing
#
# Env: FLEET_OWNER (required), FLEET_MAX_JOBS (16), FLEET_MAX_STARTS (6), FLEET_REPO (from the
# checkout), FLEET_EVENT_LABEL and FLEET_EVENT_ISSUE (the label event that started the run, if any),
# FLEET_STOP_ALL=true (stop every task and exit). FLEET_FIXTURES=<dir> reads fixture JSON instead
# of the API and implies --dry-run. FLEET_NOW fixes the clock (epoch seconds). The failure list
# this answers is FAILURES.md next to this file.
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

failures=0
# Runs a change for one issue. A failure is logged and counted, and the round carries on.
try_act() {
  if ! act "$@"; then
    echo "::error::failed: $*"
    failures=$((failures + 1))
    return 1
  fi
}

# Cancels every active run of one task.
cancel_task_runs() {
  local n=$1 active=$2 ids id
  ids=$(jq -r --arg t "task #$n" '.[] | select(.displayTitle == $t) | .databaseId' <<<"$active")
  for id in $ids; do
    echo "#$n stop: cancel run $id"
    try_act gh run cancel "$id" -R "$FLEET_REPO" || true
  done
  if [[ -z $ids ]]; then echo "#$n stop: no active run"; fi
}

# Stop all: fleet:stop on every open fleet issue, then cancel every task run.
stop_all() {
  local issues active n ids id
  issues=$(api_issues)
  for n in $(jq -r '.[].number' <<<"$issues"); do
    if has_label "$(jq -c --argjson n "$n" '.[] | select(.number == $n)' <<<"$issues")" fleet:stop; then
      echo "#$n stop all: already stopped"
    else
      echo "#$n stop all: add fleet:stop"
      try_act gh issue edit "$n" -R "$FLEET_REPO" --add-label fleet:stop || true
    fi
  done
  active=$(api_active_runs)
  ids=$(jq -r '.[] | select(.displayTitle | test("^task #[0-9]+$")) | "\(.databaseId) \(.displayTitle)"' <<<"$active")
  while read -r id _; do
    [[ -n $id ]] || continue
    echo "stop all: cancel run $id"
    try_act gh run cancel "$id" -R "$FLEET_REPO" || true
  done <<<"$ids"
  echo "stop all: done"
}

# Prints how many open or closed issues (JSON on stdin) name branch $1 in their Base line.
count_naming() {
  jq --arg b "$1" '[.[] | select(((.body // "") | split("\n") | map(sub("\r$"; ""))
    | map(capture("^Base: (?<b>fleet/[A-Za-z0-9._-]+)\\s*$").b) | first // "") == $b)] | length'
}

# Checks one fleet/<topic> branch and opens its final PR when it's ready. Runs in a subshell:
# writes "opened" and the PR URL to files in $tmp for the caller.
final_pr_for() {
  local b=$1 open=$2 closed=$3 ahead merged body url
  ahead=$(api_ahead_of_main "$b")
  if ((ahead == 0)); then echo "$b final PR: not ahead of main"; return; fi
  if (($(count_naming "$b" <<<"$open") > 0)); then echo "$b final PR: not ready, an open task names it"; return; fi
  if (($(count_naming "$b" <<<"$closed") == 0)); then echo "$b final PR: not ready, no closed task names it"; return; fi
  if [[ $(api_prs_to_main "$b" | jq length) != 0 ]]; then echo "$b final PR: a PR into main is already open"; return; fi
  merged=$(api_merged_into "$b" | jq -r 'map("- #\(.)") | join("\n")')
  body="Every fleet task issue for \`$b\` is closed. Task PRs merged into it:

${merged:-none}"
  echo "$b final PR: ready"
  touch "$tmp/opened"
  if [[ $DRY_RUN == 1 ]]; then
    act gh pr create -R "$FLEET_REPO" --base main --head "$b" --title "$b into main" --body "$body"
    return
  fi
  url=$(gh pr create -R "$FLEET_REPO" --base main --head "$b" --title "$b into main" --body "$body")
  [[ $url =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$ ]] || die "unexpected gh pr create output: $url"
  echo "$b final PR: opened $url"
  echo "$url" >"$tmp/url"
}

# The final PR: a fleet/<topic> branch whose tasks are all finished gets one PR into main.
# Ready when the branch is ahead of main, at least one closed fleet issue names it as Base, no open
# fleet issue names it (stopped and failed ones are open too), and no open PR into main exists.
# Sets FINAL_URLS (space separated) and FINAL_COUNT.
final_prs() {
  local open=$1 closed branches b rc
  FINAL_URLS="" FINAL_COUNT=0
  branches=$(api_fleet_branches)
  [[ $(jq length <<<"$branches") != 0 ]] || return 0
  closed=$(api_closed_issues)
  for b in $(jq -r '.[]' <<<"$branches"); do
    if [[ ! $b =~ ^fleet/[A-Za-z0-9._-]+$ ]]; then
      warn "branch $b: name not of the form fleet/<topic>, skipped"
      continue
    fi
    rm -f "$tmp/opened" "$tmp/url"
    # Not inside an if: errexit must stay on in the subshell. One branch's error skips that branch.
    set +e
    (
      set -e
      final_pr_for "$b" "$open" "$closed"
    )
    rc=$?
    set -e
    if ((rc != 0)); then
      echo "::error::$b final PR: check failed"
      failures=$((failures + 1))
      continue
    fi
    if [[ -f $tmp/opened ]]; then FINAL_COUNT=$((FINAL_COUNT + 1)); fi
    if [[ -s $tmp/url ]]; then FINAL_URLS="${FINAL_URLS:+$FINAL_URLS }$(cat "$tmp/url")"; fi
  done
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ ${FLEET_STOP_ALL:-false} == true ]]; then
  stop_all
  if ((failures > 0)); then die "$failures changes failed"; fi
  exit 0
fi

case ${FLEET_EVENT_LABEL:-} in
  "" | fleet) ;;
  fleet:stop)
    n=${FLEET_EVENT_ISSUE:-}
    is_number "$n" || die "fleet:stop event without an issue number"
    cancel_task_runs "$n" "$(api_active_runs)"
    if ((failures > 0)); then die "$failures changes failed"; fi
    exit 0
    ;;
  *)
    echo "label ${FLEET_EVENT_LABEL}: nothing to do"
    exit 0
    ;;
esac

issues=$(api_issues)
started=0
if [[ $(jq length <<<"$issues") != 0 ]]; then
  active=$(api_active_runs)
  running=$(jq '[.[] | select(.displayTitle | test("^task #[0-9]+$"))] | length' <<<"$active")
  slots=$((FLEET_MAX_JOBS - running))
  echo "task runs active: $running, cap $FLEET_MAX_JOBS"

  for n in $(jq -r '.[].number' <<<"$issues"); do
    issue=$(jq -c --argjson n "$n" '.[] | select(.number == $n)' <<<"$issues")
    # Each issue is decided in its own subshell, so an API error or a bad value in one issue skips
    # that issue with a warning and the round carries on.
    # Not inside an if: errexit must stay on in the subshell.
    set +e
    line=$(
      set -e
      decide "$n" "$issue" "$active"
      # \x1f, not a tab: read collapses runs of whitespace separators, and SEAT is often empty.
      printf '%s\x1f%s\x1f%s' "$DECISION" "$SEAT" "$REASON"
    )
    rc=$?
    set -e
    if ((rc != 0)); then
      warn "#$n skipped this round: reading its state failed"
      continue
    fi
    IFS=$'\x1f' read -r DECISION SEAT REASON <<<"$line"
    if [[ $DECISION == start ]] && ((slots <= 0)); then
      DECISION=skip-full REASON="no free job slot"
    fi
    echo "#$n $DECISION: $REASON"
    case $DECISION in
      start)
        [[ $SEAT =~ ^[abc]$ ]] || die "bad seat '$SEAT' for #$n"
        # Strangers can't comment on a locked issue, so nothing they write reaches the agent there.
        if [[ $(jq -r .locked <<<"$issue") != true ]]; then
          try_act gh api -X PUT "repos/$FLEET_REPO/issues/$n/lock" --silent || continue
        fi
        if try_act gh workflow run fleet.yml -R "$FLEET_REPO" -f "issue=$n" -f "seat=$SEAT"; then
          slots=$((slots - 1))
          started=$((started + 1))
        fi
        ;;
      done)
        try_act gh issue close "$n" -R "$FLEET_REPO" --comment "Done: the PR from task/$n has merged." || true
        ;;
      failed-cap)
        try_act gh issue edit "$n" -R "$FLEET_REPO" --add-label fleet:failed || true
        ;;
      skip-stopped)
        # A stop event's run can fail or race a round, so every round also cancels whatever a
        # stopped task still has running.
        if jq -e --arg t "task #$n" 'any(.[]; .displayTitle == $t)' <<<"$active" >/dev/null; then
          cancel_task_runs "$n" "$active"
        fi
        ;;
    esac
  done
  echo "started: $started"
fi

final_prs "$issues"
if [[ -n $FINAL_URLS ]]; then emit final_prs "$FINAL_URLS"; fi
if [[ $(jq length <<<"$issues") == 0 && $FINAL_COUNT == 0 ]]; then
  echo "nothing to do"
fi
if ((failures > 0)); then die "$failures changes failed"; fi
