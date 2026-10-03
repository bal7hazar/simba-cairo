//! `Real` / `Transcendental` for `fixed::Fixed`: each method is the `fixed` call it wraps
//! (forwarding tests on negative, inexact and edge values), the semantics that changed with the
//! move to `fixed` (division rounded to nearest, ties to even, `signum(0)`, rounded constants),
//! `fixed`'s panic messages, and generic code written against `Real` only.

use fixed::exp::ExpTrait;
use fixed::trig::TrigTrait;
use fixed::wide::{self, AccTrait};
use fixed::{Fixed, FixedTrait};
use crate::testing::black_box;
use super::{Real, Transcendental};

fn fx(raw: i64) -> Fixed {
    Fixed { raw }
}

// Operands: negative and inexact, positive inexact, just above an integer, tiny negative.
const A: i64 = -0x1_2345_6789; // ~ -1.1378
const B: i64 = 0x0_9abc_def1; // ~ 0.6044
const C: i64 = 0x3_0000_0001; // 3 + 1 ulp
const D: i64 = -7; // -7 ulp

// --- constants and conversions --------------------------------------------------------------

#[test]
fn test_real_constants_are_fixeds() {
    assert!(Real::<Fixed>::zero() == fixed::ZERO && Real::<Fixed>::one() == fixed::ONE);
    assert!(Real::<Fixed>::NEG_ONE == fixed::NEG_ONE && Real::<Fixed>::TWO == fixed::TWO);
    assert!(Real::<Fixed>::HALF == fixed::HALF && Real::<Fixed>::default_epsilon() == fx(1));
    assert!(
        Real::<Fixed>::min_value().unwrap() == fixed::MIN
            && Real::<Fixed>::max_value().unwrap() == fixed::MAX,
    );
    assert!(
        Real::<Fixed>::two_pi() == fixed::TAU && Real::<Fixed>::frac_pi_2() == fixed::FRAC_PI_2,
    );
    assert!(Real::<Fixed>::frac_pi_4() == fixed::FRAC_PI_4);
    assert!(Real::<Fixed>::frac_pi_6() == fixed::FRAC_PI_6);
    assert!(Real::<Fixed>::frac_1_pi() == fixed::FRAC_1_PI);
    // Rounded to nearest: one ulp above the floored constants of the former `simba::fixed`.
    assert!(Real::<Fixed>::pi() == fx(13493037705));
    assert!(Real::<Fixed>::frac_pi_3() == fx(4497679235));
    assert!(Real::<Fixed>::e() == fx(11674931555));
    assert!(Real::<Fixed>::ln_2() == fx(2977044472));
    assert!(Real::<Fixed>::ln_10() == fx(9889527671));
    assert!(Real::<Fixed>::FRAC_1_SQRT_2 == fx(3037000500));
}

#[test]
fn test_real_from_int_and_ratio() {
    assert!(Real::<Fixed>::from_int(-3) == FixedTrait::from_int(-3));
    assert!(Real::<Fixed>::from_int(-3) == fx(-0x3_0000_0000));
    // To nearest: -1/3 = -1431655765.33 raw, 2/3 = 2863311530.67 raw.
    assert!(Real::<Fixed>::from_ratio(-1, 3) == fx(-1431655765));
    assert!(Real::<Fixed>::from_ratio(2, 3) == fx(2863311531));
    // Ties to even: 1 / 2^33 = 0.5 raw -> 0, 3 / 2^33 = 1.5 raw -> 2, -5 / 2^33 = -2.5 raw -> -2.
    assert!(Real::<Fixed>::from_ratio(1, 0x200000000) == fx(0));
    assert!(Real::<Fixed>::from_ratio(3, 0x200000000) == fx(2));
    assert!(Real::<Fixed>::from_ratio(-5, 0x200000000) == fx(-2));
    assert!(Real::<Fixed>::from_ratio(7, 2) == FixedTrait::from_ratio(7, 2));
}

// --- helpers --------------------------------------------------------------------------------

#[test]
fn test_real_helpers_forward_to_fixed() {
    let (a, b, c, d) = (fx(A), fx(B), fx(C), fx(D));
    assert!(Real::abs(a) == FixedTrait::abs(a) && Real::abs(a) == fx(-A));
    assert!(
        Real::is_sign_negative(a)
            && !Real::is_sign_negative(b)
            && !Real::is_sign_negative(Real::<Fixed>::zero()),
    );
    assert!(Real::is_sign_positive(b) && !Real::is_sign_positive(a));
    assert!(Real::min(a, b) == a && Real::max(a, b) == b);
    assert!(Real::clamp(c, a, b) == b && Real::clamp(d, a, b) == d);
    assert!(Real::floor(a) == FixedTrait::floor(a) && Real::floor(a) == fx(-0x2_0000_0000));
    assert!(Real::floor(d) == Real::NEG_ONE);
    assert!(Real::sqrt(c) == FixedTrait::sqrt(c));
    assert!(Real::sqrt(fx(0x4_0000_0000)) == Real::TWO);
}

#[test]
fn test_real_signum_of_zero_is_one() {
    assert!(Real::signum(Real::<Fixed>::zero()) == Real::one());
    assert!(Real::signum(fx(D)) == Real::NEG_ONE && Real::signum(fx(B)) == Real::one());
    assert!(Real::signum(fx(A)) == FixedTrait::signum(fx(A)));
}

#[test]
fn test_real_recip_rounds_to_nearest() {
    // 2^32 / 3 = 1431655765.33 and 2^32 / 1.5 = 2863311530.67: to nearest on both signs.
    assert!(Real::recip(fx(0x3_0000_0000)) == fx(1431655765));
    assert!(Real::recip(fx(-0x3_0000_0000)) == fx(-1431655765));
    assert!(Real::recip(fx(0x1_8000_0000)) == fx(2863311531));
    assert!(Real::recip(fx(-0x1_8000_0000)) == fx(-2863311531));
    assert!(Real::recip(fx(0x1_8000_0000)) == Real::div(Real::one(), fx(0x1_8000_0000)));
    assert!(Real::recip(fx(A)) == FixedTrait::recip(fx(A)));
}

#[test]
fn test_real_abs_diff_eq_counts_ulps() {
    let (a, d) = (fx(A), fx(D));
    assert!(Real::abs_diff_eq(a, a + fx(3), 3) && !Real::abs_diff_eq(a, a + fx(4), 3));
    assert!(Real::abs_diff_eq(d, fx(0), 7) && !Real::abs_diff_eq(d, fx(1), 7));
    // Tolerances beyond `MAX` raw are clamped to it.
    assert!(
        Real::abs_diff_eq(
            Real::<Fixed>::min_value().unwrap(), Real::zero(), 0xffffffffffffffff,
        ) == false,
    );
    assert!(
        Real::abs_diff_eq(Real::<Fixed>::max_value().unwrap(), Real::zero(), 0xffffffffffffffff),
    );
}

// --- division -------------------------------------------------------------------------------

#[test]
fn test_real_div_rounds_to_nearest_ties_to_even() {
    let (a, b) = (fx(A), fx(B));
    assert!(Real::div(a, b) == a / b);
    assert!(Real::div(a, b) == FixedTrait::div_nearest(a, b));
    // Ties to even, like `f64 /`: -0.5 ulp -> 0, -1.5 ulp -> -2, 2.5 ulp -> 2, -2.5 ulp -> -2.
    assert!(Real::div(fx(-1), Real::TWO) == Real::zero());
    assert!(Real::div(fx(-3), Real::TWO) == fx(-2));
    assert!(Real::div(fx(5), Real::TWO) == fx(2));
    assert!(Real::div(fx(-5), Real::TWO) == fx(-2));
    // Not a tie: -2 / 3 = -0.67 ulp -> -1 (truncation gave 0, floor -1).
    assert!(Real::div(fx(-2), Real::from_int(3)) == fx(-1));
    assert!(Real::div(Real::<Fixed>::from_int(-7), Real::from_int(2)) == Real::from_ratio(-7, 2));
}

#[test]
fn test_real_rem_has_the_sign_of_the_dividend() {
    let (a, b) = (fx(A), fx(B));
    assert!(Real::rem(a, b) == a % b);
    assert!(Real::rem(Real::<Fixed>::from_int(-7), Real::from_int(2)) == Real::NEG_ONE);
    assert!(Real::rem(Real::<Fixed>::from_int(7), Real::from_int(-2)) == Real::one());
    assert!(Real::rem(fx(D), fx(3)) == fx(-1));
}

// --- fused kernels --------------------------------------------------------------------------

#[test]
fn test_real_fused_kernels_forward_to_fixed_wide() {
    let (a, b, c, d) = (fx(A), fx(B), fx(C), fx(D));
    assert!(Real::sqr(a) == a * a);
    assert!(Real::sum_prod2(a, b, c, d) == wide::dot2(a, b, c, d));
    assert!(Real::sum_prod3(a, b, c, d, b, a) == wide::dot3(a, b, c, d, b, a));
    assert!(Real::sum_prod4(a, b, c, d, b, a, d, c) == wide::dot4(a, b, c, d, b, a, d, c));
    assert!(Real::diff_prod(a, b, c, d) == wide::mul_sub(a, b, c, d));
    assert!(Real::mul_add(a, b, d) == wide::mul_add(a, b, d));
    assert!(Real::lerp(a, c, b) == FixedTrait::lerp(a, c, b));
    assert!(Real::norm_squared2(a, b) == wide::norm2_squared(a, b));
    assert!(Real::norm_squared3(a, b, c) == wide::norm3_squared(a, b, c));
    assert!(Real::norm_squared4(a, b, c, d) == wide::norm4_squared(a, b, c, d));
    assert!(Real::norm2(a, b) == wide::norm2(a, b));
    assert!(Real::norm3(a, b, c) == wide::norm3(a, b, c));
    assert!(Real::norm4(a, b, c, d) == wide::norm4(a, b, c, d));
}

#[test]
fn test_real_fused_kernels_round_once_by_floor() {
    // (-1 ulp) * (1/2) = -0.5 ulp floors to -1 ulp; a*b - a*b is exactly 0.
    assert!(Real::sum_prod2(fx(-1), Real::HALF, Real::zero(), Real::zero()) == fx(-1));
    assert!(Real::diff_prod(fx(A), fx(B), fx(A), fx(B)) == Real::zero());
    assert!(
        Real::norm3(
            Real::<Fixed>::from_int(2), Real::from_int(-3), Real::from_int(6),
        ) == Real::from_int(7),
    );
    assert!(Real::lerp(fx(A), fx(C), Real::one()) == fx(C));
}

#[test]
fn test_real_wide_accumulator_forwards_to_acc() {
    let (a, b, c, d) = (fx(A), fx(B), fx(C), fx(D));
    let w = Real::wide_add_prod(Real::<Fixed>::wide_zero(), a, b);
    let w = Real::<Fixed>::wide_sub_prod(w, c, d);
    let w = Real::<Fixed>::wide_add(w, c);
    let w = Real::<Fixed>::wide_sub(w, b);
    let acc = AccTrait::zero().add_prod(a, b).sub_prod(c, d);
    let acc = AccTrait::add(acc, c);
    let acc = AccTrait::sub(acc, b);
    assert!(Real::<Fixed>::wide_rescale(w) == acc.narrow());
    assert!(Real::<Fixed>::wide_mul_scalar(w, d) == acc.mul_narrow(d));
    let s = Real::wide_add_prod(Real::wide_add_prod(Real::<Fixed>::wide_zero(), a, a), c, c);
    assert!(Real::<Fixed>::wide_sqrt(s) == Real::norm2(a, c));
    assert!(Real::<Fixed>::wide_rescale(w) == wide::dot2(a, b, -c, d) + c - b);
}

// --- transcendental -------------------------------------------------------------------------

#[test]
fn test_transcendental_forwards_to_fixed() {
    let (a, b) = (fx(A), fx(B));
    assert!(
        Transcendental::sin(a) == TrigTrait::sin(a) && Transcendental::cos(a) == TrigTrait::cos(a),
    );
    assert!(
        Transcendental::sin_cos(a) == TrigTrait::sin_cos(a)
            && Transcendental::tan(b) == TrigTrait::tan(b),
    );
    assert!(
        Transcendental::asin(b) == TrigTrait::asin(b)
            && Transcendental::acos(b) == TrigTrait::acos(b),
    );
    assert!(Transcendental::atan(a) == TrigTrait::atan(a));
    assert!(Transcendental::atan2(a, b) == TrigTrait::atan2(a, b));
    assert!(Transcendental::exp(a) == ExpTrait::exp(a) && Transcendental::ln(b) == ExpTrait::ln(b));
    assert!(
        Transcendental::sinh(a) == ExpTrait::sinh(a)
            && Transcendental::cosh(a) == ExpTrait::cosh(a)
            && Transcendental::tanh(a) == ExpTrait::tanh(a),
    );
    assert!(
        Transcendental::sinhc(a) == ExpTrait::sinhc(a)
            && Transcendental::coshc(b) == ExpTrait::coshc(b),
    );
    assert!(
        Transcendental::sinhc(Real::<Fixed>::zero()) == Real::one()
            && Transcendental::coshc(Real::<Fixed>::zero()) == Real::one()
            && Transcendental::cosh(Real::<Fixed>::zero()) == Real::one(),
    );
    let quarter_turn = Real::<Fixed>::frac_pi_2();
    assert!(
        Transcendental::sin(quarter_turn) == Real::one()
            && Transcendental::exp(Real::<Fixed>::zero()) == Real::one(),
    );
    assert!(Transcendental::atan2(Real::<Fixed>::one(), Real::zero()) == quarter_turn);
}

// --- panics: `fixed`'s messages -------------------------------------------------------------

#[test]
#[should_panic(expected: 'Fixed: overflow')]
fn test_real_sum_prod3_overflow_panics() {
    let huge = black_box(fx(0x40_0000_0000_0000));
    let _ = Real::sum_prod3(huge, huge, Real::zero(), Real::zero(), Real::zero(), Real::zero());
}

#[test]
#[should_panic(expected: 'Fixed: overflow')]
fn test_real_wide_rescale_overflow_panics() {
    let huge = black_box(fx(0x40_0000_0000_0000));
    let _ = Real::<
        Fixed,
    >::wide_rescale(Real::wide_add_prod(Real::<Fixed>::wide_zero(), huge, huge));
}

#[test]
#[should_panic(expected: 'Fixed: overflow')]
fn test_real_div_overflow_panics() {
    let _ = Real::div(black_box(Real::<Fixed>::max_value().unwrap()), Real::HALF);
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_real_div_by_zero_panics() {
    let _ = Real::div(black_box(Real::<Fixed>::one()), Real::zero());
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_real_rem_by_zero_panics() {
    let _ = Real::rem(black_box(Real::<Fixed>::one()), Real::zero());
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_real_recip_of_zero_panics() {
    let _ = Real::recip(black_box(Real::<Fixed>::zero()));
}

#[test]
#[should_panic(expected: 'Fixed: sqrt negative')]
fn test_real_sqrt_negative_panics() {
    let _ = Real::sqrt(black_box(fx(D)));
}

#[test]
#[should_panic(expected: 'Fixed: sqrt negative')]
fn test_real_wide_sqrt_negative_panics() {
    let _ = Real::<
        Fixed,
    >::wide_sqrt(Real::wide_sub_prod(Real::<Fixed>::wide_zero(), black_box(fx(A)), fx(A)));
}

#[test]
#[should_panic(expected: 'Fixed: acos domain')]
fn test_transcendental_acos_domain_panics() {
    let _ = Transcendental::acos(black_box(Real::<Fixed>::TWO));
}

// --- generic code written against `Real` only (what `nalgebra` does) -------------------------

#[derive(Copy, Drop)]
struct V3<T> {
    x: T,
    y: T,
    z: T,
}

#[generate_trait]
impl V3Impl<T, impl R: Real<T>, +Copy<T>, +Drop<T>, +Drop<R::Wide>> of V3Trait<T> {
    #[inline(always)]
    fn dot(self: V3<T>, o: V3<T>) -> T {
        R::sum_prod3(self.x, o.x, self.y, o.y, self.z, o.z)
    }
    #[inline(always)]
    fn cross(self: V3<T>, o: V3<T>) -> V3<T> {
        V3 {
            x: R::diff_prod(self.y, o.z, self.z, o.y),
            y: R::diff_prod(self.z, o.x, self.x, o.z),
            z: R::diff_prod(self.x, o.y, self.y, o.x),
        }
    }
    #[inline(always)]
    fn norm(self: V3<T>) -> T {
        R::norm3(self.x, self.y, self.z)
    }
    /// Same dot product through the explicit accumulator.
    #[inline(always)]
    fn dot_wide(self: V3<T>, o: V3<T>) -> T {
        let w = R::wide_add_prod(R::wide_zero(), self.x, o.x);
        let w = R::wide_add_prod(w, self.y, o.y);
        R::wide_rescale(R::wide_add_prod(w, self.z, o.z))
    }
    #[inline(always)]
    fn unscale(self: V3<T>, k: T) -> V3<T> {
        V3 { x: R::div(self.x, k), y: R::div(self.y, k), z: R::div(self.z, k) }
    }
    /// Same quotients through one prepared divisor.
    #[inline(always)]
    fn unscale_prepared(self: V3<T>, k: T) -> V3<T> {
        let (x, y, z) = R::div3(self.x, self.y, self.z, k);
        V3 { x, y, z }
    }
}

#[test]
fn test_real_generic_code_on_fixed() {
    let a = V3 { x: fx(0x100000000), y: fx(-0x200000000), z: fx(0x200000000) };
    let b = V3 { x: fx(0x400000000), y: fx(0), z: fx(-0x300000000) };
    assert!(a.dot(b) == fx(-0x200000000));
    assert!(a.dot_wide(b) == fx(-0x200000000));
    assert!(a.norm() == fx(0x300000000));
    let c = a.cross(b);
    assert!(c.x == fx(0x600000000) && c.y == fx(0xb00000000) && c.z == fx(0x800000000));
    // To nearest: 1 / 3 = 1431655765.33 raw -> 1431655765, -2 / 3 = -2863311530.67 raw ->
    // -2863311531.
    let u = a.unscale(Real::from_int(3));
    let p = a.unscale_prepared(Real::from_int(3));
    assert!(p.x == u.x && p.y == u.y && p.z == u.z);
    assert!(u.x == fx(1431655765) && u.y == fx(-2863311531) && u.z == fx(2863311531));
}

// --- prepared divisor: `div3` .. `div16` -------------------------------------------------------

#[test]
fn test_real_div_n_is_bit_identical_to_div() {
    let (a, b, c, d) = (fx(A), fx(B), fx(C), fx(D));
    let ds = array![
        fx(B), fx(C), Real::<Fixed>::TWO, fx(-0x3_0000_0000), fx(A),
        Real::<Fixed>::min_value().unwrap(),
    ];
    let mut ds = ds.span();
    while let Some(k) = ds.pop_front() {
        let k = *k;
        let (q0, q1, q2) = Real::div3(a, b, c, k);
        assert!(q0 == Real::div(a, k) && q1 == Real::div(b, k) && q2 == Real::div(c, k));
        let (q0, q1, q2, q3) = Real::div4(d, fx(-1), fx(5), fx(-3), k);
        assert!(q0 == Real::div(d, k) && q1 == Real::div(fx(-1), k));
        assert!(q2 == Real::div(fx(5), k) && q3 == Real::div(fx(-3), k));
    }
    // Ties to even through the prepared divisor too: -0.5, 2.5, -1.5, -2.5 ulp.
    let (q0, q1, q2, q3, q4) = Real::div5(fx(-1), fx(5), fx(-3), fx(-5), fx(A), Real::<Fixed>::TWO);
    assert!(q0 == Real::zero() && q1 == fx(2) && q2 == fx(-2) && q3 == fx(-2));
    assert!(q4 == Real::div(fx(A), Real::TWO));
    let (_, _, _, _, _, q5) = Real::div6(
        a, b, c, d, a, Real::<Fixed>::max_value().unwrap(), Real::TWO,
    );
    assert!(q5 == Real::div(Real::<Fixed>::max_value().unwrap(), Real::TWO));
    let (q0, _, _, _, _, _, _, _, q8) = Real::div9(
        a, b, c, d, a, b, c, d, Real::<Fixed>::min_value().unwrap(), fx(C),
    );
    assert!(
        q0 == Real::div(a, fx(C)) && q8 == Real::div(Real::<Fixed>::min_value().unwrap(), fx(C)),
    );
    let (q0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, q15) = Real::div16(
        a, b, c, d, a, b, c, d, a, b, c, d, a, b, c, fx(-3), Real::<Fixed>::TWO,
    );
    assert!(q0 == Real::div(a, Real::TWO) && q15 == fx(-2));
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_real_div3_by_zero_panics() {
    let _ = Real::div3(fx(A), fx(B), fx(C), black_box(Real::<Fixed>::zero()));
}

#[test]
#[should_panic(expected: 'Fixed: overflow')]
fn test_real_div3_overflow_panics() {
    let _ = Real::div3(
        fx(A), Real::<Fixed>::max_value().unwrap(), fx(C), black_box(Real::<Fixed>::HALF),
    );
}

// --- simba 0.3.0: `is_sign_positive` at zero, the methods forwarded from `fixed` ---------------

#[test]
fn test_real_is_sign_positive_at_zero() {
    // Behaviour change of 0.3.0: zero is positive (`+0.0`), it was `self > 0`.
    let zero = Real::<Fixed>::zero();
    assert!(Real::is_sign_positive(zero) && !Real::is_sign_negative(zero));
    assert!(Real::is_sign_positive(zero) == FixedTrait::is_sign_positive(zero));
    assert!(!FixedTrait::is_positive(zero));
    assert!(Real::is_sign_positive(fx(1)) && !Real::is_sign_positive(fx(-1)));
    assert!(Real::is_sign_positive(fixed::MAX) && !Real::is_sign_positive(fixed::MIN));
    // Exactly one of the two holds for every value.
    assert!(Real::is_sign_positive(fx(D)) != Real::is_sign_negative(fx(D)));
}

#[test]
fn test_real_rounding_forwards_to_fixed() {
    let (a, b, d) = (fx(A), fx(B), fx(D));
    assert!(Real::ceil(a) == FixedTrait::ceil(a) && Real::ceil(a) == Real::NEG_ONE);
    assert!(Real::ceil(b) == Real::one() && Real::ceil(d) == Real::zero());
    assert!(Real::round(a) == FixedTrait::round(a) && Real::round(a) == Real::NEG_ONE);
    assert!(Real::round(b) == Real::one());
    // Ties away from zero.
    assert!(Real::round(fx(0x1_8000_0000)) == Real::<Fixed>::TWO);
    assert!(Real::round(fx(-0x1_8000_0000)) == -Real::<Fixed>::TWO);
    assert!(Real::trunc(a) == FixedTrait::trunc(a) && Real::trunc(a) == Real::NEG_ONE);
    assert!(Real::trunc(b) == Real::zero() && Real::trunc(d) == Real::zero());
    // `fract` keeps the sign of `self`: `self - trunc(self)`.
    assert!(Real::fract(a) == FixedTrait::fract(a) && Real::fract(a) == fx(A + 0x1_0000_0000));
    assert!(Real::fract(b) == b && Real::fract(d) == d);
}

#[test]
fn test_real_copysign_powi_hypot_forward_to_fixed() {
    let (a, b, c) = (fx(A), fx(B), fx(C));
    assert!(Real::copysign(b, a) == FixedTrait::copysign(b, a) && Real::copysign(b, a) == -b);
    assert!(Real::copysign(a, b) == -a && Real::copysign(a, Real::zero()) == -a);
    assert!(
        Real::powi(a, 3) == FixedTrait::powi(a, 3) && Real::powi(c, -2) == FixedTrait::powi(c, -2),
    );
    assert!(Real::powi(Real::<Fixed>::TWO, 3) == Real::from_int(8));
    assert!(Real::powi(Real::<Fixed>::TWO, -2) == fx(0x4000_0000));
    assert!(Real::powi(a, 0) == Real::one() && Real::powi(a, 1) == a);
    assert!(Real::hypot(a, b) == wide::norm2(a, b) && Real::hypot(a, b) == Real::norm2(a, b));
    assert!(Real::hypot(Real::<Fixed>::from_int(3), Real::from_int(-4)) == Real::from_int(5));
}

#[test]
fn test_real_forwarded_constants_are_fixeds() {
    assert!(Real::<Fixed>::frac_pi_8() == fixed::FRAC_PI_8);
    assert!(Real::<Fixed>::frac_2_pi() == fixed::FRAC_2_PI);
    // Half of π/4 and twice 1/π, to within an ulp (each constant is rounded to nearest).
    let d8 = Real::<Fixed>::frac_pi_4().raw - 2 * Real::<Fixed>::frac_pi_8().raw;
    assert!(d8 >= -1 && d8 <= 1);
    let d2 = Real::<Fixed>::frac_2_pi().raw - 2 * Real::<Fixed>::frac_1_pi().raw;
    assert!(d2 >= -1 && d2 <= 1);
}

#[test]
#[should_panic(expected: 'Fixed: overflow')]
fn test_real_ceil_overflow_panics() {
    let _ = Real::ceil(black_box(fixed::MAX));
}

#[test]
#[should_panic(expected: 'Fixed: overflow')]
fn test_real_copysign_min_panics() {
    let _ = Real::copysign(black_box(fixed::MIN), Real::one());
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_real_powi_zero_to_negative_panics() {
    let _ = Real::powi(black_box(Real::<Fixed>::zero()), -1);
}

// --- simba 0.3.0: `sinh_cosh`, `asinh` / `acosh` / `atanh`, the exp / log family ----------------

#[test]
fn test_transcendental_sinh_cosh_is_the_pair() {
    let (a, b, c) = (fx(A), fx(B), fx(C));
    assert!(Transcendental::sinh_cosh(a) == ExpTrait::sinh_cosh(a));
    // Bit-identical to the two calls it replaces, below and above 2 (where `sinh` needs `exp`).
    assert!(Transcendental::sinh_cosh(a) == (Transcendental::sinh(a), Transcendental::cosh(a)));
    assert!(Transcendental::sinh_cosh(b) == (Transcendental::sinh(b), Transcendental::cosh(b)));
    assert!(Transcendental::sinh_cosh(c) == (Transcendental::sinh(c), Transcendental::cosh(c)));
    let big = Real::<Fixed>::from_int(10);
    assert!(
        Transcendental::sinh_cosh(big) == (Transcendental::sinh(big), Transcendental::cosh(big)),
    );
    assert!(Transcendental::sinh_cosh(Real::<Fixed>::zero()) == (Real::zero(), Real::one()));
}

#[test]
fn test_transcendental_inverse_hyperbolics_forward_to_fixed() {
    let (a, b, c) = (fx(A), fx(B), fx(C));
    assert!(Transcendental::asinh(a) == ExpTrait::asinh(a));
    assert!(Transcendental::asinh(c) == ExpTrait::asinh(c));
    assert!(Transcendental::acosh(c) == ExpTrait::acosh(c));
    assert!(Transcendental::atanh(b) == ExpTrait::atanh(b));
    assert!(Transcendental::atanh(fx(-B)) == ExpTrait::atanh(fx(-B)));
    // Exact values, and `asinh` / `atanh` exactly odd.
    let zero = Real::<Fixed>::zero();
    assert!(Transcendental::asinh(zero) == zero && Transcendental::atanh(zero) == zero);
    assert!(Transcendental::acosh(Real::<Fixed>::one()) == zero);
    assert!(Transcendental::asinh(-c) == -Transcendental::asinh(c));
    assert!(Transcendental::atanh(-b) == -Transcendental::atanh(b));
    // `asinh` covers the whole range.
    assert!(Transcendental::asinh(fixed::MIN) == ExpTrait::asinh(fixed::MIN));
    assert!(Transcendental::asinh(fixed::MAX) == ExpTrait::asinh(fixed::MAX));
}

#[test]
fn test_transcendental_inverse_hyperbolics_round_trip() {
    // sinh(asinh(x)) = x, cosh(acosh(x)) = x, tanh(atanh(x)) = x, to within a few ulp.
    let tol = 64_u64;
    let (b, c) = (fx(B), fx(C));
    assert!(Real::abs_diff_eq(Transcendental::sinh(Transcendental::asinh(c)), c, tol));
    assert!(Real::abs_diff_eq(Transcendental::sinh(Transcendental::asinh(-c)), -c, tol));
    assert!(Real::abs_diff_eq(Transcendental::cosh(Transcendental::acosh(c)), c, tol));
    assert!(Real::abs_diff_eq(Transcendental::tanh(Transcendental::atanh(b)), b, tol));
    assert!(Real::abs_diff_eq(Transcendental::tanh(Transcendental::atanh(-b)), -b, tol));
}

#[test]
#[should_panic(expected: 'Fixed: acosh domain')]
fn test_transcendental_acosh_below_one_panics() {
    let _ = Transcendental::acosh(black_box(fx(0xFFFF_FFFF)));
}

#[test]
#[should_panic(expected: 'Fixed: atanh domain')]
fn test_transcendental_atanh_of_one_panics() {
    let _ = Transcendental::atanh(black_box(Real::<Fixed>::one()));
}

#[test]
#[should_panic(expected: 'Fixed: atanh domain')]
fn test_transcendental_atanh_of_minus_one_panics() {
    let _ = Transcendental::atanh(black_box(Real::<Fixed>::NEG_ONE));
}

#[test]
fn test_transcendental_exp_log_family_forwards_to_fixed() {
    let (a, b, c) = (fx(A), fx(B), fx(C));
    assert!(Transcendental::exp2(a) == ExpTrait::exp2(a));
    assert!(Transcendental::exp_m1(a) == ExpTrait::exp_m1(a));
    assert!(Transcendental::ln_1p(b) == ExpTrait::ln_1p(b));
    assert!(Transcendental::log(c, b + Real::one()) == ExpTrait::log(c, b + Real::one()));
    assert!(Transcendental::log2(c) == ExpTrait::log2(c));
    assert!(Transcendental::log10(c) == ExpTrait::log10(c));
    assert!(Transcendental::powf(c, a) == ExpTrait::powf(c, a));
    // Exact values.
    let zero = Real::<Fixed>::zero();
    assert!(Transcendental::exp2(Real::<Fixed>::from_int(3)) == Real::from_int(8));
    assert!(Transcendental::exp2(Real::<Fixed>::from_int(-2)) == fx(0x4000_0000));
    assert!(Transcendental::exp_m1(zero) == zero && Transcendental::ln_1p(zero) == zero);
    assert!(Transcendental::log2(Real::<Fixed>::from_int(8)) == Real::from_int(3));
    assert!(Transcendental::log2(Real::<Fixed>::one()) == zero);
    assert!(Transcendental::log10(Real::<Fixed>::one()) == zero);
    assert!(Transcendental::powf(c, zero) == Real::one());
    assert!(Transcendental::powf(zero, Real::TWO) == zero);
    // Negative base, integer exponent: the sign of `powi`.
    assert!(
        Transcendental::powf(-Real::<Fixed>::TWO, Real::from_int(3)) == -Real::<Fixed>::from_int(8),
    );
}

#[test]
#[should_panic(expected: 'Fixed: ln domain')]
fn test_transcendental_log2_of_zero_panics() {
    let _ = Transcendental::log2(black_box(Real::<Fixed>::zero()));
}

#[test]
#[should_panic(expected: 'Fixed: ln domain')]
fn test_transcendental_ln_1p_of_minus_one_panics() {
    let _ = Transcendental::ln_1p(black_box(Real::<Fixed>::NEG_ONE));
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_transcendental_log_base_one_panics() {
    let _ = Transcendental::log(black_box(Real::<Fixed>::TWO), Real::one());
}

#[test]
#[should_panic(expected: 'Fixed: powf domain')]
fn test_transcendental_powf_negative_base_fraction_panics() {
    let _ = Transcendental::powf(black_box(Real::<Fixed>::NEG_ONE), Real::HALF);
}
