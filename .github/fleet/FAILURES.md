# How the restart routine can go wrong

Written before `router.sh` and `task.sh`. Each line is a failure and the defence the code has for it.
"Router" is the `router` job in `fleet.yml`, "task job" is the `task` job, "check" is `task.sh check`.

| # | Failure | Defence |
|---|---|---|
| 1 | Double start: two router runs (cron and a label event) dispatch the same task at once | The router job has `concurrency: fleet-router` so routers run one at a time. Each dispatch is a run named `task #<n>`, and a queued, pending or in-progress run with that name means "running". If a dispatch lands before GitHub lists it, the task job's own group `fleet-task-<n>` (no cancel) makes the second one wait, and its check finds the PR state the first one left. One writer per task at any time. |
| 2 | Restart of a stopped task | `fleet:stop` cancels every active `task #<n>` run. The router skips any issue with `fleet:stop`, and check stops the task job cleanly if the label is there when it starts. |
| 3 | Restart of a task waiting in the queue | An open, non-draft PR from `task/<n>` that is in the merge queue, has auto-merge on, or has checks still pending counts as "waiting" and is skipped. Merge queue state comes from GraphQL `isInMergeQueue`. |
| 4 | Task dropped from the queue (conflict, failed check) never repaired | Once it's out of the queue, auto-merge is off and checks aren't pending, so it's "unfinished" and restarts on the same branch. |
| 5 | Forged marker comment | Only comments whose author is `github-actions[bot]` (type `Bot`) count, and the marker must be the comment's whole first line. Only workflows in this repo can post as `github-actions[bot]`. `ci.yml` has `contents: read` only and can't comment. The agent posts as `claude[bot]`, so its comments never count. |
| 6 | Issue written or edited by someone else | Only issues whose author is `FLEET_OWNER` start (the author can't change on edit). A missing `FLEET_OWNER` fails the job instead of trusting everyone. Edits by others need write access, and the brief is read fresh at each start, so an owner should lock a task issue they don't want edited. Comments are never read as the brief. |
| 7 | Cap never reached | Starts are counted from markers, not from memory: `progress` and `failed` count, `paused` and `cancelled` don't. The router and check both refuse at `FLEET_MAX_STARTS` (default 6), after two `failed` in a row, or 48 hours after the first marker. The task job also checks right after it posts its marker, so the label and the Telegram alert come from the run that hit the cap. A run that fails before its marker step still ends with a `failed` marker, because that step runs on `always()`. |
| 8 | Cron late or skipped | GitHub's schedule is best effort. Label events also start the router, and nothing depends on the cron being on time: a late round just starts work later. |
| 9 | Dispatch fails | Each `gh workflow run` failure is logged, the router carries on with the other tasks and then exits non-zero so the run shows red. The next round tries again. |
| 10 | API pagination past 30 or 100 items | Issues, comments and blockers use `gh api --paginate --slurp` with `per_page=100`. Runs use `gh run list` with a 1000 limit per status. PRs are looked up per branch name, so there are never many. |
| 11 | Issue with no `Base:` line, or a base branch that doesn't exist | The task job fails with a clear message and records `failed`. Two in a row add `fleet:failed`. |
| 12 | Deleted task branch | GitHub closes the PR. The task job finds no `task/<n>` on the remote and creates it again from the base, and the agent opens a new PR. |
| 13 | Closed, unmerged PR | Not "waiting", not "done", so the task is unfinished and the agent opens a new PR. To stop a task, use `fleet:stop`, not closing the PR. |
| 14 | Usage limit loops | A run that hits a seat limit records `paused` with the reset time when the SDK gives one, and the router waits until then. Paused runs don't count as starts, but the 48 hour cap still ends a task that never gets going. Each restart moves to the next seat. |
| 15 | Job killed at the 6 hour limit | The agent step stops at 330 minutes and the job at 355, so the checkpoint and marker steps get time to run. |
| 16 | Work lost when a run dies | The checkpoint step commits and pushes anything left in the tree with `GITHUB_TOKEN`, with git hooks off. Its commit doesn't start CI (GitHub's rule for that token), so CI runs on the agent's next push. |
| 17 | Issue body used as shell | The body is written to a file with `gh api ... --jq .body > file`. Scripts read issue JSON with `jq` and only print numbers, labels and the validated base branch name. The prompt is fixed text. |
| 18 | A task issue that's a PR | `/issues` also lists PRs. Anything with `pull_request` set is dropped. |
| 19 | Dispatched run rejected as a bot | Runs the router starts have `github-actions[bot]` as their actor, and the action refuses bot actors unless `allowed_bots` lists them, so the task job lists exactly that one bot. |
| 20 | Runner isn't a sandbox | The agent can run any shell command on the runner. Scripts run from a copy of `main` taken before the agent starts, not from the task branch. The real limits are the seat token (one per job), the app token's repo scope and the rulesets on `main` and `fleet/**`. |
