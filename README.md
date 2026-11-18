# fleet-spike

A test bed for running Claude Code agents as GitHub Actions jobs. Each task is a GitHub issue, each run of a task is one job, and the work lands through pull requests and the merge queue.

## Set up a repo

Once, by an admin, before the first task starts:

1. **Rulesets:** apply `.github/rulesets/main.json`, then `.github/rulesets/fleet.json` (Settings, Rules, Rulesets, Import a ruleset). Both must be on before the first task is started: the seat environments only protect anything while `main` is protected.
2. **Labels:** create `fleet`, `fleet:stop` and `fleet:failed`. The router doesn't create them.
3. **Variables:** set the repo variables `FLEET_OWNER`, `FLEET_MAX_JOBS` and `FLEET_MAX_STARTS` (see below).
4. **Environments:** create `fleet-seat-a`, `fleet-seat-b` and `fleet-seat-c` (each holds `FLEET_SEAT_TOKEN` and `FLEET_AGENTS_CONFIG_KEY`) and `fleet-alert` (holds `FLEET_TELEGRAM_BOT_TOKEN` and `FLEET_TELEGRAM_CHAT_ID`). Limit each to the branch `main`.
5. **Actions:** turn on "Allow GitHub Actions to create and approve pull requests" (Settings, Actions, General), so the router can open the final PR.

## Start a task

1. Create the feature branch `fleet/<topic>` from `main`.
2. Write an issue as the owner (the login in `FLEET_OWNER`). The body is the brief: what to build, how it's accepted and the commands that prove it. Add a line `Base: fleet/<topic>`.
3. Add the label `fleet`.

The router locks the issue, then starts the task within a few seconds, and again every 30 minutes until it's done. The agent works on `task/<number>` and opens a draft PR into the base branch. When the checks in the brief pass, it marks the PR ready and turns on auto-merge, and the merge queue lands it.

A task waits while another open issue blocks it (GitHub's "blocked by" on the issue).

When every task issue for a `fleet/<topic>` branch is closed, the router opens the PR from that branch into `main`, starts `ci` on it, and Telegram says it's ready for review. A final PR you close isn't opened again until the branch gets a new commit.

## Stop a task

- **One task:** add the label `fleet:stop`. Its job is cancelled and it doesn't restart until you remove the label. Cancelling the job in the Actions tab alone only stops that one run.
- **Everything:** run the `fleet` workflow with `stop_all` ticked (Actions tab, or `gh workflow run fleet.yml -f stop_all=true`). It adds `fleet:stop` to every open fleet issue and cancels every task run.

## Retry a failed task

A task that hits a cap gets `fleet:failed`. Removing the label doesn't reset its count, so the next round adds it again. To retry, close the issue and open a new one.

## Labels

- `fleet`: the task should run.
- `fleet:stop`: stopped by hand, never restarted.
- `fleet:failed`: past a cap (6 starts, or two failed runs in a row). Telegram hears about it.

The fleet posts its records as comments on locked issues, unlocking each for a few seconds while it posts.

## Repo variables

- `FLEET_OWNER`: the only login whose issues start tasks. Required.
- `FLEET_MAX_JOBS`: most task jobs at once. Default 16.
- `FLEET_MAX_STARTS`: most starts per task. A run that ends `progress`, `failed` or `done` is a start, and so is a cancelled run when the task has no `fleet:stop`. One that ends on a usage limit, or is cancelled by `fleet:stop`, isn't. Default 6.

## Environments

Secrets live in environments that only `main` may use: `fleet-seat-a`, `fleet-seat-b` and `fleet-seat-c` each hold `FLEET_SEAT_TOKEN` and `FLEET_AGENTS_CONFIG_KEY`, and `fleet-alert` holds `FLEET_TELEGRAM_BOT_TOKEN` and `FLEET_TELEGRAM_CHAT_ID`. The router picks a task's seat and passes it to the run: the seats take turns, and a seat that hit a usage limit is skipped for that task until it resets.

## How it works

- `.github/workflows/fleet.yml`: the router, the agent's task job, the outcome job that judges it, and the Telegram alerts.
- `.github/fleet/router.sh`: what to start. `bash .github/fleet/router.sh --dry-run` prints its decisions and changes nothing.
- `.github/fleet/router-test.sh`: runs those decisions against the fixtures and compares them with `fixtures/expected.txt`, which is written by hand from the rules.
- `.github/fleet/classify-test.sh`: checks how the outcome job classifies a run.
- `.github/fleet/FAILURES.md`: how restarts can go wrong and what stops each case.
- `.github/rulesets/`: the rulesets for `main` and `fleet/**`, applied by the repo admin.

## The project tasks change

`lib/` holds two small functions with tests. `./test.sh` runs them, and CI runs the same command. CI refuses a change into a `fleet/*` branch that touches `.github/` or `test.sh`: those go to `main` through the owner.

`registry.json` must have unique ids and as many entries as the number in `TOTAL`. Two branches that each add an entry and bump `TOTAL` pass alone and fail together.
