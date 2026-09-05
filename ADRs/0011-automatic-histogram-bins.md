<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0011: Automatic histogram bin selection

- Status: Accepted
- Date: 2026-08-16
- Scope: UniPlot statistics, recipes and bindings

## Context

UniPlot supports fixed bin counts and explicit unequal boundaries. Automatic
selection was deferred until UniMath exposed native float64 roots and
logarithms. Implementing those operations locally would violate the Uni*
dependency graph, while delegating selection to a renderer would make CPU,
SVG and WGPU output disagree.

## Decision

Automatic selection is a deterministic statistics-stage operation. UniPlot
offers square-root, Sturges, Rice, Scott and Freedman-Diaconis rules. `Auto`
uses Freedman-Diaconis and falls back to Sturges when the interquartile range
cannot define a positive width. Scott similarly falls back to Sturges for zero
variance. Non-finite samples are ignored consistently with existing
histograms.

All scale-dependent calculations normalize finite samples before evaluating
spread, standard deviation or width. This avoids intermediate overflow without
changing the scale-invariant selected count. Counts are bounded to the number
of finite samples. Boundaries use overflow-safe affine interpolation and omit
interior values that cannot be represented distinctly in float64. Constant
samples use a positive unit interval when it is representable, matching the
pre-existing fixed-count histogram convention. At large magnitudes where
adding one rounds back to the sample, the nearest finite representable
neighbour supplies the second boundary.

The operation materializes ordinary numeric rectangle marks before rendering.
Consequently CPU, SVG and WGPU consume the same retained scene. The C ABI adds
an enum and one status-returning function; Python exposes the same enum values
and a dedicated method. Input arrays remain caller-owned and are copied before
the PlotSpec is published transactionally.

## Consequences

- UniMath remains the only source of native roots and logarithms.
- Automatic histograms serialize as their resulting ordinary PlotSpec; no
  hidden transform state or schema change is required.
- The selected theoretical count can exceed the number of representable
  intervals at a one-ULP domain. The returned boundaries, not an invalid
  duplicate, are authoritative.
- Benchmarks measure selection separately from PlotSpec construction and scene
  publication so convenience cannot hide statistical cost.
