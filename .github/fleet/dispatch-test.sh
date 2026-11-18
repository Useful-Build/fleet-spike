#!/usr/bin/env bash
# Runs router.sh on its live path (no FLEET_FIXTURES, no dry run) against a stub gh and a stub
# sleep put first on PATH, and checks what it sends and how it handles the answers. Needs bash and
# jq, no network, no GitHub token.
#
#   dispatch-test.sh   run every case, exit 1 on the first difference
#
# The expected results below are written by hand from the rules, never copied from the output:
# - The dispatch sends return_run_details as a JSON boolean (-F). Like GitHub, the stub answers
#   200 with the run id only when it's there, and 204 with no body otherwise.
# - A dispatch with no numeric run id is an error naming the task, and the round ends red.
# - A failed dispatch is counted, the loop carries on, the runs already started are still waited
#   for, and failed_tasks and final_prs are still written before the round ends red.
# - A run that isn't in the run list after 60 seconds, and hasn't finished, is an error naming the
#   task, and the round ends red. The wait polls every 5 seconds: 13 reads, 12 sleeps.
# - A run that has already finished ends its wait at once.
# - A task that got fleet:stop after the round read the issues isn't started.
# - The active runs are read with one REST request per status (queued, in_progress, waiting,
#   pending, requested).
# - A run list that fails while waiting is a warning naming the task, then the run counts as
#   missing, and the outputs are still written.
# Seats: no markers, so the seat is "abc"[issue number mod 3].
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
[[ $# == 0 ]] || { echo "usage: dispatch-test.sh (no options)" >&2; exit 2; }

mkdir "$tmp/bin"
cat >"$tmp/bin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "sleep $*" >>"$STUB/calls.log"
EOF
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Stub gh. Answers from the files in $STUB and logs every call to $STUB/calls.log.
set -euo pipefail
d=$STUB R=fixture/repo
echo "$*" >>"$d/calls.log"
or_default() { if [[ -f $1 ]]; then cat "$1"; else echo "$2"; fi; }
unexpected() { echo "stub gh: unexpected call: $*" >&2; exit 97; }
case "$1 ${2:-}" in
  "issue edit") exit 0 ;;
  "pr create") echo "https://github.com/$R/pull/300"; exit 0 ;;
  "api "*) shift ;;
  *) unexpected "$@" ;;
esac
case "$*" in
  "--paginate --slurp repos/$R/actions/workflows/fleet.yml/runs?status="*"&exclude_pull_requests=true&per_page=100")
    # One read of the active runs asks for each status in turn, queued first, one page each. Each
    # line of $STUB/runs is "id|title|status|n": the run is listed from the n-th read on.
    # list-fail-from: the n-th read and every one after it fail.
    status=${3#*status=}
    status=${status%%&*}
    if [[ $status == queued ]]; then echo $(($(or_default "$d/list-count" 0) + 1)) >"$d/list-count"; fi
    c=$(cat "$d/list-count")
    if [[ -f $d/list-fail-from ]] && ((c >= $(cat "$d/list-fail-from"))); then echo "stub: HTTP 502" >&2; exit 1; fi
    or_default "$d/runs" "" | jq -Rn --arg s "$status" --argjson c "$c" '[inputs | select(length > 0)
      | split("|") | select(.[2] == $s and (.[3] | tonumber) <= $c)
      | {id: (.[0] | tonumber), display_title: .[1], status: .[2]}]
      | [{total_count: length, workflow_runs: .}]'
    ;;
  "--paginate --slurp repos/$R/issues?state=open&labels=fleet&per_page=100") printf '[%s]\n' "$(cat "$d/issues.json")" ;;
  "--paginate --slurp repos/$R/issues?state=closed&labels=fleet&per_page=100") printf '[%s]\n' "$(or_default "$d/closed.json" '[]')" ;;
  "--paginate --slurp repos/$R/git/matching-refs/heads/fleet/?per_page=100") printf '[%s]\n' "$(or_default "$d/branches.json" '[]')" ;;
  "--paginate --slurp repos/$R/pulls?"*) echo '[[]]' ;;
  "--paginate --slurp repos/$R/issues/"*"/dependencies/blocked_by?per_page=100") echo '[[]]' ;;
  "--paginate --slurp repos/$R/issues/"*"/comments?per_page=100")
    n=${3#repos/"$R"/issues/}
    printf '[%s]\n' "$(or_default "$d/comments-${n%%/*}.json" '[]')"
    ;;
  "-X PUT repos/$R/issues/"*"/lock --silent") ;;
  "-X POST repos/$R/actions/workflows/ci.yml/dispatches -f ref="*" --silent") ;;
  "-X POST repos/$R/actions/workflows/fleet.yml/dispatches "*)
    n="" details=false prev=""
    for a in "$@"; do
      if [[ $a == "inputs[issue]="* ]]; then n=${a#"inputs[issue]="}; fi
      if [[ $prev == -F && $a == return_run_details=true ]]; then details=true; fi
      prev=$a
    done
    answer=$(cat "$d/dispatch-$n")
    if [[ $answer == FAIL ]]; then echo "stub: HTTP 422" >&2; exit 1; fi
    # 204 No Content unless the run's details were asked for.
    if [[ $details == true ]]; then printf '%s' "$answer"; fi
    ;;
  "repos/$R/actions/runs/"*" --jq .status")
    id=${1#repos/"$R"/actions/runs/}
    [[ -f $d/run-$id.status ]] || { echo "stub: HTTP 404" >&2; exit 1; }
    cat "$d/run-$id.status"
    ;;
  "repos/$R/compare/main..."*" --jq .ahead_by") cat "$d/ahead" ;;
  "repos/$R/issues/"*)
    n=${1#repos/"$R"/issues/}
    if [[ -f $d/issue-$n.json ]]; then cat "$d/issue-$n.json"; else jq -e --argjson n "$n" '.[] | select(.number == $n)' "$d/issues.json"; fi
    ;;
  *) unexpected api "$@" ;;
esac
EOF
chmod +x "$tmp/bin/gh" "$tmp/bin/sleep"

# issue <number> [extra label]: an open, locked fleet issue by the owner, with no Base line.
issue() {
  jq -nc --argjson n "$1" --arg l "${2:-}" '{number: $n, state: "open", locked: true,
    user: {login: "fleet-owner"}, created_at: "2026-11-17T10:00:00Z", body: "brief",
    labels: ([{name: "fleet"}] + (if $l == "" then [] else [{name: $l}] end))}'
}
ok() { printf '{"workflow_run_id":%s,"run_url":"https://api.github.com/repos/fixture/repo/actions/runs/%s","html_url":"https://github.com/fixture/repo/actions/runs/%s"}' "$1" "$1" "$1"; }
# A branch fleet/x that is ready for its final PR: ahead of main, named by a closed task only.
final_ready() {
  echo '[{"ref": "refs/heads/fleet/x", "object": {"sha": "1111111111111111111111111111111111111111"}}]' >"$STUB/branches.json"
  echo 2 >"$STUB/ahead"
  echo '[{"number": 200, "state": "closed", "body": "Base: fleet/x", "labels": [{"name": "fleet"}]}]' >"$STUB/closed.json"
}

fails=0 name="" out="" code=0
# scenario <name>: a fresh stub directory.
scenario() {
  name=$1
  export STUB="$tmp/$name"
  mkdir "$STUB"
  : >"$STUB/calls.log"
}
route() {
  code=0
  out=$(env -u FLEET_FIXTURES -u FLEET_EVENT_LABEL -u FLEET_EVENT_ISSUE -u FLEET_STOP_ALL -u FLEET_AFTER_RUN \
    PATH="$tmp/bin:$PATH" FLEET_REPO=fixture/repo FLEET_OWNER=fleet-owner FLEET_NOW=1794916800 \
    GITHUB_OUTPUT="$STUB/output" bash "$here/router.sh" 2>&1) || code=$?
}
fail() {
  echo "dispatch-test: $name: $*" >&2
  fails=$((fails + 1))
}
want_exit() { [[ $code == "$1" ]] || fail "exit $code, want $1"; }
want_out() { grep -qxF -- "$1" <<<"$out" || fail "no output line: $1"; }
want_call() { grep -qxF -- "$1" "$STUB/calls.log" || fail "no call: gh $1"; }
want_no_call() { if grep -qF -- "$1" "$STUB/calls.log"; then fail "unwanted call: $1"; fi; }
want_sleeps() {
  local n
  n=$(grep -c '^sleep 5$' "$STUB/calls.log" || true)
  [[ $n == "$1" ]] || fail "$n sleeps, want $1"
}
want_output() { grep -qxF -- "$1" "$STUB/output" 2>/dev/null || fail "no step output: $1"; }
dispatch_call() { echo "api -X POST repos/fixture/repo/actions/workflows/fleet.yml/dispatches -f ref=main -F return_run_details=true -f inputs[issue]=$1 -f inputs[seat]=$2"; }
done_case() {
  if ((fails > 0)); then
    printf '%s\n' "--- output of $name:" "$out" "--- calls:" >&2
    cat "$STUB/calls.log" >&2
    exit 1
  fi
  echo "ok: $name"
}

# The request carries return_run_details, the answer has the id, and the run shows on the second
# poll: one sleep.
scenario id
issue 201 | jq -s . >"$STUB/issues.json"
ok 5001 >"$STUB/dispatch-201"
echo "5001|task #201|queued|3" >"$STUB/runs"
echo queued >"$STUB/run-5001.status"
route
want_call "$(dispatch_call 201 a)"
want_out "#201 started run 5001"
want_out "#201 run 5001 is in the run list"
# One request per active status, each the REST list itself, not gh run list.
for s in queued in_progress waiting pending requested; do
  want_call "api --paginate --slurp repos/fixture/repo/actions/workflows/fleet.yml/runs?status=$s&exclude_pull_requests=true&per_page=100"
done
want_sleeps 1
want_exit 0
done_case

# 204 with no body: an error naming the task, no wait, red.
scenario no-id
issue 202 | jq -s . >"$STUB/issues.json"
: >"$STUB/dispatch-202"
route
want_call "$(dispatch_call 202 b)"
want_out "::error::#202: the dispatch returned no run id, so this round can't wait for its run"
want_sleeps 0
want_out "fleet: 1 changes failed"
want_exit 1
done_case

# Four tasks: 211 starts, 212's dispatch fails, 213 starts, 214 is past its cap. Both started runs
# are waited for, failed_tasks and final_prs are written, and the round is red for 212 alone.
scenario mid-round
{
  issue 211
  issue 212
  issue 213
  issue 214
} | jq -s . >"$STUB/issues.json"
ok 5011 >"$STUB/dispatch-211"
echo FAIL >"$STUB/dispatch-212"
ok 5013 >"$STUB/dispatch-213"
for r in 1 2 3 4 5 6; do
  jq -n --argjson r "$r" '{user: {login: "github-actions[bot]", type: "Bot"},
    created_at: "2026-11-17T0\($r):00:00Z",
    body: "<!-- fleet:attempt run=\($r) seat=a outcome=progress retry_after= -->\nRun \($r)"}'
done | jq -s . >"$STUB/comments-214.json"
printf '%s\n' "5011|task #211|in_progress|2" "5013|task #213|queued|3" >"$STUB/runs"
echo queued >"$STUB/run-5013.status"
final_ready
route
want_call "$(dispatch_call 211 b)"
want_call "$(dispatch_call 212 c)"
want_call "$(dispatch_call 213 a)"
want_no_call "inputs[issue]=214"
want_out "::error::failed: dispatch task #212"
want_call "issue edit 214 -R fixture/repo --add-label fleet:failed"
want_out "#211 run 5011 is in the run list"
want_out "#213 run 5013 is in the run list"
want_sleeps 1
want_output "failed_tasks=214"
want_output "final_prs=https://github.com/fixture/repo/pull/300"
want_out "fleet: 1 changes failed"
want_exit 1
done_case

# The run never shows and hasn't finished: 13 reads, 12 sleeps, an error naming the task, red.
scenario never-listed
issue 221 | jq -s . >"$STUB/issues.json"
ok 5021 >"$STUB/dispatch-221"
echo in_progress >"$STUB/run-5021.status"
route
want_call "$(dispatch_call 221 c)"
want_sleeps 12
want_out "::error::#221: its run 5021 isn't in the run list after 60s and hasn't finished, so the next round may start task #221 again"
want_out "fleet: 1 changes failed"
want_exit 1
done_case

# The run isn't listed but has already finished: no sleep, green.
scenario finished
issue 231 | jq -s . >"$STUB/issues.json"
ok 5031 >"$STUB/dispatch-231"
echo completed >"$STUB/run-5031.status"
route
want_call "$(dispatch_call 231 a)"
want_out "#231 run 5031 has finished"
want_sleeps 0
want_exit 0
done_case

# fleet:stop arrived after the round read the issue list: no dispatch.
scenario stopped-meanwhile
issue 241 | jq -s . >"$STUB/issues.json"
issue 241 fleet:stop >"$STUB/issue-241.json"
route
want_no_call "dispatches"
want_out "#241 got fleet:stop during this round, not started"
want_exit 0
done_case

# Every run list read after the round's own fails: a warning naming the task each time, then the
# run is missing, the final PR output is still written, red.
scenario list-fails
issue 251 | jq -s . >"$STUB/issues.json"
ok 5051 >"$STUB/dispatch-251"
echo in_progress >"$STUB/run-5051.status"
echo 2 >"$STUB/list-fail-from"
final_ready
route
want_call "$(dispatch_call 251 c)"
want_out "::warning::listing runs failed while waiting for #251, trying again"
want_out "::error::#251: its run 5051 isn't in the run list after 60s and hasn't finished, so the next round may start task #251 again"
want_sleeps 12
want_output "final_prs=https://github.com/fixture/repo/pull/300"
want_out "fleet: 1 changes failed"
want_exit 1
done_case

echo "dispatch-test: all cases match"
