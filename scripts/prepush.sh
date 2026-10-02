#!/usr/bin/env bash
# Short local check to run before every push (the `.githooks/pre-push` hook runs it); catches what CI
# catches cheaply. `scripts/check.sh` stays the full local equivalent of CI.
#
# Usage: scripts/prepush.sh [BASE]    BASE: the ref the push is compared against (default: origin/main).
#
# Every check is gated on its inputs, as CI is (the path-gating of .github/workflows/ci.yml is the
# reference). The changed paths are those between the merge base of BASE and the working tree. The
# toolchain set is `.tool-versions`, any `Scarb.toml`, any `Scarb.lock`, and `.github/workflows/**`, which
# triggers everything; prose `.md` files (`crates/**/*.md`, docs, ...) trigger nothing, a checked `.md`
# artefact (`gas/*.md`) triggers its check. A push of prose only takes seconds.
#   scarb fmt --check                              a `.cairo` file or the toolchain set changed
#   python3 scripts/consumer_cost.py --self-test   scripts/consumer_cost.py or a workflow changed (its own
#                                                  logic, no scarb; consumer_cost.toml is not read by it)
#                                                  (scripts/gas_report.py has no self-test: the gas check exercises it)
#   scarb lint --deny-warnings, scarb build        crates/** (not .md), the toolchain set or scripts/check.sh
#   snforge test --workspace | python3 scripts/gas_report.py --check gas/    the gas snapshot check: the
#       generator (scripts/gas_report.py), its inputs (crates/** not .md, the toolchain set, scripts/check.sh)
#       or its checked output (gas/**) changed.
#
# The heavy-build lock. On the shared VPS the scarb/snforge shims serialise every compile through one lock
# file ($HEAVY_BUILD_LOCK, default ~/orchestrator/heavy-build.lock; it prevents running out of memory) and
# let a nested call run without re-locking when $HEAVY_BUILD_LOCK_HELD is set or an ancestor process holds
# that file. The Cairo steps (lint, build, tests, gas check) are run as ONE block under
# `flock -E 75 -w 90 <that same lock file>`: this takes the real lock, waiting at most 90 s for its turn.
# Inside it the scarb/snforge SHIMS are still called, with HEAVY_BUILD_LOCK_HELD=1 exported (the lock really
# is held), which they honour as a pass-through: they never wait on the lock a second time. (Calling the
# real binaries would be equivalent; the shims also set nice and the thread caps.) It never bypasses the
# lock, and it only gives up waiting: it never signals or kills the process holding the lock, nor a compile
# that runs; it touches the lock only through `flock -w`.
# The wait starts BEFORE the fixed checks (fmt, self-test) and overlaps them: the waiting process, once it
# holds the lock, holds it until those checks have passed and then runs the Cairo block; if one of them
# fails the script exits at once, and the waiting process (which holds and runs nothing) ends by itself as
# soon as it sees that. A busy lock thus costs about 90 s in all, not 90 s plus the checks. If the lock is
# not obtained in 90 s the whole Cairo block is skipped, with the single line
# `heavy lock busy: Cairo compile left to CI`, and the push is not blocked (CI runs them).
# Without the lock (no lock directory or no `flock`, as on the Mac), or when a caller already holds it
# (HEAVY_BUILD_LOCK_HELD, or an ancestor process with the lock file open: the test of the shims), the Cairo
# block runs directly, with no wait. The time the lock was waited for and the time the block itself took are
# printed separately.
# Exits non-zero on the first failure, with a one-line message naming the step.
set -euo pipefail
# The script's own path, resolved once before any `cd` (it is re-run under flock).
self=$(realpath "$0" 2> /dev/null || readlink -f "$0")
cd "$(dirname "$self")/.."
# The Cairo compiler is not deterministic on several threads: Sierra, and so the gas snapshot, are only
# reproducible single-threaded.
export RAYON_NUM_THREADS="${RAYON_NUM_THREADS:-1}"

start=$SECONDS
step="start"
workdir=""
on_exit() {
    local rc=$?
    if [[ $rc -ne 0 ]]; then echo "prepush: FAILED at step: ${step} ($((SECONDS - start))s)" >&2; fi
    if [[ -n "$workdir" ]]; then rm -rf "$workdir"; fi
}
trap on_exit EXIT

run() { step="$1"; shift; local t=$SECONDS; echo "prepush: $step"; "$@"; echo "prepush: $step: $((SECONDS - t))s"; }

# The Cairo block: run inside the lock (inner mode, re-executed by flock) or directly.
cairo_block() {
    local t=$SECONDS
    if [[ "$PREPUSH_DO_BUILD" == 1 ]]; then
        run "scarb lint --deny-warnings" scarb lint --deny-warnings
        run "scarb build" scarb build
    fi
    if [[ "$PREPUSH_DO_GAS" == 1 ]]; then
        local t2=$SECONDS output
        step="snforge test --workspace"
        echo "prepush: $step, then the gas snapshot check"
        output=$(snforge test --workspace) || { echo "$output"; exit 1; }
        echo "$output" | tail -n 1
        echo "prepush: $step: $((SECONDS - t2))s"
        step="gas_report.py --check gas/"
        echo "$output" | python3 scripts/gas_report.py --check gas/
    fi
    echo "prepush: Cairo block: $((SECONDS - t))s of work"
}

if [[ "${PREPUSH_INNER:-}" == 1 ]]; then
    # Started by flock in the background of the main run, which creates $PREPUSH_DIR. Reaching this line means
    # the lock is held. Tell the caller, then wait for it to say that the fixed checks passed ($PREPUSH_DIR/go);
    # when it is gone (a check failed, or the caller died) end without running anything.
    got=$(date +%s)
    : > "$PREPUSH_DIR/held"
    until [[ -e "$PREPUSH_DIR/go" ]]; do
        [[ -d "$PREPUSH_DIR" ]] && kill -0 "$PREPUSH_PARENT" 2> /dev/null || exit 0
        sleep 0.2
    done
    export HEAVY_BUILD_LOCK_HELD=1 # the lock really is held here: the shims run nested, without re-locking
    echo "prepush: heavy lock obtained after $((got - PREPUSH_T0))s of waiting (the fixed checks ran meanwhile)"
    cairo_block
    exit 0
fi

# The test of the scarb/snforge shims: does an ancestor process (this one included: a caller may have exec'd
# us under `flock <lock> ...`) hold the lock file open?
ancestor_holds_lock() {
    local lock="$1" p=$$ fds
    while [[ -n "$p" && "$p" -gt 1 ]] 2> /dev/null; do
        fds=$(ls -l "/proc/$p/fd" 2> /dev/null || true)
        if grep -qF -- "$lock" <<< "$fds"; then return 0; fi
        p=$(sed -n 's/^PPid:[[:space:]]*//p' "/proc/$p/status" 2> /dev/null) || return 1
    done
    return 1
}

# Copy what the waiting process wrote to $2 to our own output until process $1 ends.
relay_until_exit() {
    local pid="$1" out="$2" off=0 size
    flush() {
        size=$(wc -c < "$out")
        if ((size > off)); then
            tail -c +$((off + 1)) "$out" | head -c $((size - off))
            off=$size
        fi
    }
    while kill -0 "$pid" 2> /dev/null; do flush; sleep 0.3; done
    flush
}

base="${1:-origin/main}"
step="resolve base $base"
git rev-parse --verify --quiet "$base^{commit}" > /dev/null || { echo "prepush: base ref '$base' not found (git fetch origin main?)" >&2; exit 1; }
merge_base=$(git merge-base "$base" HEAD)
changed=$(git diff --name-only --no-renames "$merge_base")
changed_code=$(grep -Ev '\.md$' <<< "$changed" || true) # prose .md files trigger nothing, except the checked gas/*.md

# What each check depends on (see the header).
toolchain='^(\.tool-versions$|(.*/)?Scarb\.toml$|(.*/)?Scarb\.lock$|\.github/workflows/)'
has() { grep -Eq "$1" <<< "$2"; }
DO_FMT=0 DO_COST_TEST=0
PREPUSH_DO_BUILD=0 PREPUSH_DO_GAS=0
if has '\.cairo$' "$changed" || has "$toolchain" "$changed"; then DO_FMT=1; fi
if has '^(scripts/consumer_cost\.py$|\.github/workflows/)' "$changed"; then DO_COST_TEST=1; fi
if has "$toolchain|^(crates/|scripts/check\.sh$)" "$changed_code"; then PREPUSH_DO_BUILD=1; PREPUSH_DO_GAS=1; fi
if has '^(gas/|scripts/gas_report\.py$)' "$changed"; then PREPUSH_DO_GAS=1; fi
export PREPUSH_DO_BUILD PREPUSH_DO_GAS

# How the Cairo block will run: under the real lock (flock, the wait started now), or directly.
mode=none
if [[ "$PREPUSH_DO_BUILD" == 1 || "$PREPUSH_DO_GAS" == 1 ]]; then
    lock="${HEAVY_BUILD_LOCK:-$HOME/orchestrator/heavy-build.lock}"
    if [[ -z "${HEAVY_BUILD_LOCK_HELD:-}" ]] && command -v flock > /dev/null && [[ -d "$(dirname "$lock")" ]] \
        && ! ancestor_holds_lock "$lock"; then
        mode=flock
    else
        mode=direct
    fi
fi

waiter=""
if [[ "$mode" == flock ]]; then
    workdir=$(mktemp -d)
    # PREPUSH_DIR/held appears only once the lock is held: a failed step is told apart from a lock that was
    # not obtained (flock exit 75 after the 90 s) and from any other flock error. The waiting process writes
    # to a file, not to our terminal or pipes, so that one left behind by an early failure holds none of them.
    PREPUSH_INNER=1 PREPUSH_DIR="$workdir" PREPUSH_PARENT=$$ PREPUSH_T0=$(date +%s) \
        flock -E 75 -w 90 "$lock" "$self" "$base" > "$workdir/out" 2>&1 < /dev/null &
    waiter=$!
fi

if [[ "$DO_FMT" == 1 ]]; then run "scarb fmt --check" scarb fmt --check; else echo "prepush: scarb fmt --check skipped (no .cairo file or toolchain input changed against $base)"; fi
if [[ "$DO_COST_TEST" == 1 ]]; then
    run "consumer_cost.py --self-test" python3 scripts/consumer_cost.py --self-test
else
    echo "prepush: consumer_cost.py --self-test skipped (scripts/consumer_cost.py unchanged against $base)"
fi

case "$mode" in
    none) echo "prepush: Cairo compile skipped (no Cairo source, manifest or gas input changed against $base)" ;;
    direct) cairo_block ;;
    flock)
        step="Cairo compile (the failing step is named above)"
        : > "$workdir/go"
        relay_until_exit "$waiter" "$workdir/out"
        rc=0
        wait "$waiter" || rc=$?
        if [[ -e "$workdir/held" ]]; then
            [[ $rc -eq 0 ]] || exit 1 # a step failed inside the lock; it printed its own message
        elif [[ $rc -eq 75 ]]; then
            echo "heavy lock busy: Cairo compile left to CI"
        elif [[ $rc -ne 0 ]]; then
            echo "prepush: flock failed on $lock (exit $rc)" >&2
            exit 1
        fi
        ;;
esac

echo "prepush: ok in $((SECONDS - start))s"
