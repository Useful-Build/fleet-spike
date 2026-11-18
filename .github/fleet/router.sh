#!/usr/bin/env bash
# The fleet router: decides, from real GitHub state, which task issues to start, and starts them.
#
#   router.sh             act: lock and dispatch task runs, close done issues, label capped ones,
#                         open the final PR of a finished fleet/<topic> branch and start its ci
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
# writes "opened", the PR URL and "ci-failed" to files in $tmp for the caller.
final_pr_for() {
  local b=$1 sha=$2 open=$3 closed=$4 ahead merged body url
  ahead=$(api_ahead_of_main "$b")
  if ((ahead == 0)); then echo "$b final PR: not ahead of main"; return; fi
  if (($(count_naming "$b" <<<"$open") > 0)); then echo "$b final PR: not ready, an open task names it"; return; fi
  if (($(count_naming "$b" <<<"$closed") == 0)); then echo "$b final PR: not ready, no closed task names it"; return; fi
  if [[ $(api_prs_to_main "$b" | jq length) != 0 ]]; then echo "$b final PR: a PR into main is already open"; return; fi
  # The owner closed a final PR at this very commit: don't reopen it until the branch moves on.
  if api_closed_heads_to_main "$b" | jq -e --arg s "$sha" 'index($s) != null' >/dev/null; then
    echo "$b final PR: a closed PR into main has this head, not reopened"
    return
  fi
  merged=$(api_merged_into "$b" | jq -r 'map("- #\(.)") | join("\n")')
  body="Every fleet task issue for \`$b\` is closed. Task PRs merged into it:

${merged:-none}"
  echo "$b final PR: ready"
  touch "$tmp/opened"
  if [[ $DRY_RUN == 1 ]]; then
    act gh pr create -R "$FLEET_REPO" --base main --head "$b" --title "$b into main" --body "$body"
  else
    url=$(gh pr create -R "$FLEET_REPO" --base main --head "$b" --title "$b into main" --body "$body")
    [[ $url =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$ ]] || die "unexpected gh pr create output: $url"
    echo "$b final PR: opened $url"
    echo "$url" >"$tmp/url"
  fi
  # A PR opened with GITHUB_TOKEN starts no ci run by itself, and main requires ci. A dispatch is
  # the one start GITHUB_TOKEN may make, and its ci check lands on the branch's head commit.
  if ! act gh workflow run ci.yml -R "$FLEET_REPO" --ref "$b"; then
    echo "::error::$b final PR: starting ci failed. Run ci on $b by hand."
    touch "$tmp/ci-failed"
  fi
}

# The final PR: a fleet/<topic> branch whose tasks are all finished gets one PR into main.
# Ready when the branch is ahead of main, at least one closed fleet issue names it as Base, no open
# fleet issue names it (stopped and failed ones are open too), no open PR into main exists, and
# no closed, unmerged PR into main has the branch's current head. The issue lists are read fresh
# here, so a task this round closed counts as closed. Sets FINAL_URLS (space separated) and
# FINAL_COUNT.
final_prs() {
  local open closed branches b sha rc
  FINAL_URLS="" FINAL_COUNT=0
  branches=$(api_fleet_branches)
  [[ $(jq length <<<"$branches") != 0 ]] || return 0
  open=$(api_issues_after_round)
  closed=$(api_closed_issues)
  while IFS=$'\x1f' read -r b sha; do
    if [[ ! $b =~ ^fleet/[A-Za-z0-9._-]+$ ]]; then
      warn "a fleet branch name isn't of the form fleet/<topic>, skipped"
      continue
    fi
    if [[ ! $sha =~ ^[0-9a-f]{40}$ ]]; then
      warn "branch $b: head commit unreadable, skipped"
      continue
    fi
    rm -f "$tmp/opened" "$tmp/url" "$tmp/ci-failed"
    # Not inside an if: errexit must stay on in the subshell. One branch's error skips that branch.
    set +e
    # stdin closed: the loop reads the branch list from it, and no gh call may take it.
    (
      set -e
      final_pr_for "$b" "$sha" "$open" "$closed"
    ) </dev/null
    rc=$?
    set -e
    if ((rc != 0)); then
      echo "::error::$b final PR: check failed"
      failures=$((failures + 1))
      continue
    fi
    if [[ -f $tmp/opened ]]; then FINAL_COUNT=$((FINAL_COUNT + 1)); fi
    if [[ -s $tmp/url ]]; then FINAL_URLS="${FINAL_URLS:+$FINAL_URLS }$(cat "$tmp/url")"; fi
    if [[ -f $tmp/ci-failed ]]; then failures=$((failures + 1)); fi
  done < <(jq -r '.[] | "\(.name)\u001f\(.sha)"' <<<"$branches")
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
failed_tasks=""
dispatched=""
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
      printf '%s\x1f%s\x1f%s\x1f%s' "$DECISION" "$SEAT" "$PR_STATE" "$REASON"
    )
    rc=$?
    set -e
    if ((rc != 0)); then
      warn "#$n skipped this round: reading its state failed"
      continue
    fi
    IFS=$'\x1f' read -r DECISION SEAT PR_STATE REASON <<<"$line"
    if [[ $DECISION == start ]] && ((slots <= 0)); then
      DECISION=skip-full REASON="no free job slot"
    fi
    echo "#$n $DECISION pr=$PR_STATE: $REASON"
    case $DECISION in
      start)
        [[ $SEAT =~ ^[abc]$ ]] || die "bad seat '$SEAT' for #$n"
        # Strangers can't comment on a locked issue, so nothing they write reaches the agent there.
        if [[ $(jq -r .locked <<<"$issue") != true ]]; then
          try_act gh api -X PUT "repos/$FLEET_REPO/issues/$n/lock" --silent || continue
        fi
        # The REST dispatch returns the new run's id (workflow_run_id), so the round can wait for
        # that run to show in the run list below.
        if [[ $DRY_RUN == 1 ]]; then
          if try_act gh api -X POST "repos/$FLEET_REPO/actions/workflows/fleet.yml/dispatches" \
            -f ref=main -f "inputs[issue]=$n" -f "inputs[seat]=$SEAT"; then
            slots=$((slots - 1))
            started=$((started + 1))
          fi
        elif run_id=$(gh api -X POST "repos/$FLEET_REPO/actions/workflows/fleet.yml/dispatches" \
          -f ref=main -f "inputs[issue]=$n" -f "inputs[seat]=$SEAT" --jq .workflow_run_id); then
          slots=$((slots - 1))
          started=$((started + 1))
          if [[ $run_id =~ ^[0-9]+$ ]]; then
            echo "#$n started run $run_id"
            dispatched+="$n $run_id"$'\n'
          else
            echo "::error::#$n: the dispatch returned no run id, so this round can't wait for its run"
            failures=$((failures + 1))
          fi
        else
          echo "::error::failed: dispatch task #$n"
          failures=$((failures + 1))
        fi
        ;;
      done)
        if ! comment_on "$n" "Done: the PR from task/$n has merged." "$(jq -r .locked <<<"$issue")"; then
          echo "::error::failed: comment on #$n"
          failures=$((failures + 1))
        fi
        try_act gh issue close "$n" -R "$FLEET_REPO" || true
        ;;
      failed-cap)
        # The outcome job alerts for the caps it applies. These are the ones it left: a start cap
        # reached while the PR was set to merge, then dropped, or a label that failed there.
        if try_act gh issue edit "$n" -R "$FLEET_REPO" --add-label fleet:failed; then
          failed_tasks="${failed_tasks:+$failed_tasks }$n"
        fi
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
  if [[ -n $failed_tasks ]]; then emit failed_tasks "$failed_tasks"; fi
  # Rounds run one at a time, so a round that ends only once its runs are listed can't be
  # followed by one that misses them and starts the same task again.
  if [[ $DRY_RUN == 1 ]] && ((started > 0)); then
    echo "would wait for the $started started runs to show in the run list"
  elif [[ -n $dispatched ]]; then
    wait_for_runs "$dispatched"
    failures=$((failures + WAIT_MISSING))
  fi
fi

final_prs
if [[ -n $FINAL_URLS ]]; then emit final_prs "$FINAL_URLS"; fi
if [[ $(jq length <<<"$issues") == 0 && $FINAL_COUNT == 0 ]]; then
  echo "nothing to do"
fi
if ((failures > 0)); then die "$failures changes failed"; fi
