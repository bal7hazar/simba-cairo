//! Scalar abstraction for nalgebra-cairo: the counterpart of Dimforge's `simba`.
//!
//! Rust has one real scalar, `f64`, and `simba` is a trait layer (`RealField`) implemented for
//! it; nalgebra is generic over `T: RealField`. Here the primitive is the Q32.32 `fixed::Fixed`
//! (package `fixed` from fixed-cairo, pinned to 0.3.0) and this package is the trait layer
//! implemented for it; nalgebra-cairo is generic over `T: Real`. See `docs/DESIGN.md`.
//!
//! - `scalar`: the `Real` trait (constants, helpers, fused kernels, the `Acc` accumulator) and
//!   `Transcendental`, with their `#[inline(always)]` impls for `fixed::Fixed`, which delegate
//!   every operation to `fixed`'s public API: the numeric specification (rounding, overflow,
//!   panic messages `'Fixed: ...'`) is `fixed`'s;
//! - `prelude`: everything needed to use `fixed::Fixed` through the traits with method syntax.

#[cfg(test)]
mod benches;
pub mod scalar;

/// `use simba::prelude::*;`: the scalar `fixed::Fixed`, its accumulator (`Real::Wide`) and the
/// scalar traits with their impls (method syntax). Operator impls need no import: they live in
/// the module of `fixed::Fixed`, where the compiler looks them up.
pub mod prelude {
    pub use fixed::Fixed;
    pub use fixed::wide::{Acc, AccTrait};
    pub use crate::scalar::{FixedReal, FixedTranscendental, Real, Transcendental};
}
