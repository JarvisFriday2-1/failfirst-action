# FailFirst Gate (GitHub Action)

Proves that a pull request's tests actually test the change. On every PR it runs the
[`fail-first-gate`](https://www.npmjs.com/package/fail-first-gate) CLI, which checks three things:

- **A. head passes** - the test suite passes on the PR head.
- **B. base + new tests fails** - the PR's new or changed tests fail on the base commit. Tests that already pass without the change do not test it.
- **C. guard removed, tests fail** - with every non-test file reverted to base, the tests fail again. Otherwise the fix is hollow.

It also scans the diff for weakened tests: skipped or focused tests, lengthened timeouts, deleted assertions, deleted test files, and CI tampering.

No model, no API key, no network beyond installing the package. Built for PRs written by coding agents, useful for any PR.

## Usage

```yaml
name: FailFirst
on: [pull_request]
jobs:
  failfirst:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # the base commit must be present
      - uses: JarvisFriday2-1/failfirst-action@v0.1.1
```

The verdict is printed to the job log and to the job summary. A failed check or a scan hit fails the job.

This repo's own [self-test](.github/workflows/self-test.yml) runs the Action on two fixtures on every push: an honest fix must pass and a hollow one must fail.

## Inputs

| Input | Default | Meaning |
| --- | --- | --- |
| `base` | the PR's base SHA | Ref or SHA to compare against. |
| `test-command` | from `failfirst.config.json`, else `npm test` | Command that runs the test suite. |
| `version` | `0.1.1` | Version of `fail-first-gate` to run. |
| `node-version` | `22` | Node.js version to set up. |
| `path` | `.` | Directory of the repository to check, relative to the workspace. |

## Running it locally

```bash
npm i -D fail-first-gate
npx failfirst init
npx failfirst check --base main
npx failfirst scan --base main
```

Note: install `fail-first-gate` first. A bare `npx failfirst` fetches an unrelated package of that name.

## License

MIT
