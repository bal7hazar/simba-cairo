# Changelog

Numeric results are part of the API: any change of a result is a MINOR bump (pre-1.0).

## 0.3.0 (unreleased)

### Changed

- **Result change**: `Real::is_sign_positive(0)` now returns `true` (was `false`), following simba-rs
  (`+0.0` is positive) and fixed's `is_sign_positive`; a result change for callers that branch on it at
  zero. It forwards to `fixed::FixedTrait::is_sign_positive` (`self >= 0`, there is no negative zero)
  instead of `is_positive` (`self > 0`).
- `fixed = "0.5.0"` (was 0.4.0). Breaking under pre-1.0 caret resolution: consumers must pin `fixed`
  0.5 as well. No existing result changes through it: `fixed` 0.5.0 is a pure addition (its
  changelog: "no numeric result of 0.4.0 changes"), and every result of a method simba already
  delegated to is unchanged.

### Added

- `Transcendental::{sinh_cosh, asinh, acosh, atanh}` (simba-rs `ComplexField` names), delegating to
  `fixed::exp::ExpTrait`. `sinh_cosh` is bit-identical to `(sinh, cosh)` from one shared
  exponential; `asinh` / `acosh` / `atanh` are within 0.68 ulp (`atanh` 0.57), exactly odd
  (`asinh`, `atanh`). Domain errors are `fixed`'s, not simba-rs's NaN: `acosh` panics
  (`'Fixed: acosh domain'`) below 1, `atanh` panics (`'Fixed: atanh domain'`) for `|x| >= 1`.
- Forwarded from `fixed` (simba-rs `RealField` / `ComplexField` names, each with a zero-cost bench):
  `Real::{copysign, ceil, round, trunc, fract, powi, hypot, frac_pi_8, frac_2_pi}` and
  `Transcendental::{exp2, exp_m1, ln_1p, log, log2, log10, powf}`. Overflow and domain errors panic
  with `fixed`'s messages where `f64` returns an infinity or NaN. `hypot` is `norm2` (floor of the
  exact root).

## 0.2.0 (2026-09-25)

- `fixed = "0.4.0"` (was 0.3.0). Breaking under pre-1.0 caret resolution: `fixed::Fixed` is
  re-exported and every trait is typed on it, so consumers must pin `fixed` 0.4 as well. No
  existing result changes (`fixed` 0.4.0 is a pure addition).
- `Transcendental::{sinh, cosh, tanh, sinhc, coshc}` (simba-rs `ComplexField` names), delegating
  to `fixed::exp::ExpTrait` (within 1.5 ulp; `sinhc(0) = coshc(0) = 1` like simba-rs).

## 0.1.0 (2026-09-25)

- First release from this repository. `simba` was developed inside nalgebra-cairo (history kept:
  `git log --follow crates/simba`) and split out on 2026-09-25 to mirror the Rust layout
  (dimforge/simba is separate from dimforge/nalgebra).
- `Real<T>` and `Transcendental<T>` implemented for `fixed::Fixed` (`fixed = "0.3.0"`): constants and
  predicates under simba-rs names, fused kernels (`sum_prod2/3/4`, `diff_prod`, `mul_add`, `lerp`,
  `norm*`, `norm_squared*`), the `fixed::wide::Acc` accumulator (`wide_*`, `wide_mul_scalar`),
  division rounded to nearest (`div`, `recip`) and prepared divisors (`div3..div16`,
  `fixed::wide::RecipNearest`, bit-identical to per-element division), transcendentals delegated to
  `fixed::trig` / `fixed::exp`.
