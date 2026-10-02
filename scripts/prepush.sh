#!/usr/bin/env bash
# Short local check to run before every push (the `.githooks/pre-push` hook runs it); catches what CI
# catches cheaply. `scripts/check.sh` stays the full local equivalent of CI.
#
# Usage: scripts/prepush.sh [BASE]    BASE: the ref the push is compared against (default: origin/main).
#
# Always run (seconds):
#   scarb fmt --check                              formatting
#   python3 scripts/consumer_cost.py --self-test   the script's own logic, no scarb
#                                                  (scripts/gas_report.py has no self-test: the gas check exercises it)
#   scarb lint --deny-warnings                     lint
#   scarb build                                    compile (the workspace is one package)
# Run only when an input changed between the merge base of BASE and the working tree:
#   snforge test --workspace | python3 scripts/gas_report.py --check gas/    the gas snapshot check, when
#   crates/**, gas/**, Scarb.toml, Scarb.lock, .tool-versions or scripts/gas_report.py changed.
# Exits non-zero on the first failure, with a one-line message naming the step.
set -euo pipefail
cd "$(dirname "$0")/.."
# The Cairo compiler is not deterministic on several threads: Sierra, and so the gas snapshot, are only
# reproducible single-threaded.
export RAYON_NUM_THREADS="${RAYON_NUM_THREADS:-1}"

start=$SECONDS
step="start"
trap 'rc=$?; if [[ $rc -ne 0 ]]; then echo "prepush: FAILED at step: ${step} ($((SECONDS - start))s)" >&2; fi' EXIT

run() { step="$1"; shift; echo "prepush: $step"; "$@"; }

base="${1:-origin/main}"
step="resolve base $base"
git rev-parse --verify --quiet "$base^{commit}" > /dev/null || { echo "prepush: base ref '$base' not found (git fetch origin main?)" >&2; exit 1; }
merge_base=$(git merge-base "$base" HEAD)
changed=$(git diff --name-only "$merge_base")

run "scarb fmt --check" scarb fmt --check
run "consumer_cost.py --self-test" python3 scripts/consumer_cost.py --self-test
run "scarb lint --deny-warnings" scarb lint --deny-warnings
run "scarb build" scarb build

if grep -Eq '^(crates/|gas/|Scarb\.toml$|Scarb\.lock$|\.tool-versions$|scripts/gas_report\.py$)' <<< "$changed"; then
    step="snforge test --workspace"
    echo "prepush: $step, then the gas snapshot check"
    output=$(snforge test --workspace) || { echo "$output"; exit 1; }
    echo "$output" | tail -n 1
    step="gas_report.py --check gas/"
    echo "$output" | python3 scripts/gas_report.py --check gas/
else
    echo "prepush: gas snapshot check skipped (no input changed against $base)"
fi

echo "prepush: ok in $((SECONDS - start))s"
