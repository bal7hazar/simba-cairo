//! Gas benchmarks of the `Real` layer over `fixed::Fixed` (AGENTS.md rule 8).
//!
//! Test-only. Three questions, each a `bench_real_<op>__<variant>` group with its `baseline`:
//!
//! - **Zero cost**: generic code over `Real` (`generic`) against the direct `fixed` call
//!   (`direct`), for `dot3`, `cross3`, `norm3`, `div`.
//! - **Two bit-identical `fixed` paths**: the named kernel of `fixed::wide` (`named`) against the
//!   same sum on the count-agnostic `fixed::wide::Acc` (`acc`), for `sum_prod2/3/4`,
//!   `diff_prod`, `mul_add`; and, for the square root of a long sum of squares (the static-count
//!   `wide_sqrt` sites of nalgebra: `Vector6::norm`, the Frobenius norms of `Matrix3`, `Matrix4`,
//!   `SymMatrix3`), `Acc::sqrt` (`acc`) against the typed `W6` / `W9` / `W16` accumulator and
//!   `WideSqrt` (`typed`).
//! - **`normalize3`**: three `Real::div` by `Real::norm3` (`div`, to nearest) against `fixed`'s
//!   `wide::normalize3` (`recip`, one reciprocal, rounded to nearest).
//!
//! - **Shared divisor**: `n` quotients by one divisor, per-element `Real::div`
//! (`alt_per_element_div`)
//!   against `Real::div3` / `div4` (`prepared`, one `fixed::wide::RecipNearest`), and at 2
//!   quotients against `fixed`'s prepared divisor directly: the break-even is 3 quotients.
//!
//! - **Zero cost of the forwarded methods** (0.3.0): `sinh_cosh`, `asinh`, `acosh`, `atanh`,
//!   `exp2`, `exp_m1`, `ln_1p`, `log`, `log2`, `log10`, `powf`, `copysign`, `ceil`, `round`,
//!   `trunc`, `fract`, `powi`, `hypot`: a `generic` call through `Real` / `Transcendental`
//!   against the `direct` `fixed` call (one `bench_real_<op>` group each, with its `baseline`).
//!
//! Plus the scalar headline figures of `docs/BENCHMARK.md` section 6 (`add`, `mul`, `div`,
//! `sqrt`, `sin_cos`, `atan2`, `sinh`, `cosh`, `tanh`) on `fixed::Fixed` through `Real` /
//! `Transcendental`.

use fixed::exp::ExpTrait;
use fixed::wide::{
    self, AccTrait, NormTrait, RecipNearestTrait, RecipTrait, WideAdd, WideSqrt, wide_mul,
};
use fixed::{Fixed, FixedTrait};
use crate::scalar::{Real, Transcendental};
use crate::testing::black_box;

// 1.5, -2.25, 3.75 and -4.5, 0.25, 2 as raw Q32.32 (dot = 0.1875), plus two inexact operands.
const AX: i64 = 0x1_8000_0000;
const AY: i64 = -0x2_4000_0000;
const AZ: i64 = 0x3_C000_0000;
const BX: i64 = -0x4_8000_0000;
const BY: i64 = 0x0_4000_0000;
const BZ: i64 = 0x2_0000_0000;
const P: i64 = -0x1_2345_6789;
const Q: i64 = 0x0_9abc_def1;
// 0.7 radian.
const ANGLE: i64 = 3006477107;

#[inline(always)]
fn fx(raw: i64) -> Fixed {
    Fixed { raw }
}

#[derive(Copy, Drop)]
struct V3<T> {
    x: T,
    y: T,
    z: T,
}

/// Generic code written against `Real` only, as nalgebra's.
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
    #[inline(always)]
    fn normalize(self: V3<T>) -> V3<T> {
        let n = R::norm3(self.x, self.y, self.z);
        V3 { x: R::div(self.x, n), y: R::div(self.y, n), z: R::div(self.z, n) }
    }
}

fn a3() -> V3<Fixed> {
    black_box(V3 { x: fx(AX), y: fx(AY), z: fx(AZ) })
}

fn b3() -> V3<Fixed> {
    black_box(V3 { x: fx(BX), y: fx(BY), z: fx(BZ) })
}

// --- the losing (or candidate) formulations ------------------------------------------------

/// `sum_prod2` on `Acc`.
#[inline(always)]
fn acc_dot2(a0: Fixed, b0: Fixed, a1: Fixed, b1: Fixed) -> Fixed {
    AccTrait::zero().add_prod(a0, b0).add_prod(a1, b1).narrow()
}

/// `sum_prod3` on `Acc`.
#[inline(always)]
fn acc_dot3(a0: Fixed, b0: Fixed, a1: Fixed, b1: Fixed, a2: Fixed, b2: Fixed) -> Fixed {
    AccTrait::zero().add_prod(a0, b0).add_prod(a1, b1).add_prod(a2, b2).narrow()
}

/// `sum_prod4` on `Acc`.
#[inline(always)]
fn acc_dot4(
    a0: Fixed, b0: Fixed, a1: Fixed, b1: Fixed, a2: Fixed, b2: Fixed, a3: Fixed, b3: Fixed,
) -> Fixed {
    AccTrait::zero().add_prod(a0, b0).add_prod(a1, b1).add_prod(a2, b2).add_prod(a3, b3).narrow()
}

/// `diff_prod` on `Acc`.
#[inline(always)]
fn acc_mul_sub(a: Fixed, b: Fixed, c: Fixed, d: Fixed) -> Fixed {
    AccTrait::zero().add_prod(a, b).sub_prod(c, d).narrow()
}

/// `mul_add` on `Acc`.
#[inline(always)]
fn acc_mul_add(a: Fixed, b: Fixed, c: Fixed) -> Fixed {
    AccTrait::add(AccTrait::zero().add_prod(a, b), c).narrow()
}

/// Square root of a sum of 6 squares on `Acc` (what `Real::wide_sqrt` does).
#[inline(always)]
fn acc_norm6(a: Fixed, b: Fixed, c: Fixed, d: Fixed, e: Fixed, f: Fixed) -> Fixed {
    let w = AccTrait::zero().add_prod(a, a).add_prod(b, b).add_prod(c, c);
    AccTrait::sqrt(w.add_prod(d, d).add_prod(e, e).add_prod(f, f))
}

/// Square root of a sum of 6 squares on the typed `W6`.
#[inline(always)]
fn typed_norm6(a: Fixed, b: Fixed, c: Fixed, d: Fixed, e: Fixed, f: Fixed) -> Fixed {
    let w = wide_mul(a, a).add(wide_mul(b, b)).add(wide_mul(c, c));
    w.add(wide_mul(d, d)).add(wide_mul(e, e)).add(wide_mul(f, f)).sqrt()
}

/// Square root of a sum of 9 squares on `Acc`.
#[inline(always)]
fn acc_norm9(
    a: Fixed, b: Fixed, c: Fixed, d: Fixed, e: Fixed, f: Fixed, g: Fixed, h: Fixed, i: Fixed,
) -> Fixed {
    let w = AccTrait::zero().add_prod(a, a).add_prod(b, b).add_prod(c, c);
    let w = w.add_prod(d, d).add_prod(e, e).add_prod(f, f);
    AccTrait::sqrt(w.add_prod(g, g).add_prod(h, h).add_prod(i, i))
}

/// Square root of a sum of 9 squares on the typed `W9`.
#[inline(always)]
fn typed_norm9(
    a: Fixed, b: Fixed, c: Fixed, d: Fixed, e: Fixed, f: Fixed, g: Fixed, h: Fixed, i: Fixed,
) -> Fixed {
    let w = wide_mul(a, a).add(wide_mul(b, b)).add(wide_mul(c, c));
    let w = w.add(wide_mul(d, d)).add(wide_mul(e, e)).add(wide_mul(f, f));
    w.add(wide_mul(g, g)).add(wide_mul(h, h)).add(wide_mul(i, i)).sqrt()
}

/// Square root of a sum of 16 squares on `Acc` (the 4 x 4 Frobenius norm).
#[inline(always)]
fn acc_norm16(m: [Fixed; 16]) -> Fixed {
    let [a, b, c, d, e, f, g, h, i, j, k, l, n, o, p, q] = m;
    let w = AccTrait::zero().add_prod(a, a).add_prod(b, b).add_prod(c, c).add_prod(d, d);
    let w = w.add_prod(e, e).add_prod(f, f).add_prod(g, g).add_prod(h, h);
    let w = w.add_prod(i, i).add_prod(j, j).add_prod(k, k).add_prod(l, l);
    AccTrait::sqrt(w.add_prod(n, n).add_prod(o, o).add_prod(p, p).add_prod(q, q))
}

/// Square root of a sum of 16 squares on the typed `W16`.
#[inline(always)]
fn typed_norm16(m: [Fixed; 16]) -> Fixed {
    let [a, b, c, d, e, f, g, h, i, j, k, l, n, o, p, q] = m;
    let w = wide_mul(a, a).add(wide_mul(b, b)).add(wide_mul(c, c)).add(wide_mul(d, d));
    let w = w.add(wide_mul(e, e)).add(wide_mul(f, f)).add(wide_mul(g, g)).add(wide_mul(h, h));
    let w = w.add(wide_mul(i, i)).add(wide_mul(j, j)).add(wide_mul(k, k)).add(wide_mul(l, l));
    w.add(wide_mul(n, n)).add(wide_mul(o, o)).add(wide_mul(p, p)).add(wide_mul(q, q)).sqrt()
}

// --- zero cost: generic `Real` code against the direct `fixed` call -------------------------

#[test]
#[inline(never)]
fn bench_real_dot3__baseline() {
    let _a = a3();
    let _b = b3();
    let e = black_box(fx(0x0_3000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_dot3__generic() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(0x0_3000_0000));
    assert!(a.dot(b) == e);
}

#[test]
#[inline(never)]
fn bench_real_dot3__direct() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(0x0_3000_0000));
    assert!(wide::dot3(a.x, b.x, a.y, b.y, a.z, b.z) == e);
}

#[test]
#[inline(never)]
fn bench_real_cross3__baseline() {
    let _a = a3();
    let _b = b3();
    let e = black_box(fx(-0x5_7000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_cross3__generic() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x5_7000_0000));
    assert!(a.cross(b).x == e);
}

#[test]
#[inline(never)]
fn bench_real_cross3__direct() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x5_7000_0000));
    let c = V3 {
        x: wide::mul_sub(a.y, b.z, a.z, b.y),
        y: wide::mul_sub(a.z, b.x, a.x, b.z),
        z: wide::mul_sub(a.x, b.y, a.y, b.x),
    };
    assert!(c.x == e);
}

#[test]
#[inline(never)]
fn bench_real_norm3__baseline() {
    let _a = a3();
    let e = black_box(fx(19856967406));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_norm3__generic() {
    let a = a3();
    let e = black_box(fx(19856967406));
    assert!(a.norm() == e);
}

#[test]
#[inline(never)]
fn bench_real_norm3__direct() {
    let a = a3();
    let e = black_box(fx(19856967406));
    assert!(wide::norm3(a.x, a.y, a.z) == e);
}

// --- sum_prod2/3/4, diff_prod, mul_add: `fixed::wide` named kernel vs `Acc` -----------------

#[test]
#[inline(never)]
fn bench_real_sum_prod2__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(-0x7_5000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod2__named() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x7_5000_0000));
    assert!(Real::sum_prod2(a.x, b.x, a.y, b.y) == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod2__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x7_5000_0000));
    assert!(acc_dot2(a.x, b.x, a.y, b.y) == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod3__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(0x0_3000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod3__named() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(0x0_3000_0000));
    assert!(Real::sum_prod3(a.x, b.x, a.y, b.y, a.z, b.z) == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod3__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(0x0_3000_0000));
    assert!(acc_dot3(a.x, b.x, a.y, b.y, a.z, b.z) == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod4__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(-0x0_6000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod4__named() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x0_6000_0000));
    assert!(Real::sum_prod4(a.x, b.x, a.y, b.y, a.z, b.z, b.y, a.y) == e);
}

#[test]
#[inline(never)]
fn bench_real_sum_prod4__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x0_6000_0000));
    assert!(acc_dot4(a.x, b.x, a.y, b.y, a.z, b.z, b.y, a.y) == e);
}

#[test]
#[inline(never)]
fn bench_real_diff_prod__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(-0x5_7000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_diff_prod__named() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x5_7000_0000));
    assert!(Real::diff_prod(a.y, b.z, a.z, b.y) == e);
}

#[test]
#[inline(never)]
fn bench_real_diff_prod__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x5_7000_0000));
    assert!(acc_mul_sub(a.y, b.z, a.z, b.y) == e);
}

#[test]
#[inline(never)]
fn bench_real_mul_add__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(-0x4_C000_0000));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_mul_add__named() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x4_C000_0000));
    assert!(Real::mul_add(a.x, b.x, b.z) == e);
}

#[test]
#[inline(never)]
fn bench_real_mul_add__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(-0x4_C000_0000));
    assert!(acc_mul_add(a.x, b.x, b.z) == e);
}

// --- square root of a long sum of squares: `Acc::sqrt` vs typed `Wn` + `WideSqrt` -----------

#[test]
#[inline(never)]
fn bench_real_norm6__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(29030770225));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_norm6__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(29030770225));
    assert!(acc_norm6(a.x, a.y, a.z, b.x, b.y, b.z) == e);
}

#[test]
#[inline(never)]
fn bench_real_norm6__typed() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(29030770225));
    assert!(typed_norm6(a.x, a.y, a.z, b.x, b.y, b.z) == e);
}

#[test]
#[inline(never)]
fn bench_real_norm9__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(29756406294));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_norm9__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(29756406294));
    assert!(acc_norm9(a.x, a.y, a.z, b.x, b.y, b.z, a.x, b.y, fx(0)) == e);
}

#[test]
#[inline(never)]
fn bench_real_norm9__typed() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(29756406294));
    assert!(typed_norm9(a.x, a.y, a.z, b.x, b.y, b.z, a.x, b.y, fx(0)) == e);
}

#[test]
#[inline(never)]
fn bench_real_norm16__baseline() {
    let (_a, _b) = (a3(), b3());
    let e = black_box(fx(41938632862));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_norm16__acc() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(41938632862));
    let m = [a.x, a.y, a.z, b.x, b.y, b.z, a.x, a.y, a.z, b.x, b.y, b.z, a.x, b.y, fx(P), fx(Q)];
    assert!(acc_norm16(m) == e);
}

#[test]
#[inline(never)]
fn bench_real_norm16__typed() {
    let (a, b) = (a3(), b3());
    let e = black_box(fx(41938632862));
    let m = [a.x, a.y, a.z, b.x, b.y, b.z, a.x, a.y, a.z, b.x, b.y, b.z, a.x, b.y, fx(P), fx(Q)];
    assert!(typed_norm16(m) == e);
}

// --- normalize3: `Real::div` by the norm vs `fixed::wide::normalize3` -----------------------

#[test]
#[inline(never)]
fn bench_real_normalize3__baseline() {
    let _a = a3();
    let e = black_box(fx(3483678492));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_normalize3__div() {
    let a = a3();
    let e = black_box(fx(3483678492));
    assert!(a.normalize().z == e);
}

#[test]
#[inline(never)]
fn bench_real_normalize3__recip() {
    let a = a3();
    let e = black_box(fx(3483678492));
    let (_, _, z) = wide::normalize3(a.x, a.y, a.z);
    assert!(z == e);
}

// --- scalar headline figures (`docs/BENCHMARK.md` section 6) --------------------------------

#[test]
#[inline(never)]
fn bench_real_scalar__baseline() {
    let _a = black_box(fx(P));
    let _b = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__add() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(P + Q));
    assert!(a + b == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__mul() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(-2953749737));
    assert!(a * b == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__div() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(-8084644371));
    assert!(Real::div(a, b) == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__recip() {
    let (a, _b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(-3774873601));
    assert!(Real::recip(a) == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__sqrt() {
    let (_a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(3339166348));
    assert!(Real::sqrt(b) == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__inv_norm2() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(3333650220));
    assert!(inv_norm2(a, b) == e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__sin_cos() {
    let (a, _b) = (black_box(fx(ANGLE)), black_box(fx(Q)));
    let e = black_box(fx(0));
    let (s, _) = Transcendental::sin_cos(a);
    assert!(s != e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__atan2() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(Transcendental::atan2(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__sinh() {
    let (a, _b) = (black_box(fx(ANGLE)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(Transcendental::sinh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__cosh() {
    let (a, _b) = (black_box(fx(ANGLE)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(Transcendental::cosh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_scalar__tanh() {
    let (a, _b) = (black_box(fx(ANGLE)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(Transcendental::tanh(a) != e);
}


// --- zero cost of the methods forwarded in 0.3.0: generic `Real` / `Transcendental` code against
// the direct `fixed` call (same gas, `bench_real_<op>__generic` == `bench_real_<op>__direct`) ---

/// Generic code over `Real` and `Transcendental` only, as nalgebra's.
#[generate_trait]
impl ScalarOps<T, impl R: Real<T>, impl X: Transcendental<T>> of ScalarOpsTrait<T> {
    #[inline(always)]
    fn g_sinh_cosh(x: T) -> (T, T) {
        X::sinh_cosh(x)
    }
    #[inline(always)]
    fn g_asinh(x: T) -> T {
        X::asinh(x)
    }
    #[inline(always)]
    fn g_acosh(x: T) -> T {
        X::acosh(x)
    }
    #[inline(always)]
    fn g_atanh(x: T) -> T {
        X::atanh(x)
    }
    #[inline(always)]
    fn g_exp2(x: T) -> T {
        X::exp2(x)
    }
    #[inline(always)]
    fn g_exp_m1(x: T) -> T {
        X::exp_m1(x)
    }
    #[inline(always)]
    fn g_ln_1p(x: T) -> T {
        X::ln_1p(x)
    }
    #[inline(always)]
    fn g_log(x: T, y: T) -> T {
        X::log(x, y)
    }
    #[inline(always)]
    fn g_log2(x: T) -> T {
        X::log2(x)
    }
    #[inline(always)]
    fn g_log10(x: T) -> T {
        X::log10(x)
    }
    #[inline(always)]
    fn g_powf(x: T, y: T) -> T {
        X::powf(x, y)
    }
    #[inline(always)]
    fn g_copysign(x: T, y: T) -> T {
        R::copysign(x, y)
    }
    #[inline(always)]
    fn g_ceil(x: T) -> T {
        R::ceil(x)
    }
    #[inline(always)]
    fn g_round(x: T) -> T {
        R::round(x)
    }
    #[inline(always)]
    fn g_trunc(x: T) -> T {
        R::trunc(x)
    }
    #[inline(always)]
    fn g_fract(x: T) -> T {
        R::fract(x)
    }
    #[inline(always)]
    fn g_powi(x: T) -> T {
        R::powi(x, 3)
    }
    #[inline(always)]
    fn g_hypot(x: T, y: T) -> T {
        R::hypot(x, y)
    }
}

#[test]
#[inline(never)]
fn bench_real_sinh_cosh__baseline() {
    let _a = black_box(fx(ANGLE));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_sinh_cosh__generic() {
    let a = black_box(fx(ANGLE));
    let e = black_box(fx(0));
    let (s, t) = ScalarOpsTrait::<Fixed>::g_sinh_cosh(a);
    assert!(s != e && t != e);
}

#[test]
#[inline(never)]
fn bench_real_sinh_cosh__direct() {
    let a = black_box(fx(ANGLE));
    let e = black_box(fx(0));
    let (s, t) = ExpTrait::sinh_cosh(a);
    assert!(s != e && t != e);
}

#[test]
#[inline(never)]
fn bench_real_asinh__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_asinh__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_asinh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_asinh__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ExpTrait::asinh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_acosh__baseline() {
    let _a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_acosh__generic() {
    let a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_acosh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_acosh__direct() {
    let a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(ExpTrait::acosh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_atanh__baseline() {
    let _a = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_atanh__generic() {
    let a = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_atanh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_atanh__direct() {
    let a = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(ExpTrait::atanh(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_exp2__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_exp2__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_exp2(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_exp2__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ExpTrait::exp2(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_exp_m1__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_exp_m1__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_exp_m1(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_exp_m1__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ExpTrait::exp_m1(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_ln_1p__baseline() {
    let _a = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_ln_1p__generic() {
    let a = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_ln_1p(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_ln_1p__direct() {
    let a = black_box(fx(Q));
    let e = black_box(fx(0));
    assert!(ExpTrait::ln_1p(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_log__baseline() {
    let (_a, _b) = (black_box(fx(AX)), black_box(fx(0x2_0000_0000)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_log__generic() {
    let (a, b) = (black_box(fx(AX)), black_box(fx(0x2_0000_0000)));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_log(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_log__direct() {
    let (a, b) = (black_box(fx(AX)), black_box(fx(0x2_0000_0000)));
    let e = black_box(fx(0));
    assert!(ExpTrait::log(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_log2__baseline() {
    let _a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_log2__generic() {
    let a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_log2(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_log2__direct() {
    let a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(ExpTrait::log2(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_log10__baseline() {
    let _a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_log10__generic() {
    let a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_log10(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_log10__direct() {
    let a = black_box(fx(AX));
    let e = black_box(fx(0));
    assert!(ExpTrait::log10(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_powf__baseline() {
    let (_a, _b) = (black_box(fx(AX)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_powf__generic() {
    let (a, b) = (black_box(fx(AX)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_powf(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_powf__direct() {
    let (a, b) = (black_box(fx(AX)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(ExpTrait::powf(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_copysign__baseline() {
    let (_a, _b) = (black_box(fx(Q)), black_box(fx(P)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_copysign__generic() {
    let (a, b) = (black_box(fx(Q)), black_box(fx(P)));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_copysign(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_copysign__direct() {
    let (a, b) = (black_box(fx(Q)), black_box(fx(P)));
    let e = black_box(fx(0));
    assert!(FixedTrait::copysign(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_ceil__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_ceil__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_ceil(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_ceil__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(FixedTrait::ceil(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_round__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_round__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_round(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_round__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(FixedTrait::round(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_trunc__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_trunc__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_trunc(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_trunc__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(FixedTrait::trunc(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_fract__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_fract__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_fract(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_fract__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(FixedTrait::fract(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_powi__baseline() {
    let _a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_powi__generic() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_powi(a) != e);
}

#[test]
#[inline(never)]
fn bench_real_powi__direct() {
    let a = black_box(fx(P));
    let e = black_box(fx(0));
    assert!(FixedTrait::powi(a, 3) != e);
}

#[test]
#[inline(never)]
fn bench_real_hypot__baseline() {
    let (_a, _b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_hypot__generic() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(ScalarOpsTrait::<Fixed>::g_hypot(a, b) != e);
}

#[test]
#[inline(never)]
fn bench_real_hypot__direct() {
    let (a, b) = (black_box(fx(P)), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(wide::norm2(a, b) != e);
}

// --- a divisor shared by n quotients: per-element `Real::div` vs `Real::divisor` + `div_by` ---

#[test]
#[inline(never)]
fn bench_real_shared_div2__baseline() {
    let (_a, _d) = (a3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div2__alt_per_element_div() {
    let (a, d) = (a3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(Real::div(a.x, d) != e && Real::div(a.y, d) != e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div2__prepared() {
    let (a, d) = (a3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    // Below the `divN` family: `fixed`'s prepared divisor directly.
    let r = RecipNearestTrait::new(d);
    assert!(r.div_nearest(a.x) != e && r.div_nearest(a.y) != e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div3__baseline() {
    let (_a, _d) = (a3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div3__alt_per_element_div() {
    let (a, d) = (a3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(Real::div(a.x, d) != e && Real::div(a.y, d) != e && Real::div(a.z, d) != e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div3__prepared() {
    let (a, d) = (a3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    let (x, y, z) = Real::div3(a.x, a.y, a.z, d);
    assert!(x != e && y != e && z != e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div4__baseline() {
    let (_a, _b, _d) = (a3(), b3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_shared_div4__alt_per_element_div() {
    let (a, b, d) = (a3(), b3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    assert!(
        Real::div(a.x, d) != e
            && Real::div(a.y, d) != e
            && Real::div(a.z, d) != e
            && Real::div(b.x, d) != e,
    );
}

#[test]
#[inline(never)]
fn bench_real_shared_div4__prepared() {
    let (a, b, d) = (a3(), b3(), black_box(fx(Q)));
    let e = black_box(fx(0));
    let (x, y, z, w) = Real::div4(a.x, a.y, a.z, b.x, d);
    assert!(x != e && y != e && z != e && w != e);
}

/// `1 / sqrt(x^2 + y^2)` through `fixed`'s normalisation path: `wide::norm2_wide(x, y)` (floor
/// of the exact norm), then `recip().mul(one())`, one rounding to nearest. The measured loser for
/// the Jacobi `c` of nalgebra's `SymmetricEigen3` / `Svd3` (cheaper, worse SVD records), kept as
/// evidence (AGENTS.md rule 8); formerly `Real::inv_norm2`, not part of upstream `RealField`.
#[inline(always)]
fn inv_norm2(x: Fixed, y: Fixed) -> Fixed {
    wide::norm2_wide(x, y).recip().mul(fixed::ONE)
}

#[test]
fn test_inv_norm2_rounds_to_nearest() {
    // 1/5 = 858993459.2 raw.
    assert!(inv_norm2(Real::from_int(3), Real::from_int(-4)) == fx(858993459));
    // 1 / floor(sqrt(2)) = 3037000500.45 raw (the exact 1/sqrt(2) is 3037000499.98 raw).
    assert!(inv_norm2(Real::one(), Real::one()) == fx(3037000500));
    assert!(inv_norm2(Real::one(), Real::zero()) == Real::one());
}

#[test]
#[should_panic(expected: 'Fixed: division by zero')]
fn test_inv_norm2_of_zero_panics() {
    let _ = inv_norm2(black_box(Real::zero()), Real::zero());
}

// --- Jacobi rotation `c = 1 / sqrt(1 + t^2)`: `recip(sqrt(mul_add))` (shipped in nalgebra's
// `SymmetricEigen3` / `Svd3`, better SVD records) vs `inv_norm2(1, t)` (cheaper) -------------

#[test]
#[inline(never)]
fn bench_real_jacobi_c__baseline() {
    let _t = black_box(fx(-Q));
    let e = black_box(fx(0));
    assert!(e == e);
}

#[test]
#[inline(never)]
fn bench_real_jacobi_c__recip_sqrt() {
    let t = black_box(fx(-Q));
    let e = black_box(fx(0));
    assert!(Real::recip(Real::sqrt(Real::mul_add(t, t, Real::one()))) != e);
}

#[test]
#[inline(never)]
fn bench_real_jacobi_c__alt_inv_norm2() {
    let t = black_box(fx(-Q));
    let e = black_box(fx(0));
    assert!(inv_norm2(Real::one(), t) != e);
}
