//! Scalar abstraction (DESIGN D3): what `nalgebra` needs from a number.
//!
//! `nalgebra` types are generic over `T` with `+Real<T>` (plus the corelib operator traits they
//! use: `Add`, `Sub`, `Mul`, `Neg`, `PartialOrd`, `PartialEq`, `Copy`, `Drop`). The trait exposes
//! FUSED kernels, not just operators: generic code must route every sum of products through
//! `sum_prod*` / `diff_prod` / `mul_add` / the wide accumulator, so that a fixed-point scalar
//! rounds once per output and pays one overflow check, and every division through `Real::div` /
//! `Real::rem` / `Real::recip`.
//!
//! Counterpart of upstream `simba::scalar::RealField` (+ `ComplexField` helpers), implemented
//! here for the one scalar of the stack, glam.cairo's `fixed::Fixed` (as upstream implements it
//! for `f64`). Transcendental functions live in the separate `Transcendental` trait.
//!
//! # Numeric specification: `fixed`'s
//!
//! `FixedReal` and `FixedTranscendental` add no arithmetic of their own: every method is an
//! `#[inline(always)]` call to `fixed`'s public API (or a composition of its public kernels and
//! accumulators, rounded once as `fixed` defines it). So, as documented in glam.cairo's
//! `docs/DESIGN.md` section 2:
//!
//! - every rescale (products, fused kernels, `Acc::narrow`) rounds toward negative infinity
//!   (floor); `sqrt` and the `norm*` kernels return the floor of the exact root;
//! - `div`, `recip` and `from_ratio` are correctly rounded: to NEAREST, ties to even, like Rust's
//!   `f64 /` (exact whenever the quotient is representable); `rem` is the exact truncated
//!   remainder (sign of the dividend), like Rust's float `%`;
//! - the transcendental functions of `fixed::trig` round their final rescale to nearest;
//! - constants are rounded to nearest;
//! - overflow panics with `'Fixed: overflow'` (or the corelib's `'i64_add Overflow'`-style
//!   message for the plain `+` / `-` / unary `-`), a zero divisor with `'Fixed: division by
//!   zero'`, a negative square root with `'Fixed: sqrt negative'`; never wraps.

use fixed::exp::ExpTrait;
use fixed::trig::TrigTrait;
use fixed::wide::{self, Acc, AccTrait, RecipNearestTrait};
use fixed::{Fixed, FixedTrait, fixed as consts};

/// Real scalar: constants, conversions, helpers, fused kernels and wide accumulation.
///
/// Numeric contract for implementors: deterministic, a single rounding per output, panics instead
/// of wrapping. The rounding of each method for `fixed::Fixed` is in the module documentation.
pub trait Real<T> {
    /// Exact accumulator of unscaled products, see `wide_zero`.
    type Wide;

    // --- constants: simba-rs's names (`num::Zero::zero`, `num::One::one`, `RealField::pi`, ...)
    // ---

    /// 0. Upstream: `num::Zero::zero`.
    fn zero() -> T;
    /// 1. Upstream: `num::One::one`.
    fn one() -> T;
    /// Smallest positive value (1 ulp). Upstream: `approx::AbsDiffEq::default_epsilon`; not a
    /// float-style machine epsilon.
    fn default_epsilon() -> T;
    /// Smallest value. Upstream: `RealField::min_value` (`Option<Self>`, always `Some` here).
    fn min_value() -> Option<T>;
    /// Largest value. Upstream: `RealField::max_value` (`Option<Self>`, always `Some` here).
    fn max_value() -> Option<T>;
    /// π. Upstream: `RealField::pi`.
    fn pi() -> T;
    /// 2π. Upstream: `RealField::two_pi`.
    fn two_pi() -> T;
    /// π/2. Upstream: `RealField::frac_pi_2`.
    fn frac_pi_2() -> T;
    /// π/3. Upstream: `RealField::frac_pi_3`.
    fn frac_pi_3() -> T;
    /// π/4. Upstream: `RealField::frac_pi_4`.
    fn frac_pi_4() -> T;
    /// π/6. Upstream: `RealField::frac_pi_6`.
    fn frac_pi_6() -> T;
    /// 1/π. Upstream: `RealField::frac_1_pi`.
    fn frac_1_pi() -> T;
    /// Euler's number. Upstream: `RealField::e`.
    fn e() -> T;
    /// ln 2. Upstream: `RealField::ln_2`.
    fn ln_2() -> T;
    /// ln 10. Upstream: `RealField::ln_10`.
    fn ln_10() -> T;

    // --- constants without a simba-rs name: the documented scalar exception ---------------------
    //
    // Upstream builds them with `crate::convert(0.5)` (an `f64` literal conversion); Cairo has no
    // such conversion, so the ones nalgebra uses are associated constants (owner ruling
    // 2026-09-24).

    /// -1.
    const NEG_ONE: T;
    /// 2.
    const TWO: T;
    /// 1/2.
    const HALF: T;
    /// 1/√2.
    const FRAC_1_SQRT_2: T;

    // --- conversions ---------------------------------------------------------------------------

    /// The integer `v`, exactly.
    fn from_int(v: i32) -> T;
    /// `num / den` for two integers, rounded once (to nearest, ties to even for `fixed::Fixed`).
    /// Panics on a zero denominator or overflow.
    fn from_ratio(num: i64, den: i64) -> T;

    // --- helpers -------------------------------------------------------------------------------

    /// `|self|`.
    fn abs(self: T) -> T;
    /// `-1` if `self` is negative, `1` otherwise: `signum(0) = 1`, as for `+0.0` in Rust.
    fn signum(self: T) -> T;
    /// `self < 0`. Upstream: `RealField::is_sign_negative`.
    fn is_sign_negative(self: T) -> bool;
    /// `self > 0`. Upstream: `RealField::is_sign_positive`.
    fn is_sign_positive(self: T) -> bool;
    /// The smaller of two values.
    fn min(self: T, other: T) -> T;
    /// The larger of two values.
    fn max(self: T, other: T) -> T;
    /// `self` restricted to `[lo, hi]` (`lo <= hi` is not checked).
    fn clamp(self: T, lo: T, hi: T) -> T;
    /// Largest integer `<= self`.
    fn floor(self: T) -> T;
    /// `1 / self`, bit-identical to `Real::div(one(), self)` and cheaper (to nearest, ties to even
    /// for `fixed::Fixed`).
    fn recip(self: T) -> T;
    /// Square root (floor of the exact root for `fixed::Fixed`). Panics on a negative input.
    fn sqrt(self: T) -> T;
    /// `|self - other| <= ulps` smallest units (raw units for fixed point).
    fn abs_diff_eq(self: T, other: T, ulps: u64) -> bool;

    // --- division: the ONLY division entry points of generic code -------------------------------

    /// `a / b`, rounded once (to nearest, ties to even for `fixed::Fixed`, like `f64 /`). Panics on
    /// a zero divisor and when the quotient is out of range.
    ///
    /// Generic code (nalgebra) divides through `Real::div` / `Real::rem`, never through the
    /// corelib `/` / `%` operators, so that the trait pins the semantics. Upstream: `Div for f64`.
    fn div(a: T, b: T) -> T;
    /// `(x0 / d, x1 / d, x2 / d)` with ONE prepared divisor: BIT-IDENTICAL to three `div(xi, d)`
    /// (same rounding, same panics), cheaper from 3 quotients on (normalisations, adjugate
    /// scaling, pivot columns). The `divN` family exists for the static counts nalgebra uses: a
    /// divisor object held across generic code would need `Copy` / `Drop` bounds on an associated
    /// type, which Cairo cannot state without making `+Drop<R::Wide>` ambiguous. Upstream: `x / d`
    /// per element.
    fn div3(x0: T, x1: T, x2: T, d: T) -> (T, T, T);
    /// Four quotients by one prepared divisor, see `div3`.
    fn div4(x0: T, x1: T, x2: T, x3: T, d: T) -> (T, T, T, T);
    /// Five quotients by one prepared divisor, see `div3`.
    fn div5(x0: T, x1: T, x2: T, x3: T, x4: T, d: T) -> (T, T, T, T, T);
    /// Six quotients by one prepared divisor, see `div3`.
    fn div6(x0: T, x1: T, x2: T, x3: T, x4: T, x5: T, d: T) -> (T, T, T, T, T, T);
    /// Nine quotients by one prepared divisor (3x3 adjugate), see `div3`.
    fn div9(
        x0: T, x1: T, x2: T, x3: T, x4: T, x5: T, x6: T, x7: T, x8: T, d: T,
    ) -> (T, T, T, T, T, T, T, T, T);
    /// Sixteen quotients by one prepared divisor (4x4 adjugate), see `div3`.
    fn div16(
        x0: T,
        x1: T,
        x2: T,
        x3: T,
        x4: T,
        x5: T,
        x6: T,
        x7: T,
        x8: T,
        x9: T,
        x10: T,
        x11: T,
        x12: T,
        x13: T,
        x14: T,
        x15: T,
        d: T,
    ) -> (T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T);
    /// `a - b * trunc(a / b)`, exact: zero or the sign of the DIVIDEND, `|rem(a, b)| < |b|`, as
    /// Rust's float `%`. Panics on a zero divisor. Upstream: `Rem for f64`.
    fn rem(a: T, b: T) -> T;

    // --- fused kernels: one rounding, one overflow check ----------------------------------------

    /// `self^2`.
    fn sqr(self: T) -> T;
    /// `a0*b0 + a1*b1` (dot2, complex products).
    fn sum_prod2(a0: T, b0: T, a1: T, b1: T) -> T;
    /// `a0*b0 + a1*b1 + a2*b2` (dot3, matrix rows).
    fn sum_prod3(a0: T, b0: T, a1: T, b1: T, a2: T, b2: T) -> T;
    /// `a0*b0 + a1*b1 + a2*b2 + a3*b3` (dot4, quaternion products).
    fn sum_prod4(a0: T, b0: T, a1: T, b1: T, a2: T, b2: T, a3: T, b3: T) -> T;
    /// `a*b - c*d` (cross product components, 2x2 determinants).
    fn diff_prod(a: T, b: T, c: T, d: T) -> T;
    /// `a*b + c` (Horner steps, integration).
    fn mul_add(a: T, b: T, c: T) -> T;
    /// `a + (b - a) * t`, `t` not clamped.
    fn lerp(a: T, b: T, t: T) -> T;
    /// `x^2 + y^2`.
    fn norm_squared2(x: T, y: T) -> T;
    /// `x^2 + y^2 + z^2`.
    fn norm_squared3(x: T, y: T, z: T) -> T;
    /// `x^2 + y^2 + z^2 + w^2`.
    fn norm_squared4(x: T, y: T, z: T, w: T) -> T;
    /// `sqrt(x^2 + y^2)` without intermediate overflow.
    fn norm2(x: T, y: T) -> T;
    /// `sqrt(x^2 + y^2 + z^2)` without intermediate overflow.
    fn norm3(x: T, y: T, z: T) -> T;
    /// `sqrt(x^2 + y^2 + z^2 + w^2)` without intermediate overflow.
    fn norm4(x: T, y: T, z: T, w: T) -> T;

    // --- wide accumulation: sums of any number of products ---------------------------------------

    /// The empty exact accumulator. Accumulate with `wide_add_prod` / `wide_sub_prod` /
    /// `wide_add` / `wide_sub`, finish with `wide_rescale` (or `wide_sqrt`, `wide_mul_scalar`).
    fn wide_zero() -> Self::Wide;
    /// `w + a*b`, exact.
    fn wide_add_prod(w: Self::Wide, a: T, b: T) -> Self::Wide;
    /// `w - a*b`, exact.
    fn wide_sub_prod(w: Self::Wide, a: T, b: T) -> Self::Wide;
    /// `w + c`, exact.
    fn wide_add(w: Self::Wide, c: T) -> Self::Wide;
    /// `w - c`, exact.
    fn wide_sub(w: Self::Wide, c: T) -> Self::Wide;
    /// The accumulated value as a scalar: the single rounding / overflow check.
    fn wide_rescale(w: Self::Wide) -> T;
    /// Square root of the accumulated value (norm of a long vector). Panics on a negative sum.
    fn wide_sqrt(w: Self::Wide) -> T;
    /// The accumulated value times `s`, as a scalar: the single rounding / overflow check of an
    /// exact triple product `(a*b - c*d) * e`, where `diff_prod(a, b, c, d) * e` or
    /// `wide_rescale(w) * s` would round twice. Terminal: consumes the accumulator.
    fn wide_mul_scalar(w: Self::Wide, s: T) -> T;
}

/// Transcendental functions. Declared separately from `Real` so that a scalar can be a `Real`
/// without them. Angles are in radians.
///
/// For `fixed::Fixed` the numeric specification of every function (error in ulp, exact values,
/// symmetries, domain and panics) is `fixed::trig::TrigTrait` / `fixed::exp::ExpTrait`'s.
pub trait Transcendental<T> {
    /// Sine.
    fn sin(self: T) -> T;
    /// Cosine.
    fn cos(self: T) -> T;
    /// `(sin, cos)` with a shared range reduction.
    fn sin_cos(self: T) -> (T, T);
    /// Tangent.
    fn tan(self: T) -> T;
    /// Arcsine, in `[-π/2, π/2]`. Panics outside `[-1, 1]`.
    fn asin(self: T) -> T;
    /// Arccosine, in `[0, π]`. Panics outside `[-1, 1]`.
    fn acos(self: T) -> T;
    /// Arctangent, in `[-π/2, π/2]`.
    fn atan(self: T) -> T;
    /// Four-quadrant arctangent of `y / x`, in `[-π, π]`.
    fn atan2(y: T, x: T) -> T;
    /// Exponential.
    fn exp(self: T) -> T;
    /// Natural logarithm. Panics on a non-positive input.
    fn ln(self: T) -> T;
    /// Hyperbolic sine (simba-rs `ComplexField::sinh`).
    fn sinh(self: T) -> T;
    /// Hyperbolic cosine (simba-rs `ComplexField::cosh`).
    fn cosh(self: T) -> T;
    /// Hyperbolic tangent (simba-rs `ComplexField::tanh`).
    fn tanh(self: T) -> T;
    /// Cardinal hyperbolic sine `sinh(x) / x`, `1` at zero (simba-rs `ComplexField::sinhc`).
    fn sinhc(self: T) -> T;
    /// `cosh(x) / x`, `1` at zero like simba-rs `ComplexField::coshc`.
    fn coshc(self: T) -> T;
}

/// `Transcendental` for `fixed::Fixed`: `#[inline(always)]` forwards to `fixed::trig::TrigTrait`
/// and `fixed::exp::ExpTrait`, where the numeric specification lives.
pub impl FixedTranscendental of Transcendental<Fixed> {
    #[inline(always)]
    fn sin(self: Fixed) -> Fixed {
        TrigTrait::sin(self)
    }
    #[inline(always)]
    fn cos(self: Fixed) -> Fixed {
        TrigTrait::cos(self)
    }
    #[inline(always)]
    fn sin_cos(self: Fixed) -> (Fixed, Fixed) {
        TrigTrait::sin_cos(self)
    }
    #[inline(always)]
    fn tan(self: Fixed) -> Fixed {
        TrigTrait::tan(self)
    }
    #[inline(always)]
    fn asin(self: Fixed) -> Fixed {
        TrigTrait::asin(self)
    }
    #[inline(always)]
    fn acos(self: Fixed) -> Fixed {
        TrigTrait::acos(self)
    }
    #[inline(always)]
    fn atan(self: Fixed) -> Fixed {
        TrigTrait::atan(self)
    }
    #[inline(always)]
    fn atan2(y: Fixed, x: Fixed) -> Fixed {
        TrigTrait::atan2(y, x)
    }
    #[inline(always)]
    fn exp(self: Fixed) -> Fixed {
        ExpTrait::exp(self)
    }
    #[inline(always)]
    fn ln(self: Fixed) -> Fixed {
        ExpTrait::ln(self)
    }
    #[inline(always)]
    fn sinh(self: Fixed) -> Fixed {
        ExpTrait::sinh(self)
    }
    #[inline(always)]
    fn cosh(self: Fixed) -> Fixed {
        ExpTrait::cosh(self)
    }
    #[inline(always)]
    fn tanh(self: Fixed) -> Fixed {
        ExpTrait::tanh(self)
    }
    #[inline(always)]
    fn sinhc(self: Fixed) -> Fixed {
        ExpTrait::sinhc(self)
    }
    #[inline(always)]
    fn coshc(self: Fixed) -> Fixed {
        ExpTrait::coshc(self)
    }
}

/// `Real` for `fixed::Fixed`: every method is an `#[inline(always)]` call to `fixed`'s public
/// API, zero-cost (`bench_real_dot3__generic` equals `bench_real_dot3__direct`). The accumulator
/// is `fixed::wide::Acc`.
pub impl FixedReal of Real<Fixed> {
    type Wide = Acc;

    #[inline(always)]
    fn zero() -> Fixed {
        consts::ZERO
    }
    #[inline(always)]
    fn one() -> Fixed {
        consts::ONE
    }
    #[inline(always)]
    fn default_epsilon() -> Fixed {
        consts::EPSILON
    }
    #[inline(always)]
    fn min_value() -> Option<Fixed> {
        Some(consts::MIN)
    }
    #[inline(always)]
    fn max_value() -> Option<Fixed> {
        Some(consts::MAX)
    }
    #[inline(always)]
    fn pi() -> Fixed {
        consts::PI
    }
    #[inline(always)]
    fn two_pi() -> Fixed {
        consts::TAU
    }
    #[inline(always)]
    fn frac_pi_2() -> Fixed {
        consts::FRAC_PI_2
    }
    #[inline(always)]
    fn frac_pi_3() -> Fixed {
        consts::FRAC_PI_3
    }
    #[inline(always)]
    fn frac_pi_4() -> Fixed {
        consts::FRAC_PI_4
    }
    #[inline(always)]
    fn frac_pi_6() -> Fixed {
        consts::FRAC_PI_6
    }
    #[inline(always)]
    fn frac_1_pi() -> Fixed {
        consts::FRAC_1_PI
    }
    #[inline(always)]
    fn e() -> Fixed {
        consts::E
    }
    #[inline(always)]
    fn ln_2() -> Fixed {
        consts::LN_2
    }
    #[inline(always)]
    fn ln_10() -> Fixed {
        consts::LN_10
    }

    const NEG_ONE: Fixed = consts::NEG_ONE;
    const TWO: Fixed = consts::TWO;
    const HALF: Fixed = consts::HALF;
    const FRAC_1_SQRT_2: Fixed = consts::FRAC_1_SQRT_2;

    #[inline(always)]
    fn from_int(v: i32) -> Fixed {
        FixedTrait::from_int(v)
    }
    #[inline(always)]
    fn from_ratio(num: i64, den: i64) -> Fixed {
        FixedTrait::from_ratio(num, den)
    }

    #[inline(always)]
    fn abs(self: Fixed) -> Fixed {
        FixedTrait::abs(self)
    }
    #[inline(always)]
    fn signum(self: Fixed) -> Fixed {
        FixedTrait::signum(self)
    }
    #[inline(always)]
    fn is_sign_negative(self: Fixed) -> bool {
        FixedTrait::is_negative(self)
    }
    #[inline(always)]
    fn is_sign_positive(self: Fixed) -> bool {
        FixedTrait::is_positive(self)
    }
    #[inline(always)]
    fn min(self: Fixed, other: Fixed) -> Fixed {
        FixedTrait::min(self, other)
    }
    #[inline(always)]
    fn max(self: Fixed, other: Fixed) -> Fixed {
        FixedTrait::max(self, other)
    }
    #[inline(always)]
    fn clamp(self: Fixed, lo: Fixed, hi: Fixed) -> Fixed {
        FixedTrait::clamp(self, lo, hi)
    }
    #[inline(always)]
    fn floor(self: Fixed) -> Fixed {
        FixedTrait::floor(self)
    }
    #[inline(always)]
    fn recip(self: Fixed) -> Fixed {
        FixedTrait::recip(self)
    }
    #[inline(always)]
    fn sqrt(self: Fixed) -> Fixed {
        FixedTrait::sqrt(self)
    }
    /// `fixed::FixedTrait::abs_diff_eq` with a tolerance of `ulps` raw units. A tolerance beyond
    /// `MAX` raw (`2^63 - 1`) is clamped to it: the only pairs this misjudges are more than
    /// `2^63 - 1` raw apart, i.e. `MIN`-side against `MAX`-side values.
    #[inline(always)]
    fn abs_diff_eq(self: Fixed, other: Fixed, ulps: u64) -> bool {
        let tol = match ulps.try_into() {
            Some(raw) => Fixed { raw },
            None => consts::MAX,
        };
        FixedTrait::abs_diff_eq(self, other, tol)
    }

    /// `fixed::Fixed`'s `/` (`FixedDiv`, `FixedTrait::div_nearest`): to nearest, ties to even.
    #[inline(always)]
    fn div(a: Fixed, b: Fixed) -> Fixed {
        a / b
    }
    /// `fixed::wide::RecipNearestTrait`: `new(d)` once, then `div_nearest` per quotient (the
    /// bits of `x / d`).
    #[inline(always)]
    fn div3(x0: Fixed, x1: Fixed, x2: Fixed, d: Fixed) -> (Fixed, Fixed, Fixed) {
        let r = RecipNearestTrait::new(d);
        (r.div_nearest(x0), r.div_nearest(x1), r.div_nearest(x2))
    }
    #[inline(always)]
    fn div4(x0: Fixed, x1: Fixed, x2: Fixed, x3: Fixed, d: Fixed) -> (Fixed, Fixed, Fixed, Fixed) {
        let r = RecipNearestTrait::new(d);
        (r.div_nearest(x0), r.div_nearest(x1), r.div_nearest(x2), r.div_nearest(x3))
    }
    #[inline(always)]
    fn div5(
        x0: Fixed, x1: Fixed, x2: Fixed, x3: Fixed, x4: Fixed, d: Fixed,
    ) -> (Fixed, Fixed, Fixed, Fixed, Fixed) {
        let r = RecipNearestTrait::new(d);
        (
            r.div_nearest(x0),
            r.div_nearest(x1),
            r.div_nearest(x2),
            r.div_nearest(x3),
            r.div_nearest(x4),
        )
    }
    #[inline(always)]
    fn div6(
        x0: Fixed, x1: Fixed, x2: Fixed, x3: Fixed, x4: Fixed, x5: Fixed, d: Fixed,
    ) -> (Fixed, Fixed, Fixed, Fixed, Fixed, Fixed) {
        let r = RecipNearestTrait::new(d);
        (
            r.div_nearest(x0),
            r.div_nearest(x1),
            r.div_nearest(x2),
            r.div_nearest(x3),
            r.div_nearest(x4),
            r.div_nearest(x5),
        )
    }
    #[inline(always)]
    fn div9(
        x0: Fixed,
        x1: Fixed,
        x2: Fixed,
        x3: Fixed,
        x4: Fixed,
        x5: Fixed,
        x6: Fixed,
        x7: Fixed,
        x8: Fixed,
        d: Fixed,
    ) -> (Fixed, Fixed, Fixed, Fixed, Fixed, Fixed, Fixed, Fixed, Fixed) {
        let r = RecipNearestTrait::new(d);
        (
            r.div_nearest(x0),
            r.div_nearest(x1),
            r.div_nearest(x2),
            r.div_nearest(x3),
            r.div_nearest(x4),
            r.div_nearest(x5),
            r.div_nearest(x6),
            r.div_nearest(x7),
            r.div_nearest(x8),
        )
    }
    #[inline(always)]
    fn div16(
        x0: Fixed,
        x1: Fixed,
        x2: Fixed,
        x3: Fixed,
        x4: Fixed,
        x5: Fixed,
        x6: Fixed,
        x7: Fixed,
        x8: Fixed,
        x9: Fixed,
        x10: Fixed,
        x11: Fixed,
        x12: Fixed,
        x13: Fixed,
        x14: Fixed,
        x15: Fixed,
        d: Fixed,
    ) -> (
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
        Fixed,
    ) {
        let r = RecipNearestTrait::new(d);
        (
            r.div_nearest(x0),
            r.div_nearest(x1),
            r.div_nearest(x2),
            r.div_nearest(x3),
            r.div_nearest(x4),
            r.div_nearest(x5),
            r.div_nearest(x6),
            r.div_nearest(x7),
            r.div_nearest(x8),
            r.div_nearest(x9),
            r.div_nearest(x10),
            r.div_nearest(x11),
            r.div_nearest(x12),
            r.div_nearest(x13),
            r.div_nearest(x14),
            r.div_nearest(x15),
        )
    }
    /// `fixed::Fixed`'s `%` (`FixedRem`): truncated remainder, sign of the dividend.
    #[inline(always)]
    fn rem(a: Fixed, b: Fixed) -> Fixed {
        a % b
    }

    /// `self * self` (`FixedMul`, floor).
    #[inline(always)]
    fn sqr(self: Fixed) -> Fixed {
        self * self
    }
    #[inline(always)]
    fn sum_prod2(a0: Fixed, b0: Fixed, a1: Fixed, b1: Fixed) -> Fixed {
        wide::dot2(a0, b0, a1, b1)
    }
    #[inline(always)]
    fn sum_prod3(a0: Fixed, b0: Fixed, a1: Fixed, b1: Fixed, a2: Fixed, b2: Fixed) -> Fixed {
        wide::dot3(a0, b0, a1, b1, a2, b2)
    }
    #[inline(always)]
    fn sum_prod4(
        a0: Fixed, b0: Fixed, a1: Fixed, b1: Fixed, a2: Fixed, b2: Fixed, a3: Fixed, b3: Fixed,
    ) -> Fixed {
        wide::dot4(a0, b0, a1, b1, a2, b2, a3, b3)
    }
    #[inline(always)]
    fn diff_prod(a: Fixed, b: Fixed, c: Fixed, d: Fixed) -> Fixed {
        wide::mul_sub(a, b, c, d)
    }
    #[inline(always)]
    fn mul_add(a: Fixed, b: Fixed, c: Fixed) -> Fixed {
        wide::mul_add(a, b, c)
    }
    #[inline(always)]
    fn lerp(a: Fixed, b: Fixed, t: Fixed) -> Fixed {
        FixedTrait::lerp(a, b, t)
    }
    #[inline(always)]
    fn norm_squared2(x: Fixed, y: Fixed) -> Fixed {
        wide::norm2_squared(x, y)
    }
    #[inline(always)]
    fn norm_squared3(x: Fixed, y: Fixed, z: Fixed) -> Fixed {
        wide::norm3_squared(x, y, z)
    }
    #[inline(always)]
    fn norm_squared4(x: Fixed, y: Fixed, z: Fixed, w: Fixed) -> Fixed {
        wide::norm4_squared(x, y, z, w)
    }
    #[inline(always)]
    fn norm2(x: Fixed, y: Fixed) -> Fixed {
        wide::norm2(x, y)
    }
    #[inline(always)]
    fn norm3(x: Fixed, y: Fixed, z: Fixed) -> Fixed {
        wide::norm3(x, y, z)
    }
    #[inline(always)]
    fn norm4(x: Fixed, y: Fixed, z: Fixed, w: Fixed) -> Fixed {
        wide::norm4(x, y, z, w)
    }

    #[inline(always)]
    fn wide_zero() -> Acc {
        AccTrait::zero()
    }
    #[inline(always)]
    fn wide_add_prod(w: Acc, a: Fixed, b: Fixed) -> Acc {
        w.add_prod(a, b)
    }
    #[inline(always)]
    fn wide_sub_prod(w: Acc, a: Fixed, b: Fixed) -> Acc {
        w.sub_prod(a, b)
    }
    #[inline(always)]
    fn wide_add(w: Acc, c: Fixed) -> Acc {
        AccTrait::add(w, c)
    }
    #[inline(always)]
    fn wide_sub(w: Acc, c: Fixed) -> Acc {
        AccTrait::sub(w, c)
    }
    #[inline(always)]
    fn wide_rescale(w: Acc) -> Fixed {
        w.narrow()
    }
    #[inline(always)]
    fn wide_sqrt(w: Acc) -> Fixed {
        AccTrait::sqrt(w)
    }
    #[inline(always)]
    fn wide_mul_scalar(w: Acc, s: Fixed) -> Fixed {
        w.mul_narrow(s)
    }
}

#[cfg(test)]
mod tests;
