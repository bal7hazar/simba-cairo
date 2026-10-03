# REC-S — record of the simba 0.3.0 publication (documents only)

Lot of the nalgebra track of Slingfall (orchestrator: herdr project `slingfall-nalgebra`), 2026-10-03.
Light lot on the VPS. Commit this brief verbatim as `docs/briefs/rec-simba-0.3.0.md` (first commit).

simba 0.3.0 was published by the orchestrator on 2026-10-03, on the project manager's go, from commit
`6d791f9570c17fcc198721e71331ceab3f694cc6`: registry read-back checksum
`sha256:b2477769287bb0f3e920410c480ab6bf8117cef5f6b960b35f056c044863de13` (equal to the request), annotated
tag `v0.3.0` on that commit, GitHub release `v0.3.0`. Verify each fact yourself (scarbs.xyz index
`https://scarbs.xyz/api/v1/index/si/mb/simba.json`, `git ls-remote --tags origin v0.3.0`, `gh release view
v0.3.0 -R bal7hazar/simba-cairo`).

Edit, allowlist exactly these two files:
1. `docs/releases/0.3.0.md`: status "published 2026-10-03" with the read-back checksum, the tag and the release
   link; label the size figures ("16833 bytes compressed; scarb: 10 files, 89.08 KiB unpacked"); one line saying
   the release commit is 6d791f9 (#10, which moved the `is_sign_positive(0)` entry under "Changed"), not
   d609143 (#9) named by the brief of #11.
2. `CHANGELOG.md`: the 0.3.0 heading dated (2026-10-03) instead of "unreleased". Nothing else.

One PR `docs(release): record simba 0.3.0`; "Audit: none needed — documents". Never merge, never launch a
review or any agent; foreground only; `REPORT.md` at the worktree root (not committed).

Reading CI logs (programme rule): wait for the run to complete, then `gh run view <id> -R <owner>/<repo> --log-failed`, alone in its call (if your thread cannot run it, name the job and run id in your report and end your turn: the orchestrator relays the log). Never `gh api …/logs`. To read a sibling repository (simba-cairo, fixed-cairo), use the Read tool on its checkout. A bare command refused: report its exact text, no other attempt. At most one GitHub call per PR every 5 minutes. Never probe the shared heavy-build lock. Mac repositories by absolute path (/Users/bal7hazar/git/<repo>).
Signals (programme rule after an incident): a thread, a test or a script signals only processes it started itself, by pid or pgid taken from `$!` or ids it recorded. Never find a pid by searching (`ps | grep`, `pgrep`, `pkill`, `killall`).
Picking up main: after any push (and until nexus #83 is installed), run `git merge origin/main`, alone in its call. `git rebase origin/main` in exactly that form is allowed only before your first push, once #83 is installed; every other rebase form and every force push stay refused.
Files: to remove an untracked file of your own worktree, use `git clean -f -- <exact path>` (nexus #92); a bare `rm` stays refused. NEVER run `git clean` with `-d`, `-x` or `-X`: it deletes your own .herdr-project folder (brief, report). `gh pr edit` works for a PR title and body (nexus #91).
Memory (organisation rule): a build or test that may pass 8 GB runs on the Mac, or on the VPS only under a hard cap: `prlimit --as=8589934592 -- /usr/bin/time -v <command>`, never uncapped; every peak-memory measure is capped that way. Keep test files small enough that their build stays well under 8 GB (split goldens or tables before they grow).

Work autonomously, do not ask questions, do not widen the scope.

