# simba-cairo

Scalar traits for provable linear algebra in Cairo: the counterpart of Dimforge's
[simba](https://github.com/dimforge/simba).

In Rust, `simba` is a trait layer (`RealField`, `ComplexField`) implemented for the primitive
`f32` / `f64`; nalgebra is generic over `T: RealField`. Here the primitive is the Q32.32
[`fixed::Fixed`](https://github.com/bal7hazar/fixed-cairo) and `simba` implements the traits for
it; [nalgebra-cairo](https://github.com/bal7hazar/nalgebra-cairo) is generic over `T: Real`.

Part of a stack porting reputable Rust crates to Cairo for provable game physics:
`fixed -> simba -> nalgebra -> rapier` and `fixed -> glam -> glamx -> rapier`.

## Package

| Package | Content |
|---|---|
| [`simba`](crates/simba) | `Real` (constants, helpers, fused kernels `sum_prod*` / `diff_prod` / `norm*`, the `fixed::wide::Acc` accumulator, prepared divisors `div3..div16`) and `Transcendental`, implemented for `fixed::Fixed` by delegation only (`#[inline(always)]`, zero-cost: no arithmetic of its own) |

```toml
[dependencies]
simba = "0.2.0"
fixed = "0.4.0"
```

The numeric specification (rounding, overflow, panic messages `'Fixed: ...'`) is `fixed`'s. See
[docs/DESIGN.md](docs/DESIGN.md).

## Development

`./scripts/check.sh` (fmt, lint, build, tests, gas snapshot; `--update` refreshes `gas/`).
CI job `Consumer cost` (`scripts/consumer_cost.py`, gates in `consumer_cost.toml`): at most 40,000
library lines, at most 5 s / 1 GB marginal cold-build cost, and the closure `simba` + `fixed` under
15 s / 3 GB. Measured locally: 711 library lines, closure with `fixed` 2.1 s / 0.24 GB over the
no-dependency build.
Toolchain pinned in `.tool-versions` (scarb 2.19.4, starknet-foundry 0.61.0).
