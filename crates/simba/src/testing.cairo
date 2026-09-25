//! Test-only helpers for the gas benchmarks (AGENTS.md).
//!
//! Sierra gas is deterministic, so a single call per test is enough: the figure reported by
//! snforge for a `bench_<group>__<variant>` test is compared against the `bench_<group>__baseline`
//! test of the same group (same inputs, same assertions, no operation).
//!
//! Every benchmark test MUST be `#[inline(never)]`: snforge otherwise inlines some test bodies into
//! its generated wrapper and not others, which shifts `raw - baseline` by ~1k gas at random.

/// Opaque identity: prevents the compiler from const-folding benchmark inputs.
#[inline(never)]
pub fn black_box<T>(value: T) -> T {
    value
}
