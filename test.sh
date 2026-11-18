#!/usr/bin/env bash
# Runs every test. CI runs exactly this, so it's the one command a task must keep green.
set -euo pipefail
cd "$(dirname "$0")"
node --test "test/*.test.mjs"
