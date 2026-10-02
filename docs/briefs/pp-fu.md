# PP-FU — pre-push follow-ups (simba-cairo)

Lot of the nalgebra track of Slingfall (orchestrator: herdr project `slingfall-nalgebra`), 2026-10-02.
Light lot (shell only); runs on the VPS. The pre-push check of this repository is on `main`
(`scripts/prepush.sh`, `.githooks/pre-push`); its reviews left the follow-ups below, and the project
manager asked for two more. Commit this brief verbatim as `docs/briefs/pp-fu.md` (first commit).

## 1. Goal, in order of importance

1. **Untracked files (the red-CI path).** The hook's clean-tree test (`git diff --quiet HEAD`)
   ignores untracked files, while the build compiles them: a never-added `.cairo` file with a
   committed `mod foo;` passes locally and fails CI. Refuse the push when `git status --porcelain
   --untracked-files=all` lists an untracked file under a path that can change a build or a check
   (`crates/`, `tests/` if present, `benchmarks/`, `tools/`, `scripts/`, `gas/`, any `Scarb.toml`,
   `Scarb.lock`, `.tool-versions`), with a message naming the files ("add or remove them, then push").
   Ignored files (`.gitignore`) are not listed by `--porcelain` and stay allowed. This is a read of the
   pushed repository.
2. **Fast docs-only pushes** (`scarb fmt --check`, the self-test of `consumer_cost.py`): gate every fixed check on its inputs, as CI will
   (the CI path-gating lot is the reference: same trigger sets, the toolchain set `.tool-versions`,
   any `Scarb.toml`, any `Scarb.lock`, `.github/workflows/**` triggers everything; prose `.md`
   triggers nothing, a checked `.md` artefact triggers its check). `scarb fmt --check` runs when a
   `.cairo` file or the toolchain set changed; each Python self-test when its script changed; each
   generator check when its generator, its inputs or its checked output changed (read each script to
   find them). A push that changes only prose `.md` files must take **seconds**: measure it.
3. **Lock wait first or in parallel.** When the Cairo block will run, start the `flock -E 75 -w 90`
   wait before the fixed checks, or in parallel with them, so the lock-busy case stays near 2 min
   (not 90 s + the checks). Keep the lock rules: the script holds the lock itself, exports
   `HEAVY_BUILD_LOCK_HELD=1` inside, kills nothing, touches the lock only through `flock -w`, exit 75 =
   busy → `heavy lock busy: Cairo compile left to CI`, pass.
4. **Ancestor-held lock:** before `flock -w`, reuse the shims' test (`HEAVY_BUILD_LOCK_HELD`, or an
   ancestor process holding the lock file: read `~/.local/bin/scarb`) so a caller that already holds
   the lock does not wait 90 s for itself.
5. **Relative `$0`:** resolve the script's own path once (`realpath "$0"`) before any `cd`, and
   re-run that path under flock.
6. **Review notes of #5:** a tag of a tree or blob gives a garbled message (use
   `git rev-parse --verify --quiet "$sha^{commit}" || echo "$sha"`); the tag exemption: skip only when
   the tag's commit is already on `origin/main` (`git merge-base --is-ancestor`), refuse otherwise;
   fix the stale comment `# only deletions` → `# only deletions or skipped tags`.

## 2. Rules

- Allowlist: the brief, `scripts/prepush.sh`, `.githooks/pre-push`, and the header comments of
  those files. Nothing else (not the workflows: another lot edits `ci.yml`).
- Git commands: only reads of this repository, or in a sanitised environment (`env -u GIT_DIR -u
  GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR -u GIT_PREFIX …`). Never `git config
  core.hooksPath` (the owner sets it; it is set on the VPS clone).
- Measured times (real `time` output, VPS, naming the head and the lock wait separately): (a) prose
  docs only; (b) one Cairo file, lock free or on a private `HEAVY_BUILD_LOCK=$(mktemp)` file (say
  which); (c) the same with the shared lock busy. Show the untracked-file refusal on a throwaway
  untracked file (then delete it), and that an ignored file is not refused.
- Push through the hook. All fixes of one review loop in one push. CI: at most one GitHub call per PR
  every 5 minutes, or end your turn. Never merge, never launch a review or any agent yourself.
  Foreground only. `REPORT.md` at the worktree root (not committed), `## Summary` first, with the PR
  number and head sha. Audit: none needed — local tooling. Prefer words over links to external issues
  in PR text and commit messages.

Work autonomously, do not ask questions, do not widen the scope.

