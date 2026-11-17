#!/usr/bin/env bash
# Tests classify (lib.sh), the outcome job's verdict on a task run, against a table written by hand
# from the rules. No network, no fixtures.
#
# Columns: task job result | checkout ran | agent step | paused claim | timed out | PR state | outcome
# "-" stands for an empty value (a task job that died without outputs reports nothing).
# Rules: skipped means nothing started. cancelled is cancelled. No checkout: a clean refusal is no
# start, a job that died there is failed. Then a PR that is merged, queued or set to auto-merge
# (checks not failed) is done; a usage limit claim on an agent that didn't succeed is paused; an
# agent that succeeded, or failed at its step timeout, made progress; anything else failed.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "$here/lib.sh"

table='
skipped   -     -         -     -     none      none
skipped   -     -         -     -     merged    none
cancelled true  cancelled false false draft     cancelled
cancelled -     -         -     -     none      cancelled
cancelled true  success   false false automerge cancelled
success   false -         -     -     none      none
success   false -         -     -     merged    none
failure   false -         -     -     none      failed
failure   -     -         -     -     none      failed
failure   -     -         -     -     automerge failed
success   true  success   false false merged    done
success   true  failure   false false queued    done
success   true  failure   true  false automerge done
success   true  success   false false failing   progress
success   true  success   false false ready     progress
success   true  success   false false draft     progress
success   true  success   false false none      progress
success   true  failure   true  false none      paused
success   true  failure   true  false failing   paused
success   true  success   true  false draft     progress
success   true  failure   false true  draft     progress
success   true  failure   false false draft     failed
success   true  failure   false false failing   failed
success   true  -         -     -     none      failed
failure   true  success   false false draft     progress
failure   true  failure   false false none      failed
failure   true  -         -     -     none      failed
failure   true  failure   true  false none      paused
'

v() { if [[ $1 == - ]]; then echo ""; else echo "$1"; fi; }

fails=0 count=0
while read -r result checkout agent paused timed state want; do
  [[ -n $result ]] || continue
  got=$(classify "$(v "$result")" "$(v "$checkout")" "$(v "$agent")" "$(v "$paused")" "$(v "$timed")" "$state")
  count=$((count + 1))
  if [[ $got != "$want" ]]; then
    echo "FAIL: $result $checkout $agent $paused $timed $state: want $want, got $got"
    fails=$((fails + 1))
  fi
done <<<"$table"

if ((fails > 0)); then
  echo "classify-test: $fails of $count cases wrong" >&2
  exit 1
fi
echo "classify-test: all $count cases match"
