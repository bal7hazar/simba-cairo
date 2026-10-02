# CI-S — simba-cairo: test jobs run only when their files change

Lot of the nalgebra track of Slingfall (orchestrator: herdr project `slingfall-nalgebra`), 2026-10-02.
Light lot (workflow only, no Cairo build); runs on the VPS. Commit this brief verbatim as
`docs/briefs/ci-paths.md` (first commit). Allowlist: that brief and `.github/workflows/ci.yml`.

## Mapping table (job → paths that trigger it on a pull request)

T = the toolchain set: `.tool-versions`, `Scarb.toml`, `Scarb.lock` (any directory),
`.github/workflows/**`. Prose `**/*.md` never triggers; checked `.md` artefacts do (§5).

| Job (name) | Group | Paths |
|---|---|---|
| `library` (Library (simba)) | `library` | T, `crates/**`, `gas/**`, `scripts/gas_report.py`, `scripts/check.sh` |
| `consumer-cost` (Consumer cost) | `cost` | T, `crates/**`, `scripts/consumer_cost.py`, `consumer_cost.toml` |
| `changes` | — | always |
| `CI result` | — | always (summary, §6 below) |

Read the workflow and every script a job runs before applying the table; if a job reads a file the
table misses, add it and say so in the PR body (a missing trigger is worse than an extra one).
## Common rules (both repositories)

Owner's CI rule (2026-10-02): "CI tests must absolutely run only if files related to the tests were
modified, so docs should skip all tests."

1. **Workflow file this lot changes: `.github/workflows/ci.yml`** (and nothing else under
   `.github/`). Edit it **with the file-editing tool only, never by a script rewrite** (no sed/awk/
   python rewriting the YAML).
2. A first job `changes` computes, **from the changed paths only** (never from a label), one boolean
   output per group of the table below, with `dorny/paths-filter` pinned by sha (nalgebra-cairo
   already pins `dorny/paths-filter@ceb8a2b8f2d89434be7ff52d3de7ec3738c5cc9d # v4.0.3`: use exactly
   that pin in both repositories). Each test job gets `needs: changes` and
   `if: github.event_name == 'push' || needs.changes.outputs.<group> == 'true'` (a job that already
   has `needs`/`if` combines them; a job that `needs` a skipped job must not fail because of it).
3. **Pushes to `main` keep their full CI**: every job runs on `push`, whatever changed.
4. **The toolchain set triggers everything**: `.tool-versions`, any `Scarb.toml`, any `Scarb.lock`,
   `.github/workflows/**`. Put it in every group.
5. **Prose documents trigger nothing; checked `.md` artefacts do.** A `.md` file that a job reads,
   regenerates or compares (for example `docs/API_PARITY.md` for the parity check,
   `docs/PACKAGES.md` for Consumer cost, `gas/*.md` for the gas check, `CHANGELOG.md` if a release
   check reads it, any table a script regenerates) triggers the job that checks it; every other
   `.md` triggers nothing. Find them yourself: grep every script and step a job runs for `.md`
   paths, and list in the PR body each checked `.md` with the job it triggers. A PR that changes only
   prose `.md` files (e.g. `docs/X.md`, `crates/core/README.md` if no job reads it) sets every
   output to false. The tables above say "`**/*.md` never triggers": read that as "prose `.md`".
6. **A final job that always runs**, named `CI result`, `needs:` every other job, `if: always()`.
   It fails when any job that ran failed or was cancelled, and passes only when every job either
   passed or was **skipped by the paths rule**, never skipped by error: for each job, `skipped` is
   accepted only if that job's `changes` output was `false` (and the event is a pull request); a job
   skipped while its output was `true` (e.g. because a job it needs failed or `changes` itself
   failed) fails `CI result`, and `CI result` fails if `changes` did not succeed. It is what
   `gh pr checks` always sees, so the standard's merge command never lacks checks. List which jobs
   it aggregates, with their groups, in a comment.
7. `concurrency`: the PR-only cancel line `cancel-in-progress: ${{ github.event_name ==
   'pull_request' }}` (group unchanged) — already on main in simba-cairo; in nalgebra-cairo it comes
   with #95: keep it.
8. Keep every existing job, step, pin, retry and `RAYON_NUM_THREADS` setting as it is; only add the
   `changes` job, the `needs`/`if` lines and `CI result`.
9. **Show it works**, in the PR body, with the real `changes` outputs from CI logs: (a) this PR itself
   (workflow changed → everything runs); then a throwaway **draft** PR or extra commit on a scratch
   branch is NOT allowed (it would spend the starved Actions queue) — instead, show the filter
   behaviour locally: run the same patterns through a small read-only check (e.g. a shell or Python
   snippet in the worktree, not committed) on three synthetic path lists: docs-only
   (`docs/X.md`, `crates/core/README.md`) → all false; one Cairo file → the expected groups true;
   `.tool-versions` → all true. State the tool's matching semantics you relied on.
10. Git commands: only reads of this repository, or in a sanitised environment (`env -u GIT_DIR -u
    GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR -u GIT_PREFIX`).
11. Push through the repository's pre-push hook (`git -c core.hooksPath=.githooks push` if the
    clone's config does not set it; never write the config). All fixes of one review loop in one
    push. CI: at most one GitHub call per PR every 5 minutes, or end your turn. Never merge, never
    launch a review or any agent yourself. Foreground only. `REPORT.md` at the worktree root (not
    committed), `## Summary` first, with the PR number and head sha. Prefer words over links to
    external issues in PR text and commit messages. Audit: none needed — CI gating, every job still
    runs on main.

Work autonomously, do not ask questions, do not widen the scope.
