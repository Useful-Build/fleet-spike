# shellcheck shell=bash
# Shared by router.sh and task.sh. Sourced, never run on its own.
#
# Every GitHub read goes through an api_* function. With FLEET_FIXTURES set to a directory they read
# JSON files from it instead (same shapes the API returns), and FLEET_NOW fixes the clock, so the
# decisions can be tested without a network. See router-test.sh and classify-test.sh.
#
# Issue text never reaches the shell: JSON is read with jq, and only numbers, label names, logins
# and the validated base branch name come out of it.

MARKER_BOT="github-actions[bot]"
ACTIVE_STATUSES="queued in_progress waiting pending requested"
# A paused marker never asks to wait longer than this, whatever the task job claims.
MAX_PAUSE_SECONDS=$((8 * 24 * 3600))

die() {
  echo "fleet: $*" >&2
  exit 1
}

warn() { echo "::warning::$*"; }

is_number() { [[ $1 =~ ^[1-9][0-9]{0,9}$ ]]; }

fleet_init() {
  : "${FLEET_OWNER:?FLEET_OWNER is not set. Set the repo variable FLEET_OWNER to the login whose issues may start tasks.}"
  FLEET_MAX_JOBS=${FLEET_MAX_JOBS:-16}
  FLEET_MAX_STARTS=${FLEET_MAX_STARTS:-6}
  is_number "$FLEET_MAX_JOBS" || die "FLEET_MAX_JOBS must be a positive whole number"
  is_number "$FLEET_MAX_STARTS" || die "FLEET_MAX_STARTS must be a positive whole number"
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    [[ -d $FLEET_FIXTURES ]] || die "FLEET_FIXTURES is not a directory: $FLEET_FIXTURES"
    FLEET_REPO=${FLEET_REPO:-fixture/repo}
    DRY_RUN=1
  else
    FLEET_REPO=${FLEET_REPO:-${GITHUB_REPOSITORY:-}}
    if [[ -z $FLEET_REPO ]]; then
      FLEET_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
    fi
  fi
  [[ $FLEET_REPO =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "bad repo name: $FLEET_REPO"
  NOW=${FLEET_NOW:-$(date -u +%s)}
}

# Runs a command that changes GitHub, or only prints it in a dry run.
act() {
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    echo "  would run: $*"
  else
    "$@"
  fi
}

# Writes a step output in Actions, and always echoes it.
emit() {
  echo "$1=$2"
  if [[ -n ${GITHUB_OUTPUT:-} ]]; then echo "$1=$2" >>"$GITHUB_OUTPUT"; fi
}

fixture() {
  local f="$FLEET_FIXTURES/$1.json"
  [[ -f $f ]] || die "missing fixture $f"
  cat "$f"
}

# One part of issue-<n>.json: comments, blocked_by or pulls.
fixture_part() {
  fixture "issue-$1" | jq -e --arg k "$2" 'if has($k) then .[$k] else error("fixture has no \($k)") end'
}

# One part of final.json, the fixture for the final PR rule.
fixture_final() {
  fixture final | jq -e --arg k "$1" 'if has($k) then .[$k] else error("final.json has no \($k)") end'
}

# All pages of a REST list, as one array.
api_list() {
  gh api --paginate --slurp "$1" | jq 'add // []'
}

# Open issues labelled fleet, oldest first. /issues also lists PRs, which are dropped.
api_issues() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture issues
  else
    api_list "repos/$FLEET_REPO/issues?state=open&labels=fleet&per_page=100"
  fi | jq 'map(select(.pull_request == null)) | sort_by(.created_at, .number)'
}

# Closed issues labelled fleet. Only the final PR rule reads them.
api_closed_issues() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_final closed_issues
  else
    api_list "repos/$FLEET_REPO/issues?state=closed&labels=fleet&per_page=100"
  fi | jq 'map(select(.pull_request == null))'
}

api_issue() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture issues | jq -e --argjson n "$1" '.[] | select(.number == $n)'
  else
    gh api "repos/$FLEET_REPO/issues/$1"
  fi
}

api_comments() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_part "$1" comments
  else
    api_list "repos/$FLEET_REPO/issues/$1/comments?per_page=100"
  fi
}

# Issues that block this one (GitHub issue dependencies).
api_blocked_by() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_part "$1" blocked_by
  else
    api_list "repos/$FLEET_REPO/issues/$1/dependencies/blocked_by?per_page=100"
  fi
}

# PRs from task/<n> in this repo into the task's base branch, newest first, as
# [{number, state, isDraft, inQueue, autoMerge, checks, locked}]. A fork PR from a branch that is
# also named task/<n>, or a PR into another base, is never the task's PR. GraphQL, because REST has
# no merge queue state. $2 is the base branch; without one no PR can be the task's.
api_pulls() {
  local n=$1 base=${2:-}
  if [[ -z $base ]]; then
    echo "[]"
    return
  fi
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_part "$n" pulls
  else
    # shellcheck disable=SC2016 # GraphQL variables, not shell ones
    gh api graphql \
      -f owner="${FLEET_REPO%%/*}" -f name="${FLEET_REPO##*/}" -f head="task/$n" -f base="$base" \
      -f query='query($owner: String!, $name: String!, $head: String!, $base: String!) {
        repository(owner: $owner, name: $name) {
          pullRequests(headRefName: $head, baseRefName: $base, first: 100, orderBy: {field: CREATED_AT, direction: DESC}) {
            nodes {
              number state isDraft isInMergeQueue isCrossRepository baseRefName locked
              autoMergeRequest { enabledAt }
              commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
            }
          }
        }
      }'
  fi | jq --arg base "$base" '.data.repository.pullRequests.nodes
    | map(select(.isCrossRepository == false and .baseRefName == $base))
    | map({
        number, state, isDraft, locked,
        inQueue: .isInMergeQueue,
        autoMerge: (.autoMergeRequest != null),
        checks: .commits.nodes[0].commit.statusCheckRollup.state
      })'
}

# Runs of fleet.yml that haven't finished, as [{databaseId, displayTitle, status}].
api_active_runs() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture runs
    return
  fi
  local s all="[]" page
  for s in $ACTIVE_STATUSES; do
    page=$(gh run list -R "$FLEET_REPO" --workflow fleet.yml --status "$s" --limit 1000 \
      --json databaseId,displayTitle,status) || die "listing $s runs failed"
    all=$(jq -n --argjson a "$all" --argjson b "$page" '$a + $b')
  done
  echo "$all"
}

# Branches named fleet/<topic>, as a JSON array of names.
api_fleet_branches() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_final branches
  else
    api_list "repos/$FLEET_REPO/git/matching-refs/heads/fleet/?per_page=100" | jq 'map(.ref | sub("^refs/heads/"; ""))'
  fi
}

# How many commits a branch has that main doesn't.
api_ahead_of_main() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_final ahead | jq -e --arg b "$1" '.[$b]'
  else
    gh api "repos/$FLEET_REPO/compare/main...$1" --jq .ahead_by
  fi
}

# Open PRs from a branch of this repo into main, as an array.
api_prs_to_main() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_final prs_to_main | jq --arg b "$1" '.[$b] // []'
  else
    api_list "repos/$FLEET_REPO/pulls?state=open&base=main&head=${FLEET_REPO%%/*}:$1&per_page=100"
  fi
}

# Numbers of the merged PRs from this repo into a branch, oldest first.
api_merged_into() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_final merged | jq --arg b "$1" '.[$b] // []'
  else
    api_list "repos/$FLEET_REPO/pulls?state=closed&base=$1&per_page=100" |
      jq --arg repo "$FLEET_REPO" '[.[] | select(.merged_at != null and .head.repo.full_name == $repo)]
        | sort_by(.merged_at) | map(.number)'
  fi
}

# Whether a ref exists on the remote. Fails loudly on anything but "found" or "not found".
ref_exists() {
  local err
  if err=$(gh api "repos/$FLEET_REPO/git/ref/heads/$1" --silent 2>&1); then
    return 0
  fi
  [[ $err == *"HTTP 404"* ]] && return 1
  die "checking branch $1 failed: $err"
}

# The base branch named by an issue's "Base: fleet/<topic>" line, or nothing. Reads issue JSON.
issue_base() {
  jq -r '
    (.body // "") | split("\n") | map(sub("\r$"; ""))
    | map(capture("^Base: (?<b>fleet/[A-Za-z0-9._-]+)\\s*$").b) | first // empty'
}

# Outcome markers on an issue, oldest first: [{run, seat, outcome, retry_after, at}].
# Only comments by github-actions[bot] count, and the marker must be the whole first line.
markers() {
  api_comments "$1" | jq --arg bot "$MARKER_BOT" '
    [ .[]
      | select(.user.login == $bot and .user.type == "Bot")
      | .created_at as $at
      | .body | split("\n")[0] | sub("\r$"; "")
      | capture("^<!-- fleet:attempt run=(?<run>[0-9]+) seat=(?<seat>[abc]) outcome=(?<outcome>done|progress|paused|failed|cancelled) retry_after=(?<retry_after>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)? -->$")
      | .retry_after = (.retry_after // "")
      | . + {at: $at} ]
    | sort_by(.at)'
}

# A start is a run that got as far as the agent: outcome progress, failed or done.
# paused and cancelled aren't starts. Prints the count. Reads markers JSON on stdin.
start_count() {
  jq '[.[] | select(.outcome == "progress" or .outcome == "failed" or .outcome == "done")] | length'
}

# Prints why a task may not start again, or nothing. Reads markers JSON on stdin.
cap_reason() {
  jq -r --argjson max "$FLEET_MAX_STARTS" '
    [ .[] | select(.outcome == "progress" or .outcome == "failed" or .outcome == "done") ] as $starts
    | if ($starts | length) >= $max then
        "\($starts | length) starts, cap is \($max)"
      elif ($starts | length) >= 2 and ($starts[-2:] | all(.outcome == "failed")) then
        "two failed runs in a row"
      else empty end'
}

# Prints the retry time if the newest marker is a pause that hasn't run out, or nothing.
# A date that can't be read (2026-13-45T99:99:99Z) is no pause, never an error.
paused_until() {
  jq -r --argjson now "$NOW" '
    last // empty
    | select(.outcome == "paused" and .retry_after != "")
    | select(((try (.retry_after | fromdateiso8601) catch null) // 0) > $now)
    | .retry_after'
}

# The seat for the next start: (issue number + earlier starts) mod 3, as a, b or c.
#   $1 issue number. Reads markers JSON on stdin.
seat_for() {
  local count seats=(a b c)
  count=$(start_count)
  echo "${seats[$((($1 + count) % 3))]}"
}

# The state of a task's PR, from api_pulls JSON on stdin. One of:
#   merged     a PR merged
#   draft      the newest open PR is a draft
#   queued     ready, in the merge queue
#   failing    ready, its checks failed or errored (whatever auto-merge says)
#   automerge  ready, auto-merge on, checks pending or passing
#   ready      ready, auto-merge off and not queued (dropped from the queue, or never queued)
#   none       no PR, or only closed unmerged ones
pr_state() {
  jq -r '
    if any(.[]; .state == "MERGED") then "merged"
    else
      ([.[] | select(.state == "OPEN")][0]) as $p
      | if $p == null then "none"
        elif $p.isDraft then "draft"
        elif $p.inQueue then "queued"
        elif ($p.checks == "FAILURE" or $p.checks == "ERROR") then "failing"
        elif $p.autoMerge then "automerge"
        else "ready" end
    end'
}

has_label() {
  jq -e --arg l "$2" 'any(.labels[]?; .name == $l)' <<<"$1" >/dev/null
}

# shellcheck disable=SC2034 # DECISION, REASON and SEAT are read by the caller
# Decides what to do with one task issue, from real state only. Sets DECISION, REASON and, for a
# start, SEAT.
#   $1 issue number, $2 issue JSON, $3 active runs JSON, or "self" when called from the task's own run
# Decisions: start, done, failed-cap, skip-running, skip-waiting, skip-blocked, skip-paused,
# skip-stopped, skip-failed, skip-author, skip-closed, skip-unlabelled.
decide() {
  local n=$1 issue=$2 active=$3 base pulls state open_no blockers mk cap until
  DECISION="" REASON="" SEAT=""

  if [[ $(jq -r .state <<<"$issue") != open ]]; then
    DECISION=skip-closed REASON="issue is closed"
    return
  fi
  if ! has_label "$issue" fleet; then
    DECISION=skip-unlabelled REASON="no fleet label"
    return
  fi
  if ! jq -e --arg o "$FLEET_OWNER" '((.user.login // "") | ascii_downcase) == ($o | ascii_downcase)' <<<"$issue" >/dev/null; then
    DECISION=skip-author REASON="author is not FLEET_OWNER"
    return
  fi

  base=$(issue_base <<<"$issue")
  pulls=$(api_pulls "$n" "$base")
  state=$(pr_state <<<"$pulls")
  open_no=$(jq -r '[.[] | select(.state == "OPEN")][0].number // empty' <<<"$pulls")
  # Merged wins over every label: the work is in, so the issue closes.
  if [[ $state == merged ]]; then
    DECISION="done" REASON="PR #$(jq -r '[.[] | select(.state == "MERGED")][0].number' <<<"$pulls") merged"
    return
  fi
  if has_label "$issue" fleet:stop; then
    DECISION=skip-stopped REASON="has fleet:stop"
    return
  fi
  if has_label "$issue" fleet:failed; then
    DECISION=skip-failed REASON="has fleet:failed"
    return
  fi
  if [[ $active != self ]] &&
    jq -e --arg t "task #$n" 'any(.[]; .displayTitle == $t)' <<<"$active" >/dev/null; then
    DECISION=skip-running REASON="a task #$n run is queued or running"
    return
  fi
  case $state in
    queued)
      DECISION=skip-waiting REASON="PR #$open_no is in the merge queue"
      return
      ;;
    automerge)
      DECISION=skip-waiting REASON="PR #$open_no has auto-merge on and its checks haven't failed"
      return
      ;;
  esac

  blockers=$(api_blocked_by "$n" | jq -r '[.[] | select(.state == "open") | "#\(.number)"] | join(" ")')
  if [[ -n $blockers ]]; then
    DECISION=skip-blocked REASON="blocked by $blockers"
    return
  fi

  mk=$(markers "$n")
  cap=$(cap_reason <<<"$mk")
  if [[ -n $cap ]]; then
    DECISION=failed-cap REASON="$cap"
    return
  fi
  until=$(paused_until <<<"$mk")
  if [[ -n $until ]]; then
    DECISION=skip-paused REASON="paused on a usage limit until $until"
    return
  fi

  DECISION=start
  SEAT=$(seat_for "$n" <<<"$mk")
  case $state in
    none) REASON="unfinished, no open PR" ;;
    draft) REASON="unfinished, draft PR #$open_no" ;;
    failing) REASON="unfinished, ready PR #$open_no has failed checks" ;;
    ready) REASON="unfinished, ready PR #$open_no has auto-merge off and isn't queued" ;;
  esac
}

# Classifies one finished task run. Prints the outcome to record, or "none" when nothing started.
#   $1 the task job's result: success, failure, cancelled or skipped ("" when unknown)
#   $2 whether its checkout ran: "true" or anything else
#   $3 the agent step's outcome: success, failure, cancelled, skipped or ""
#   $4 whether it claims a usage limit stopped it: "true" or anything else
#   $5 whether it ran to the agent's step timeout: "true" or anything else
#   $6 the PR state from pr_state
# Only $1 and $6 are facts GitHub reports. $2 to $5 are what the task job says, and the agent can
# change what that job says (see FAILURES.md).
classify() {
  local result=$1 checkout=$2 agent=$3 paused=$4 timed_out=$5 state=$6
  if [[ $result == skipped ]]; then
    echo none
  elif [[ $result == cancelled ]]; then
    echo cancelled
  elif [[ $checkout != true ]]; then
    # Never got to the agent. A clean refusal (stopped, capped, done) isn't a start. A job that
    # died here (an API error, no Base line, a lost runner with no outputs) is a failed start.
    if [[ $result == success ]]; then echo none; else echo failed; fi
  elif [[ $state == merged || $state == queued || $state == automerge ]]; then
    echo "done"
  elif [[ $paused == true && $agent != success ]]; then
    echo paused
  elif [[ $agent == success ]]; then
    echo progress
  elif [[ $agent == failure && $timed_out == true ]]; then
    echo progress
  else
    echo failed
  fi
}

# shellcheck disable=SC2034 # RETRY_AFTER is read by the caller
# Sets RETRY_AFTER to a retry time that is safe to record: a valid ISO time no more than 8 days
# ahead, or empty (with a warning) when the claim can't be read.
clamp_retry_after() {
  local raw=$1 t
  RETRY_AFTER=""
  [[ -z $raw ]] && return 0
  if [[ ! $raw =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
    ! t=$(jq -rn --arg r "$raw" '$r | fromdateiso8601' 2>/dev/null); then
    warn "retry_after '$raw' isn't a time, recorded as empty"
    return 0
  fi
  if ((t > NOW + MAX_PAUSE_SECONDS)); then
    warn "retry_after $raw is more than 8 days ahead, capped at 8 days"
    RETRY_AFTER=$(jq -rn --argjson t $((NOW + MAX_PAUSE_SECONDS)) '$t | todate')
  else
    RETRY_AFTER=$raw
  fi
}
