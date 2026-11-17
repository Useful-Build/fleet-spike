#!/usr/bin/env bash
# Steps of the fleet task job. Each subcommand writes its results as step outputs.
#
#   task.sh check <n>     may this task run now? outputs issue, go, failed_added
#   task.sh seat <n>      which seat: (n + earlier runs) mod 3 as A, B or C. outputs seat
#   task.sh base <n>      the base branch from the issue's "Base: fleet/<topic>" line. outputs base
#   task.sh branch <n>    what to check out: task/<n> if it exists, else the base. outputs ref, exists
#   task.sh outcome <n>   classify the run, post its marker, apply the caps. outputs outcome, failed_added
#
# Add --dry-run to print what would change instead. Env as in router.sh, plus for outcome:
# RUN_ID, SEAT, JOB_CANCELLED, AGENT_OUTCOME, AGENT_STARTED, AGENT_TIMEOUT_MINUTES, EXECUTION_FILE.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "$here/lib.sh"

DRY_RUN=0
args=()
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=1 ;;
    *) args+=("$arg") ;;
  esac
done
[[ ${#args[@]} == 2 ]] || die "usage: task.sh check|seat|base|branch|outcome <issue> [--dry-run]"
cmd=${args[0]} n=${args[1]}
is_number "$n" || die "issue must be a number"
fleet_init

notice() { echo "::notice::$*"; }

# Prefixes Claude Code puts on a message when a subscription usage limit stops it. Copied from
# USAGE_LIMIT_ERROR_PREFIXES in @anthropic-ai/claude-agent-sdk 0.3.326 (sdk.d.ts), the SDK version
# claude-code-action v1 pins. Only used when the structured event below is missing.
USAGE_LIMIT_PREFIXES=$(
  cat <<'JSON'
["You've hit your", "You've reached your", "You're out of usage credits",
 "Your org is out of usage", "Your seat type doesn't include usage",
 "Your usage allocation has been disabled", "Your group's usage limit is set to $0",
 "You're out of extra usage", "Your seat type doesn't include extra usage"]
JSON
)

# THE usage-limit matcher. Reads the action's execution file (a JSON array of Agent SDK messages)
# and prints "paused <retry_after>" when a usage limit stopped the run, or nothing.
# 1. Structured: a rate_limit_event whose rate_limit_info.status is "rejected". Its resetsAt
#    (epoch seconds, or milliseconds when it's that large) becomes retry_after.
# 2. Text: the result message, or an assistant message with error "rate_limit", starts with one
#    of the prefixes above. No reset time is parsed from the text, so retry_after stays empty.
match_usage_limit() {
  local file=$1
  [[ -n $file && -s $file ]] || return 0
  jq -r --argjson prefixes "$USAGE_LIMIT_PREFIXES" '
    def limited: type == "string" and (. as $t | any($prefixes[]; . as $p | $t | startswith($p)));
    ( [ .[] | select(.type == "rate_limit_event" and .rate_limit_info.status == "rejected") ] | last ) as $event
    | if $event != null then
        ($event.rate_limit_info.resetsAt // null) as $r
        | "paused " + (if $r == null then "" elif $r > 100000000000 then ($r / 1000 | floor | todate) else ($r | floor | todate) end)
      elif any(.[]; (.type == "result" and (.result | limited))
                 or (.type == "assistant" and .error == "rate_limit"
                     and any(.message.content[]?; .type == "text" and (.text | limited)))) then
        "paused "
      else empty end' "$file"
}

cmd_check() {
  local issue
  emit issue "$n"
  if [[ -n ${FLEET_FIXTURES:-} ]]; then
    issue=$(api_issue "$n")
  elif ! issue=$(api_issue "$n" 2>&1); then
    if [[ $issue == *"HTTP 404"* ]]; then
      notice "#$n not started: no such issue"
      emit go false
      emit failed_added false
      return
    fi
    die "reading issue #$n failed: $issue"
  fi
  if jq -e '.pull_request != null' <<<"$issue" >/dev/null; then
    notice "#$n not started: it's a pull request"
    emit go false
    emit failed_added false
    return
  fi
  decide "$n" "$issue" self
  case $DECISION in
    start)
      echo "#$n start: $REASON"
      emit go true
      emit failed_added false
      ;;
    failed-cap)
      notice "#$n not started, marked fleet:failed: $REASON"
      act gh issue edit "$n" -R "$FLEET_REPO" --add-label fleet:failed
      emit failed_added true
      emit go false
      ;;
    *)
      notice "#$n not started ($DECISION): $REASON"
      emit go false
      emit failed_added false
      ;;
  esac
}

seat_for() {
  local count seats=(A B C)
  count=$(markers "$1" | jq length)
  echo "${seats[$((($1 + count) % 3))]}"
}

cmd_seat() {
  local seat
  seat=$(seat_for "$n")
  emit seat "$seat"
}

cmd_base() {
  local base
  base=$(api_issue "$n" | jq -r '
    (.body // "") | split("\n") | map(sub("\r$"; ""))
    | map(capture("^Base: (?<b>fleet/[A-Za-z0-9._-]+)\\s*$").b) | first // empty')
  [[ -n $base ]] || die "issue #$n has no line \"Base: fleet/<topic>\". Add one and restart."
  # Belt and braces: only this pattern ever leaves this function.
  [[ $base =~ ^fleet/[A-Za-z0-9._-]+$ ]] || die "bad base branch name"
  if [[ -z ${FLEET_FIXTURES:-} ]] && ! ref_exists "$base"; then
    die "base branch $base doesn't exist. Create it from main first."
  fi
  emit base "$base"
}

cmd_branch() {
  local base=${BASE:?BASE is not set}
  if ref_exists "task/$n"; then
    emit ref "task/$n"
    emit exists true
  else
    emit ref "$base"
    emit exists false
  fi
}

cmd_outcome() {
  local outcome="" retry_after="" pulls paused mk cap line elapsed limit added
  local run_id=${RUN_ID:?RUN_ID is not set} seat=${SEAT:-} agent=${AGENT_OUTCOME:-}
  [[ $run_id =~ ^[0-9]+$ ]] || die "RUN_ID must be a number"
  if [[ ! $seat =~ ^[ABC]$ ]]; then
    seat=$(seat_for "$n")
  fi

  pulls=$(api_pulls "$n")
  paused=$(match_usage_limit "${EXECUTION_FILE:-}")
  if [[ ${JOB_CANCELLED:-false} == true ]]; then
    outcome=cancelled
  elif jq -e 'any(.[]; .state == "MERGED" or (.state == "OPEN" and .isDraft == false and (.autoMerge or .inQueue)))' <<<"$pulls" >/dev/null; then
    outcome="done"
  elif [[ -n $paused && $agent != success ]]; then
    outcome=paused
    retry_after=${paused#paused }
  elif [[ $agent == success ]]; then
    outcome=progress
  elif [[ $agent == failure && -n ${AGENT_STARTED:-} ]]; then
    # A step timeout also reports "failure". It shows as a run that lasted to the limit.
    elapsed=$((NOW - AGENT_STARTED))
    limit=$((${AGENT_TIMEOUT_MINUTES:-330} * 60 - 60))
    if ((elapsed >= limit)); then outcome=progress; else outcome=failed; fi
  else
    outcome=failed
  fi

  case $outcome in
    done) line="Run $run_id on seat $seat: done. The PR is ready and set to merge." ;;
    progress) line="Run $run_id on seat $seat: progress saved, not finished. The router starts it again." ;;
    paused) line="Run $run_id on seat $seat: paused on a usage limit${retry_after:+ until $retry_after}. The router starts it again after that." ;;
    cancelled) line="Run $run_id on seat $seat: cancelled." ;;
    failed) line="Run $run_id on seat $seat: failed. See the run log." ;;
  esac
  emit outcome "$outcome"
  act gh issue comment "$n" -R "$FLEET_REPO" --body \
    "<!-- fleet:attempt run=$run_id seat=$seat outcome=$outcome retry_after=$retry_after -->
$line"

  added=false
  if [[ $outcome != "done" && $outcome != cancelled ]]; then
    mk=$(markers "$n")
    if [[ ${DRY_RUN:-0} == 1 ]]; then
      # The marker above wasn't posted, so count it here.
      mk=$(jq --arg o "$outcome" --argjson now "$NOW" '. + [{outcome: $o, at: ($now | todate)}]' <<<"$mk")
    fi
    cap=$(cap_reason <<<"$mk")
    if [[ -n $cap ]]; then
      echo "::warning::#$n marked fleet:failed: $cap"
      act gh issue edit "$n" -R "$FLEET_REPO" --add-label fleet:failed
      added=true
    fi
  fi
  emit failed_added "$added"
  if [[ $outcome == failed ]]; then die "task #$n run failed"; fi
}

case $cmd in
  check) cmd_check ;;
  seat) cmd_seat ;;
  base) cmd_base ;;
  branch) cmd_branch ;;
  outcome) cmd_outcome ;;
  *) die "unknown subcommand: $cmd" ;;
esac
