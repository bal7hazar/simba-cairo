# AGENTS.md

Canonical instructions for AI agents (and humans) working on simba-cairo. Read
[docs/DESIGN.md](docs/DESIGN.md) first.

## Mission

The scalar trait layer of the provable-physics stack: `Real` / `Transcendental` implemented for
fixed-cairo's `fixed::Fixed`, the counterpart of Dimforge's `simba` for nalgebra-cairo. Every Cairo
step is proven, so gas is a first-class requirement, on par with correctness.

## Rules

- **No arithmetic here.** Every method delegates to `fixed`'s public API with `#[inline(always)]`
  (methods of impls; Cairo refuses the attribute on generic free functions). A kernel or rounding
  mode `fixed` lacks is an escalation to the fixed-cairo orchestrator, never a local
  reimplementation.
- **Names follow simba-rs** (`RealField` / `ComplexField`: `zero()`, `pi()`, `is_sign_negative`, …).
  The only exception is the documented set of fused kernels and literal-free constants (owner
  ruling 2026-09-24, see DESIGN): nalgebra-cairo's generic code needs them to stay efficient.
- **Pinned scalar.** `fixed` is a registry dependency pinned by version; `fixed` bumps MINOR on any
  numeric change, and so does `simba` when it follows.
- **Zero cost is measured.** Every delegating method keeps a `bench_real_<op>__generic` equal to the
  direct `fixed` call (`bench_<group>__<variant>`, `#[inline(never)]`, inputs through
  `simba_testing::black_box`, one `baseline` per group). `gas/*.json` is compared exactly in CI.
- Pure library: no `starknet` dependency, no storage, no proc macros.

## Definition of done

`./scripts/check.sh` green in the foreground, conventional commits, a PR following
`.github/PULL_REQUEST_TEMPLATE.md`, CI green before merge.
