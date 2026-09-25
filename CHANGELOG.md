# Changelog

Numeric results are part of the API: any change of a result is a MINOR bump (pre-1.0).

## 0.1.0 (unreleased)

- First release from this repository. `simba` was developed inside nalgebra-cairo (history kept:
  `git log --follow crates/simba`) and split out on 2026-09-25 to mirror the Rust layout
  (dimforge/simba is separate from dimforge/nalgebra).
- `Real<T>` and `Transcendental<T>` implemented for `fixed::Fixed` (`fixed = "0.3.0"`): constants and
  predicates under simba-rs names, fused kernels (`sum_prod2/3/4`, `diff_prod`, `mul_add`, `lerp`,
  `norm*`, `norm_squared*`), the `fixed::wide::Acc` accumulator (`wide_*`, `wide_mul_scalar`),
  division rounded to nearest (`div`, `recip`) and prepared divisors (`div3..div16`,
  `fixed::wide::RecipNearest`, bit-identical to per-element division), transcendentals delegated to
  `fixed::trig` / `fixed::exp`.
