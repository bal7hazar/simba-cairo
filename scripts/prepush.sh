#!/usr/bin/env bash
# Short local check to run before every push (the `.githooks/pre-push` hook runs it); catches what CI
# catches cheaply. `scripts/check.sh` stays the full local equivalent of CI.
#
# Usage: scripts/prepush.sh [BASE]    BASE: the ref the push is compared against (default: origin/main).
#
# Always run (seconds, no lock):
#   scarb fmt --check                              formatting
#   python3 scripts/consumer_cost.py --self-test   the script's own logic, no scarb
#                                                  (scripts/gas_report.py has no self-test: the gas check exercises it)
# The Cairo compile steps run only when an input changed between the merge base of BASE and the working tree:
#   scarb lint --deny-warnings, scarb build        when crates/**, Scarb.toml, Scarb.lock or .tool-versions changed
#   snforge test --workspace | python3 scripts/gas_report.py --check gas/    the gas snapshot check, when
#       crates/**, gas/**, Scarb.toml, Scarb.lock, .tool-versions or scripts/gas_report.py changed.
#
# The heavy-build lock. On the shared VPS the scarb/snforge shims serialise every compile through one lock
# file ($HEAVY_BUILD_LOCK, default ~/orchestrator/heavy-build.lock; it prevents running out of memory) and
# let a nested call run without re-locking when an ancestor process already holds that file. The Cairo steps
# are therefore run as ONE block under `flock -E 75 -w 90 <that same lock file>`: this takes the real lock,
# waiting at most 90 s for its turn. Inside it the scarb/snforge SHIMS are still called, with
# HEAVY_BUILD_LOCK_HELD=1 exported (the lock really is held), which they honour as a pass-through: they
# never wait on the lock a second time. (Calling the real binaries would be equivalent; the shims also set
# nice and the thread caps.) It never bypasses the lock, and it
# only gives up waiting: it never signals or kills the process holding the lock, nor a compile that runs.
# If the lock is not obtained in 90 s the whole Cairo block is skipped, with the single line
# `heavy lock busy: Cairo compile left to CI`, and the push is not blocked (CI runs them).
# Without the lock (no lock directory or no `flock`, as on the Mac) or when a caller already holds it
# (HEAVY_BUILD_LOCK_HELD), the Cairo block runs directly, with no wait. The time the lock was waited for
# and the time the block itself took are printed separately.
# Exits non-zero on the first failure, with a one-line message naming the step.
set -euo pipefail
cd "$(dirname "$0")/.."
# The Cairo compiler is not deterministic on several threads: Sierra, and so the gas snapshot, are only
# reproducible single-threaded.
export RAYON_NUM_THREADS="${RAYON_NUM_THREADS:-1}"

start=$SECONDS
step="start"
trap 'rc=$?; if [[ $rc -ne 0 ]]; then echo "prepush: FAILED at step: ${step} ($((SECONDS - start))s)" >&2; fi' EXIT

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
    : > "$PREPUSH_MARK" # the lock is held: tells the caller it was obtained
    export HEAVY_BUILD_LOCK_HELD=1 # the lock really is held here: the shims run nested, without re-locking
    echo "prepush: heavy lock obtained after $(($(date +%s) - PREPUSH_T0))s of waiting"
    cairo_block
    exit 0
fi

base="${1:-origin/main}"
step="resolve base $base"
git rev-parse --verify --quiet "$base^{commit}" > /dev/null || { echo "prepush: base ref '$base' not found (git fetch origin main?)" >&2; exit 1; }
merge_base=$(git merge-base "$base" HEAD)
changed=$(git diff --name-only --no-renames "$merge_base")

run "scarb fmt --check" scarb fmt --check
run "consumer_cost.py --self-test" python3 scripts/consumer_cost.py --self-test

PREPUSH_DO_BUILD=0
PREPUSH_DO_GAS=0
if grep -Eq '^(crates/|Scarb\.toml$|Scarb\.lock$|\.tool-versions$)' <<< "$changed"; then PREPUSH_DO_BUILD=1; fi
if grep -Eq '^(crates/|gas/|Scarb\.toml$|Scarb\.lock$|\.tool-versions$|scripts/gas_report\.py$)' <<< "$changed"; then PREPUSH_DO_GAS=1; fi
export PREPUSH_DO_BUILD PREPUSH_DO_GAS

if [[ "$PREPUSH_DO_BUILD" == 0 && "$PREPUSH_DO_GAS" == 0 ]]; then
    echo "prepush: Cairo compile skipped (no Cairo source, manifest or gas input changed against $base)"
else
    lock="${HEAVY_BUILD_LOCK:-$HOME/orchestrator/heavy-build.lock}"
    if [[ -z "${HEAVY_BUILD_LOCK_HELD:-}" ]] && command -v flock > /dev/null && [[ -d "$(dirname "$lock")" ]]; then
        step="Cairo compile (the failing step is named above)"
        mark=$(mktemp)
        rm -f "$mark"
        # PREPUSH_MARK appears only once the lock is held: a failed step is told apart from a lock that was
        # not obtained (flock exit 75 after the 90 s) and from any other flock error.
        rc=0
        PREPUSH_INNER=1 PREPUSH_MARK="$mark" PREPUSH_T0=$(date +%s) flock -E 75 -w 90 "$lock" "$0" "$base" || rc=$?
        if [[ -e "$mark" ]]; then
            rm -f "$mark"
            [[ $rc -eq 0 ]] || exit 1 # a step failed inside the lock; it printed its own message
        elif [[ $rc -eq 75 ]]; then
            echo "heavy lock busy: Cairo compile left to CI"
        elif [[ $rc -ne 0 ]]; then
            echo "prepush: flock failed on $lock (exit $rc)" >&2
            exit 1
        fi
    else
        cairo_block
    fi
fi

echo "prepush: ok in $((SECONDS - start))s"
