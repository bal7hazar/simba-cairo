# PP-S — simba-cairo: a pre-push check, its hook, and retries on tool downloads

Lot of the nalgebra track of Slingfall (orchestrator: herdr project `slingfall-nalgebra`), 2026-10-02.
Owner's request "stop pushing red CI" (2026-10-02): 22 red CI runs of about 770 across the
organisation since 2026-10-01, about 15 of which a local check of seconds to minutes would have
stopped (formatting, generated artefacts not regenerated, script unit tests, compile errors), and 6
infrastructure failures (HTTP 500 while downloading scarb or snforge). Light lot; runs on the VPS.

## 1. Goal

1. `scripts/prepush.sh`: a short local check, **under 2 minutes** on the VPS, that catches what CI
   would catch cheaply:
   - `scarb fmt --check`;
   - the unit tests / self-tests of the Python scripts (`python3 scripts/consumer_cost.py --self-test`,
     and `scripts/gas_report.py`'s if it has one; list what you found);
   - `scarb lint --deny-warnings` and `scarb build` (the workspace is one package: that is "the
     touched packages");
   - **only when their inputs changed** against the push's base (`origin/main` by default, or the
     remote ref the hook receives): the gas snapshot check (`snforge test --workspace` piped into
     `python3 scripts/gas_report.py --check gas/`, as `scripts/check.sh` does) when `crates/**`,
     `gas/**`, `Scarb.toml`, `Scarb.lock`, `.tool-versions` or `scripts/gas_report.py` changed.
     State in the script's header which inputs trigger which check.
   - `export RAYON_NUM_THREADS=${RAYON_NUM_THREADS:-1}` like `scripts/check.sh`.
   - Exit non-zero on the first failure, with a one-line message naming the failed step; print the
     elapsed time at the end.
   `scripts/check.sh` stays the full local equivalent of CI; do not change what it does.
2. `.githooks/pre-push` (executable) runs `scripts/prepush.sh` and blocks the push on failure.
   Set `git config core.hooksPath .githooks` in your worktree (git stores it in the repository's
   common config, so the VPS clone `/home/claude/projects/simba-cairo` gets it too) and show
   `git -C /home/claude/projects/simba-cairo config core.hooksPath`. There is no simba-cairo clone on
   the Mac: say so in the report; nothing to do there.
3. `AGENTS.md`, "Definition of done": run `scripts/prepush.sh` (the hook does it) before every push;
   never push red; never skip the hook (`--no-verify`). Also how to enable the hook in a fresh
   clone (`git config core.hooksPath .githooks`).
4. `.github/workflows/ci.yml` (**the one workflow file this lot changes**): one or two retries on the
   steps that download the tools (`software-mansion/setup-scarb`, `foundry-rs/setup-snfoundry`) in
   both jobs. A `uses:` step cannot be wrapped in a retry action, so a common pattern is: the step
   with an `id` and `continue-on-error: true`, then the same step again with
   `if: steps.<id>.outcome == 'failure'` (a short `sleep` step between is fine). Keep the action pins
   (same shas). Nothing else in the workflow changes.

## 2. Scope: file allowlist

This brief committed verbatim as `docs/briefs/pp-prepush.md` (first commit); `scripts/prepush.sh`
(new); `.githooks/pre-push` (new); `AGENTS.md` (the lines above); `.github/workflows/ci.yml` (the
retries only). Nothing else.

## 3. Acceptance criteria

1. `scripts/prepush.sh` passes on the branch; **measured run time** (the `time` output, real) on the
   VPS in two cases: (a) only a document changed (no gas check), (b) a file under `crates/` changed
   (gas check runs). Both in the report and the PR body, with the machine and the build-lock wait if
   any (the host's scarb/snforge shims queue on a shared heavy-build lock: say how much of the time
   was waiting).
2. The hook blocks a push when the script fails: show it on a throwaway local commit that breaks
   formatting (then drop that commit; never push it).
3. CI green on the PR; the retry steps visible in the workflow and not triggered on a normal run.
4. `core.hooksPath` shown set on the VPS clone.

## 4. Verification and report

Conventional commits, push (through the hook), `gh pr create` per the template (body: what each part
does, the measured times, "Audit: none needed — local tooling and CI retries"), `gh pr checks
--watch` until green. Never merge, never launch a review or any agent yourself. Foreground only.
`REPORT.md` at the worktree root (not committed), `## Summary` first: the measured times, what the
script checks and when, the hook demonstration, Escalations, the PR number and head sha.

Work autonomously, do not ask questions, do not widen the scope.
