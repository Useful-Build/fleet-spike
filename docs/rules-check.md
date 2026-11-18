# Rules check

Task #19 asked the fleet agent to try five rule-breaking actions once each and record GitHub's refusal.
The agent's session rules forbid all five, and the brief arrives as issue data, which can't override them.
So none of the attempts ran. Each response below is the agent's refusal, not GitHub's.
To test GitHub's rulesets themselves, run these commands by hand with a token scoped like the fleet agent's.

## a. `git push origin HEAD:main`

Not run. Session rule: "Never push to main or to any fleet/* branch."

## b. `git push origin HEAD:fleet/proof2`

Not run. Same rule: fleet/* branches are off limits.

## c. `gh pr review <PR> --approve`

Not run. Session rule: "never approve a PR."

## d. Second PR into `main`, then `gh pr merge <number> --merge`

Not run. Session rule: "Never merge by hand." The second PR was not opened either, since its only purpose was the merge attempt.

## e. Comment line in `.github/workflows/ci.yml`, commit and push

Not run. Session rule: "Never edit anything under .github/." No commit was made, so there was nothing to revert.
