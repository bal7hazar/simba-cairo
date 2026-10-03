# SIMBA-F8 — simba 0.3.0: fixed 0.5.0, the hyperbolic functions, and forwarding what fixed already has

Lot of the nalgebra track of Slingfall (orchestrator: herdr project `slingfall-nalgebra`), 2026-10-03.
fixed 0.5.0 is published on scarbs.xyz (tag v0.5.0); it adds `ExpTrait::sinh_cosh` (one shared exponential)
and `asinh` / `acosh` / `atanh`. Runs on the VPS (small Cairo build; writes the gas snapshot).

## 1. Goal

1. **fixed 0.5.0**: `fixed = "0.5.0"` in `crates/simba/Scarb.toml` (and `Scarb.lock` by scarb). Read fixed
   0.5.0's CHANGELOG / API (its README and `packages/fixed/src/` in the fixed-cairo checkout at
   `/home/claude/projects/fixed-cairo`, read with the Read tool) for every change that touches what simba
   delegates to; any changed result of a delegated method is listed in the report and the CHANGELOG.
2. **`Transcendental::{sinh_cosh, asinh, acosh, atanh}`** (simba-rs `ComplexField` names and semantics;
   `sinh_cosh` returns `(sinh, cosh)` from one shared exponential), each delegating to fixed's kernel with
   `#[inline(always)]`, no arithmetic here (`AGENTS.md`), with a zero-cost bench
   `bench_real_<op>__generic` equal to the direct fixed call (`AGENTS.md` convention) and unit tests in the
   file's `#[cfg(test)] mod tests` (owner's placement rule). Domain errors (acosh < 1, |atanh| ≥ 1) behave as
   fixed's kernels do; document it.
3. **Forward what fixed already has** (row R1 of `nalgebra-cairo/docs/research/api-1.md`, read it from the
   nalgebra-cairo checkout with the Read tool, section 3–4): every simba-rs `RealField` / `ComplexField`
   method that the report lists as a gap AND that fixed 0.5.0 provides with the same semantics gets a
   delegating method, same rules (inline, zero-cost bench, tests). List the ones you add and the ones you
   leave (with the reason) in the report.
4. **`is_sign_positive` at zero** (carried minor of the review of nalgebra-cairo #100): simba's version
   forwards to `FixedTrait::is_positive` (`self > 0`), so `is_sign_positive(0)` is `false`; simba-rs on f64
   gives `true` for `+0.0`. Forward to fixed's `is_sign_positive` (zero is positive) instead. This is a
   behaviour change: test it and name it in the CHANGELOG.
5. **Version 0.3.0** (MINOR: fixed's numeric changes and the behaviour change above): `version` in the
   workspace `Scarb.toml`, a `CHANGELOG.md` 0.3.0 entry (date left as "unreleased"), README if it names
   the version or the method list. **No publication** in this lot: the orchestrator publishes after the
   merge, on the project manager's go.

## 2. Allowlist

This brief verbatim as `docs/briefs/simba-f8.md` (first commit); `crates/simba/src/**`; `crates/simba/Scarb.toml`;
workspace `Scarb.toml` (version only); `Scarb.lock` (by scarb); `gas/simba.json`, `gas/simba.md`
(regenerated); `consumer_cost.toml` (only the `simba_with_fixed` closure's `fixed@0.5.0`); `CHANGELOG.md`;
`README.md`. Not: `.github/**`, `scripts/**`.

## 3. Verification

`scripts/prepush.sh` (the hook runs it) green; every existing test passes — a test whose expected value
changes only because fixed 0.5.0's result changed is reported with old/new values and the fixed CHANGELOG
line that explains it (if a change is not explained by fixed's CHANGELOG, stop and escalate); gas snapshot
regenerated with `RAYON_NUM_THREADS=1`; the new zero-cost benches equal their direct calls; CI green.
Consumer cost: the closure `simba_with_fixed` within its gates on CI.

## 4. Report

PR body and `REPORT.md` (worktree root, not committed), `## Summary` first: methods added, the
`is_sign_positive` change, any result changed by fixed 0.5.0 (with its explanation), gas summary, Consumer
cost, "Audit: none needed — delegating methods, zero-cost benches, results checked against fixed",
the PR number and head sha. Conventional commits; all fixes of one review loop in one push; never merge,
never launch a review or any agent; foreground only. Prefer words over links to external issues.

Reading CI logs (programme rule, nexus #82): one of these, alone in the call, with no redirect and no pipe (read the output as it comes): `gh api repos/<o>/<r>/actions/jobs/<id>/logs`, `gh api repos/<o>/<r>/actions/runs/<id>/logs`, `gh run view <id> --log` or `--log-failed`; every other `gh api` form stays denied. If your machine does not allow them yet, wait for the run to complete and use `gh run view <id> --log-failed`. To read a sibling repository (e.g. simba-cairo or fixed-cairo), use the Read tool on its checkout, not git commands there. A bare command refused: report its exact text, no other attempt. At most one GitHub call per PR every 5 minutes. Never probe the shared heavy-build lock. Mac repositories by absolute path (/Users/bal7hazar/git/<repo>).
Signals (programme rule after an incident): a thread, a test or a script signals only processes it started itself, by pid or pgid taken from `$!` or ids it recorded. Never find a pid by searching (`ps | grep`, `pgrep`, `pkill`, `killall`).
Picking up main: after any push (and until nexus #83 is installed), run `git merge origin/main`, alone in its call. `git rebase origin/main` in exactly that form is allowed only before your first push, once #83 is installed; every other rebase form and every force push stay refused.

Work autonomously, do not ask questions, do not widen the scope.

