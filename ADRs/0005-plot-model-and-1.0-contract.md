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

The 1.0 contract excludes facets, date-aware ticks, statistical smoothing, 3D
and volume plots, a GUI toolkit, arbitrary shader code, implicit network data
loading, and full compatibility with third-party plot object models. These can
be layered above the stable specification and scene boundaries.

The C ABI and Python binding intentionally expose owned plot handles, line and
point series, titles, and SVG/PNG export. DataFrame mutation, custom layers,
categorical bars, areas, text mappings, raw scenes, scales and histogram bins
remain Nim-only because their tagged, generic or nested value models have no
stable flat C representation. Bindings use the procedural recipes; they do not
duplicate the complete grammar object model.
