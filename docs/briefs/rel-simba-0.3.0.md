# REL-S — release request for simba 0.3.0 (documents only)

Lot of the nalgebra track of Slingfall (orchestrator: herdr project `slingfall-nalgebra`), 2026-10-03.
Light lot on the VPS. Commit this brief verbatim as `docs/briefs/rel-simba-0.3.0.md` (first commit).

## Goal

Write the release request of simba 0.3.0 for the project manager's go (slingfall `OPERATIONS.md` §7: the
request names package, version, commit and the sha256 of the archive built from a checkout detached
exactly at that commit). **You publish nothing**; never run `scarb publish`.

1. Release commit: `d60914335887d74d93bd2268cb8e10614fd9559c` (simba-cairo main after #9).
2. Check the manifest can be published as it stands: its `[dev-dependencies]` (`snforge_std`,
   `assert_macros`) are on the registry; `fixed = "0.5.0"` is on scarbs.xyz. If a dev-dependency is not on
   the registry, stop and report (that case needs a release commit off main, decided by the orchestrator).
3. In a temporary detached checkout at that commit, created with `git worktree add --detach <dir>
   d60914335887d74d93bd2268cb8e10614fd9559c` (a worktree of this clone; remove it afterwards with
   `git worktree remove <dir>`): `scarb package -p simba` (through the shims; it takes the heavy lock),
   then the sha256 of the produced `.tar.zst` archive (`sha256sum`). Record scarb's version line.
   Run it twice from that same checkout and show both sha256 are equal (reproducible).
4. `docs/releases/0.3.0.md`: one table row (package `simba`, version `0.3.0`, commit, sha256, archive file
   name and size), the toolchain (Scarb 2.20.1), the dev-dependency check, and "requested, not
   published". Allowlist: the brief and that file only.

Conventional commit `docs(release): request for simba 0.3.0`; PR per the template ("Audit: none needed —
release request, documents only"); never merge, never launch a review or any agent; foreground only;
`REPORT.md` at the worktree root (not committed) with the sha256s and the PR number and head.

Reading CI logs (programme rule): wait for the run to complete, then `gh run view <id> -R <owner>/<repo> --log-failed`, alone in its call (if your thread cannot run it, name the job and run id in your report and end your turn: the orchestrator relays the log). Never `gh api …/logs`. To read a sibling repository (simba-cairo, fixed-cairo), use the Read tool on its checkout. A bare command refused: report its exact text, no other attempt. At most one GitHub call per PR every 5 minutes. Never probe the shared heavy-build lock. Mac repositories by absolute path (/Users/bal7hazar/git/<repo>).
Signals (programme rule after an incident): a thread, a test or a script signals only processes it started itself, by pid or pgid taken from `$!` or ids it recorded. Never find a pid by searching (`ps | grep`, `pgrep`, `pkill`, `killall`).
Picking up main: after any push (and until nexus #83 is installed), run `git merge origin/main`, alone in its call. `git rebase origin/main` in exactly that form is allowed only before your first push, once #83 is installed; every other rebase form and every force push stay refused.
Files: to remove an untracked file of your own worktree, use `git clean -f -- <exact path>` (nexus #92); a bare `rm` stays refused. NEVER run `git clean` with `-d`, `-x` or `-X`: it deletes your own .herdr-project folder (brief, report). `gh pr edit` works for a PR title and body (nexus #91).
Memory (organisation rule): a build or test that may pass 8 GB runs on the Mac, or on the VPS only under a hard cap: `prlimit --as=8589934592 -- /usr/bin/time -v <command>`, never uncapped; every peak-memory measure is capped that way. Keep test files small enough that their build stays well under 8 GB (split goldens or tables before they grow).

Work autonomously, do not ask questions, do not widen the scope.
