# shellcheck shell=bash
# Shared by router.sh and task.sh. Sourced, never run on its own.
#
# Every GitHub read goes through an api_* function. With FLEET_FIXTURES set to a directory they read
# JSON files from it instead (same shapes the API returns), and FLEET_NOW fixes the clock, so the
# decisions can be tested without a network. See router-test.sh.
#
# Issue text never reaches the shell: JSON is read with jq, and only numbers, label names, logins
# and the validated base branch name come out of it.

MARKER_BOT="github-actions[bot]"
MAX_AGE_SECONDS=$((48 * 3600))
ACTIVE_STATUSES="queued in_progress waiting pending requested"

die() {
  echo "fleet: $*" >&2
  exit 1
}

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

# PRs whose head is task/<n>, newest first, as
# [{number, state, isDraft, inQueue, autoMerge, checks}]. GraphQL, because REST has no merge queue state.
api_pulls() {
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    fixture_part "$1" pulls
  else
    # shellcheck disable=SC2016 # GraphQL variables, not shell ones
    gh api graphql \
      -f owner="${FLEET_REPO%%/*}" -f name="${FLEET_REPO##*/}" -f head="task/$1" \
      -f query='query($owner: String!, $name: String!, $head: String!) {
        repository(owner: $owner, name: $name) {
          pullRequests(headRefName: $head, first: 20, orderBy: {field: CREATED_AT, direction: DESC}) {
            nodes {
              number state isDraft isInMergeQueue
              autoMergeRequest { enabledAt }
              commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
            }
          }
        }
      }'
  fi | jq '.data.repository.pullRequests.nodes | map({
      number, state, isDraft,
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

# Whether a ref exists on the remote. Fails loudly on anything but "found" or "not found".
ref_exists() {
  local err
  if err=$(gh api "repos/$FLEET_REPO/git/ref/heads/$1" --silent 2>&1); then
    return 0
  fi
  [[ $err == *"HTTP 404"* ]] && return 1
  die "checking branch $1 failed: $err"
}

# Outcome markers on an issue, oldest first: [{run, seat, outcome, retry_after, at}].
# Only comments by github-actions[bot] count, and the marker must be the whole first line.
markers() {
  api_comments "$1" | jq --arg bot "$MARKER_BOT" '
    [ .[]
      | select(.user.login == $bot and .user.type == "Bot")
      | .created_at as $at
      | .body | split("\n")[0] | sub("\r$"; "")
      | capture("^<!-- fleet:attempt run=(?<run>[0-9]+) seat=(?<seat>[ABC]) outcome=(?<outcome>done|progress|paused|failed|cancelled) retry_after=(?<retry_after>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)? -->$")
      | .retry_after = (.retry_after // "")
      | . + {at: $at} ]
    | sort_by(.at)'
}

# Prints why a task may not start again, or nothing. Reads markers JSON on stdin.
cap_reason() {
  jq -r --argjson max "$FLEET_MAX_STARTS" --argjson now "$NOW" --argjson age "$MAX_AGE_SECONDS" '
    [ .[] | select(.outcome == "progress" or .outcome == "failed") ] as $starts
    | if ($starts | length) >= $max then
        "\($starts | length) working starts, cap is \($max)"
      elif ($starts | length) >= 2 and ($starts[-2:] | all(.outcome == "failed")) then
        "two failed runs in a row"
      elif length > 0 and ($now - (.[0].at | fromdateiso8601)) > $age then
        "first run started more than 48 hours ago"
      else empty end'
}

# Prints the retry time if the newest marker is a pause that hasn't run out, or nothing.
paused_until() {
  jq -r --argjson now "$NOW" '
    last // empty
    | select(.outcome == "paused" and .retry_after != "")
    | select((.retry_after | fromdateiso8601) > $now)
    | .retry_after'
}

has_label() {
  jq -e --arg l "$2" 'any(.labels[]; .name == $l)' <<<"$1" >/dev/null
}

# shellcheck disable=SC2034 # DECISION and REASON are read by the caller
# Decides what to do with one task issue, from real state only. Sets DECISION and REASON.
#   $1 issue number, $2 issue JSON, $3 active runs JSON, or "self" when called from the task's own run
# Decisions: start, done, failed-cap, skip-running, skip-waiting, skip-blocked, skip-paused,
# skip-stopped, skip-failed, skip-author, skip-closed, skip-unlabelled.
decide() {
  local n=$1 issue=$2 active=$3 pulls open_pr blockers mk cap until
  DECISION="" REASON=""

  if [[ $(jq -r .state <<<"$issue") != open ]]; then
    DECISION=skip-closed REASON="issue is closed"
    return
  fi
  if ! has_label "$issue" fleet; then
    DECISION=skip-unlabelled REASON="no fleet label"
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
  if ! jq -e --arg o "$FLEET_OWNER" '(.user.login | ascii_downcase) == ($o | ascii_downcase)' <<<"$issue" >/dev/null; then
    DECISION=skip-author REASON="author is not FLEET_OWNER"
    return
  fi
  if [[ $active != self ]] &&
    jq -e --arg t "task #$n" 'any(.[]; .displayTitle == $t)' <<<"$active" >/dev/null; then
    DECISION=skip-running REASON="a task #$n run is queued or running"
    return
  fi

  pulls=$(api_pulls "$n")
  if jq -e 'any(.[]; .state == "MERGED")' <<<"$pulls" >/dev/null; then
    DECISION="done" REASON="PR #$(jq -r '[.[] | select(.state == "MERGED")][0].number' <<<"$pulls") merged"
    return
  fi
  open_pr=$(jq -c '[.[] | select(.state == "OPEN")][0] // empty' <<<"$pulls")
  if [[ -n $open_pr ]] && [[ $(jq -r .isDraft <<<"$open_pr") == false ]]; then
    local pr_no
    pr_no=$(jq -r .number <<<"$open_pr")
    if [[ $(jq -r .inQueue <<<"$open_pr") == true ]]; then
      DECISION=skip-waiting REASON="PR #$pr_no is in the merge queue"
      return
    fi
    if [[ $(jq -r .autoMerge <<<"$open_pr") == true ]]; then
      DECISION=skip-waiting REASON="PR #$pr_no has auto-merge on"
      return
    fi
    if jq -e '.checks == "PENDING" or .checks == "EXPECTED"' <<<"$open_pr" >/dev/null; then
      DECISION=skip-waiting REASON="PR #$pr_no checks are running"
      return
    fi
  fi

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
  if [[ -z $open_pr ]]; then
    REASON="unfinished, no open PR"
  elif [[ $(jq -r .isDraft <<<"$open_pr") == true ]]; then
    REASON="unfinished, draft PR #$(jq -r .number <<<"$open_pr")"
  else
    REASON="unfinished, PR #$(jq -r .number <<<"$open_pr") left the queue or failed checks"
  fi
}
