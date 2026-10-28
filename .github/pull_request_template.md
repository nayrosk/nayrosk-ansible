<!-- The title becomes the commit on main: use a Conventional Commit, e.g. `feat(dns): add a fallback resolver`. -->

Closes #

## Summary

<!-- What changes and why. -->

## Testing

<!-- Commands you ran and what they showed. -->

## Checklist

- [ ] The branch was created from the issue (`gh issue develop <number>`) and is named `<feat|fix|chore>/<number>-<slug>`
- [ ] Commits are signed and follow Conventional Commits
- [ ] `make lint` passes
- [ ] `make docs CHECK=1` passes (run `make docs` after changing a role variable)
- [ ] `make e2e` passes when roles or the test harness changed
- [ ] Documentation updated when behavior changes
- [ ] Secrets stay in the vault and never reach output, logs or commits
