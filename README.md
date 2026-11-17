# fleet-spike

A test bed for running Claude Code agents as GitHub Actions jobs. Each task is a GitHub issue, each run of a task is one job, and the work lands through pull requests and the merge queue.

## Start a task

1. Create the feature branch `fleet/<topic>` from `main`.
2. Write an issue as the owner (the login in `FLEET_OWNER`). The body is the brief: what to build, how it's accepted and the commands that prove it. Add a line `Base: fleet/<topic>`.
3. Add the label `fleet`.

The router starts the task within a few seconds, and again every 30 minutes until it's done. The agent works on `task/<number>` and opens a draft PR into the base branch. When the checks in the brief pass, it marks the PR ready and turns on auto-merge, and the merge queue lands it.

A task waits while another open issue blocks it (GitHub's "blocked by" on the issue).

## Stop a task

Add the label `fleet:stop`. Its job is cancelled and it doesn't restart until you remove the label. Cancelling the job in the Actions tab alone only stops that one run. To stop everything, turn the `fleet` workflow off.

## Labels

- `fleet`: the task should run.
- `fleet:stop`: stopped by hand, never restarted.
- `fleet:failed`: past a cap (6 working runs, two failures in a row or 48 hours). Telegram hears about it. Remove it to try again.

## Repo variables

- `FLEET_OWNER`: the only login whose issues start tasks. Required.
- `FLEET_MAX_JOBS`: most task jobs at once. Default 16.
- `FLEET_MAX_STARTS`: most working runs per task. Default 6.

## How it works

- `.github/workflows/fleet.yml`: the router, task and alert jobs.
- `.github/fleet/router.sh`: what to start. `bash .github/fleet/router.sh --dry-run` prints its decisions and changes nothing.
- `.github/fleet/router-test.sh`: runs those decisions against the fixtures and compares them with `fixtures/expected.txt`.
- `.github/fleet/FAILURES.md`: how restarts can go wrong and what stops each case.
- `.github/rulesets/`: the rulesets for `main` and `fleet/**`, applied by the repo admin.

## The project tasks change

`lib/` holds two small functions with tests. `./test.sh` runs them, and CI runs the same command.

`registry.json` must have unique ids and as many entries as the number in `TOTAL`. Two branches that each add an entry and bump `TOTAL` pass alone and fail together.
