# Design

## 1. Layout (mirror of the Rust dependency model)

Rust has one real scalar, `f64`; Dimforge's `simba` is a trait layer (`RealField`) implemented for
it, and nalgebra is generic over `T: RealField`. In Cairo the primitive is the Q32.32
`fixed::Fixed` of [fixed-cairo](https://github.com/bal7hazar/fixed-cairo) (a registry dependency
pinned by version), this repository is the trait layer implemented for it, and nalgebra-cairo is
generic over `T: Real`. There is ONE Q32.32 implementation in the stack: two implementations with
independent rounding choices would break the bit-exact determinism rapier-cairo relies on.

## 2. Numeric semantics are `fixed`'s

`+ - neg` checked `i64`; `*`, fused kernels and `Acc` rescale ONCE with floor; `sqrt` / norms floor of
the exact root; `/`, `recip`, `from_ratio` round to nearest, ties to even, like `f64 /`; `%` is the
exact truncated remainder; constants are rounded to nearest; overflow panics (`'Fixed: overflow'`,
`'Fixed: division by zero'`, …), never wraps.

## 3. The traits

`Real<T>` exposes fused kernels, not just operators, so that generic code rescales once per output
scalar:

```cairo
pub trait Real<T> {
    // constants and predicates under simba-rs names: zero(), one(), pi(), default_epsilon(), is_sign_negative, ...
    fn sum_prod2(a0: T, b0: T, a1: T, b1: T) -> T;            // a0*b0 + a1*b1, one rescale
    fn sum_prod3(..) -> T;  fn sum_prod4(..) -> T;
    fn diff_prod(a: T, b: T, c: T, d: T) -> T;                 // a*b - c*d
    fn mul_add(a: T, b: T, c: T) -> T;  fn lerp(a: T, b: T, t: T) -> T;
    fn norm2(x: T, y: T) -> T;  fn norm3(..) -> T;  fn norm4(..) -> T;   // floor sqrt of the exact sum
    fn sqrt(self: T) -> T;  fn div(a: T, b: T) -> T;  fn div3(x0: T, x1: T, x2: T, d: T) -> (T, T, T); // .. div16
    type Wide;  fn wide_zero() -> Self::Wide;  fn wide_add_prod(w: Self::Wide, a: T, b: T) -> Self::Wide;  // ...
}
```

`Real::Wide` is `fixed::wide::Acc` (a count-agnostic exact accumulator); `wide_mul_scalar` is the exact
triple product with one rounding; `div3..div16` prepare one divisor (`fixed::wide::RecipNearest`),
bit-identical to per-element `div`, cheaper from 3 quotients. `Transcendental<T>` delegates to
`fixed::trig` / `fixed::exp`. Approximate equality is expressed in ulps (raw units).

**The one exception to "neither more nor less"** (owner ruling, 2026-09-24): the fused kernels and
the constants simba-rs has no name for (`TWO`, `HALF`, …) have no counterpart in simba-rs. They stay:
expressing nalgebra-cairo with upstream-named scalar methods only was measured at +94 % to +326 % gas
per sum of products, up to 5 ulp more error, and norms overflowing above |x| > 46,341 where `f64`
does not.

## 4. Zero cost

Every method is an `#[inline(always)]` delegation; the benches (`gas/simba.json`) keep the generic
call equal to the direct `fixed` call (e.g. `bench_real_dot3__generic` = `__direct`).
