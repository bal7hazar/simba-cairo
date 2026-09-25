# Changelog

Numeric results are part of the API: any change of a result is a MINOR bump (pre-1.0).

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
