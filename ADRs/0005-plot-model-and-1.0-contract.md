<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0005: Plot model and 1.0 contract

- Status: Accepted
- Date: 2026-08-15
- Scope: UniPlot public model

## Decision

UniPlot has one value-oriented specification model and one compiled retained scene.
The procedural API constructs the same specifications as the grammar API.
Statistics and scale training happen before scene construction; renderers only
consume resolved coordinates, styles, paths, meshes and text runs.

The 1.0 publication contract includes Cartesian 2D line, point, bar, area,
histogram recipes and text layers; continuous and categorical scales; Cartesian
axes, labels, themes; and deterministic SVG and raster export.

## Invariants

1. Input data is owned or explicitly borrowed; retained plots never hide a
   dangling view.
2. Layer order is insertion order and therefore deterministic.
3. Scale domains are trained from finite values only; an empty trained domain
   is an error unless the user provides one explicitly.
4. Statistics operate in data space, before coordinate transformation.
5. Guides derive from trained scales and never mutate them.
6. Scene nodes contain no callbacks into the grammar or source data.
7. CPU rendering defines backend semantics.

## Exclusions

This ADR established the minimum 1.0 contract. Later accepted ADRs extended it
additively with facets, temporal ticks, statistical recipes and polar
coordinates without changing the specification/scene boundary. The remaining
exclusions are 3D and volume plots, a GUI toolkit, arbitrary shader code,
implicit network data loading, and full compatibility with third-party plot
object models.

The C ABI and Python binding expose owned plot handles and additive procedural
recipes rather than duplicating the complete tagged grammar object model.
Nested custom layers and raw retained scenes remain Nim-only where no stable
flat representation exists.

The statistical helpers stay Nim-only too, and for two separate reasons.
`histogramBinCount`, `automaticHistogramBreaks` and `contourSegments` are
inputs the recipes consume, not results a caller asks for: a C caller adds a
histogram layer and the binning happens inside it. `quantile`, `summarize` and
`aggregateGroups` are thin over UniStatistics, which ADR-0012 makes the owner
of those definitions and which exposes its own C ABI -- a second entry point
here would be a second place for them to drift.
