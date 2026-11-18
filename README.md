# fleet-spike

A test bed for running Claude Code agents as GitHub Actions jobs. Each task is a GitHub issue, each run of a task is one job, and the work lands through pull requests and the merge queue.

## Set up a repo

Once, by an admin, before the first task starts:

1. **Rulesets:** apply `.github/rulesets/main.json`, then `.github/rulesets/fleet.json` (Settings, Rules, Rulesets, Import a ruleset). Both must be on before the first task is started: the seat environments only protect anything while `main` is protected. `fleet.json` has no merge queue: GitHub refused one on the `fleet/**` ruleset when we tried (its docs say the same for branch protection rules with a wildcard), so each feature branch gets its own queue ruleset when you start it (below).
2. **Labels:** create `fleet`, `fleet:stop` and `fleet:failed`. The router doesn't create them.
3. **Variables:** set the repo variables `FLEET_OWNER`, `FLEET_MAX_JOBS`, `FLEET_MAX_STARTS` and, if you want another floor, `FLEET_BUDGET_FLOOR` (see below).
4. **Environments:** create `fleet-seat-a`, `fleet-seat-b` and `fleet-seat-c` (each holds `FLEET_SEAT_TOKEN` and `FLEET_AGENTS_CONFIG_KEY`) and `fleet-alert` (holds `FLEET_TELEGRAM_BOT_TOKEN` and `FLEET_TELEGRAM_CHAT_ID`). Limit each to the branch `main`.
5. **Actions:** turn on "Allow GitHub Actions to create and approve pull requests" (Settings, Actions, General), so the router can open the final PR.
6. **Pull requests:** turn on "Allow auto-merge" (Settings, General), or no task can finish.
7. **Claude app:** install the Claude GitHub App on the repo.

For a second repo, also:

- The repo must be owned by an organization and be public (merge queue and rulesets).
- Set `.github/CODEOWNERS` to the new owner.
- `.github/workflows/fleet.yml` reads the rules from `repository: wasimjalali/agents-config`. If you use another rules repo, change that line and store its read-only deploy key as `FLEET_AGENTS_CONFIG_KEY` in each seat environment.

## Start a task

1. Once per feature, as the owner on your own machine: `bash .github/fleet/new-feature.sh <topic>`. It creates `fleet/<topic>` from `main` and the ruleset `fleet/<topic> queue`, which puts that branch behind the merge queue. `--dry-run` prints the two requests and changes nothing.
2. Write an issue as the owner (the login in `FLEET_OWNER`). The body is the brief: what to build, how it's accepted and the commands that prove it. Add a line `Base: fleet/<topic>`.
3. Add the label `fleet`.

The router locks the issue, then starts the task within a few seconds. When a task run that counted as a start ends (`progress`, `failed` or `done`), its marker is posted and then its last job starts a new round right away, so its restart doesn't wait. A run paused on a usage limit, or a round held back below the budget floor, waits for the next round from another trigger. A round is also scheduled at minutes 7 and 37 of each hour, as the safety net, but GitHub delays scheduled runs under load and may drop some, so that isn't a promise. As of 18 November 2026 no scheduled round had fired on this repo (FAILURES.md 34), and those waits end green with no alert, so until one has been seen, a lone paused task can stall: start a round by running the `fleet` workflow with no inputs. A task that never finishes can use all its starts (`FLEET_MAX_STARTS`) in minutes. Each run of the agent stops after 55 minutes, before its GitHub access ends at the hour: it saves its work, and the next run carries on, using another start. The agent works on `task/<number>` and opens a draft PR into the base branch. When the checks in the brief pass, it marks the PR ready and turns on auto-merge, and the merge queue lands it.

A task waits while another open issue blocks it (GitHub's "blocked by" on the issue).

A round closes the issue of a merged task PR and starts the tasks it was blocking. A merge that lands after its task run has ended waits for the next round: a label event, another task run ending or the scheduled round.

When every task issue for a `fleet/<topic>` branch is closed, the router opens the PR from that branch into `main`, starts `ci` on it, and Telegram says it's ready for review. A final PR you close isn't opened again until the branch gets a new commit.

After the final PR has merged, delete the branch's queue ruleset: `gh api -X DELETE repos/<owner>/<repo>/rulesets/<id>`, with the id from `gh api --paginate repos/<owner>/<repo>/rulesets --jq '.[] | select(.name == "fleet/<topic> queue") | .id'`.

## Stop a task

- **One task:** add the label `fleet:stop` first. Its job is cancelled and it doesn't restart until you remove the label. Cancelling the run in the Actions tab without the label counts as progress: its end starts a round, which starts the task again within seconds and uses one of its starts.
- **Everything:** run the `fleet` workflow with `stop_all` ticked (Actions tab, or `gh workflow run fleet.yml -f stop_all=true`). It adds `fleet:stop` to every open fleet issue and cancels every task run.

## Retry a failed task

A task that hits a cap gets `fleet:failed`. Removing the label doesn't reset its count, so the next round adds it again. To retry, close the issue and open a new one. The new task starts on a new branch, `task/<its number>`, from its base, not on the old task's branch.

## Labels

- `fleet`: the task should run.
- `fleet:stop`: stopped by hand, never restarted.
- `fleet:failed`: past a cap (6 starts, or two failed runs in a row). Telegram hears about it.

The fleet posts its records as comments on locked issues, unlocking each for a few seconds while it posts.

## Repo variables

- `FLEET_OWNER`: the only login whose issues start tasks. Required.
- `FLEET_MAX_JOBS`: most task jobs at once. Default 16.
- `FLEET_MAX_STARTS`: most starts per task. A run that ends `progress`, `failed` or `done` is a start, and so is a cancelled run when the task has no `fleet:stop`. One that ends on a usage limit, or is cancelled by `fleet:stop`, isn't. Default 6. Each start runs the agent for at most 55 minutes, about 45 of them real work if it follows the prompt, so at 6 a task gets at most about five and a half hours of job time. After that it gets `fleet:failed` and a Telegram alert. Raise this for a bigger task.
- `FLEET_BUDGET_FLOOR`: the fewest REST requests and GraphQL points a round needs left to do anything. Every job's `GITHUB_TOKEN` in the repo shares 1,000 of each an hour. Below the floor in either, a round starts, closes, labels and cancels nothing and opens no final PR, so the outcome jobs keep room to post their markers. Stopping still works. `0` turns the guard off. Any other value fails every round but the stop rounds: the floor must be digits only, `0` or `1` to `9999999999` with no leading zero. Each round logs `fleet budget: REST <left>/<limit> resets <time> UTC, GraphQL <left>/<limit> resets <time> UTC` at its start and end, and each outcome job logs it at its end. Default 200.

## Environments

Secrets live in environments that only `main` may use: `fleet-seat-a`, `fleet-seat-b` and `fleet-seat-c` each hold `FLEET_SEAT_TOKEN` and `FLEET_AGENTS_CONFIG_KEY`, and `fleet-alert` holds `FLEET_TELEGRAM_BOT_TOKEN` and `FLEET_TELEGRAM_CHAT_ID`. The router picks a task's seat and passes it to the run: the seats take turns, and a seat that hit a usage limit is skipped for that task until it resets.

## How it works

- `.github/workflows/fleet.yml`: the router, the agent's task job, the outcome job that judges it, the next-round job that starts a round when a task run ends, and the Telegram alerts.
- `.github/fleet/router.sh`: what to start. `bash .github/fleet/router.sh --dry-run` prints its decisions and changes nothing.
- `.github/fleet/router-test.sh`: runs those decisions against the fixtures and compares them with `fixtures/expected.txt`, which is written by hand from the rules.
- `.github/fleet/classify-test.sh`: checks how the outcome job classifies a run.
- `.github/fleet/dispatch-test.sh`: runs the router's real dispatch and wait against a stub `gh`.
- `.github/fleet/FAILURES.md`: how restarts can go wrong and what stops each case.
- `.github/rulesets/`: the rulesets for `main` and `fleet/**`, applied by the repo admin.
- `.github/fleet/new-feature.sh`: starts a feature branch and its queue ruleset.

## The project tasks change

`lib/` holds two small functions with tests. `./test.sh` runs them, and CI runs the same command. CI refuses a change into a `fleet/*` branch that touches `.github/` or `test.sh`: those go to `main` through the owner.

`registry.json` must have unique ids and as many entries as the number in `TOTAL`. Two branches that each add an entry and bump `TOTAL` pass alone and fail together.
