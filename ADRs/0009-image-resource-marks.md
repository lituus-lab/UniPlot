<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0009: Image resources and data-mapped marks

- Status: Accepted
- Date: 2026-08-16
- Scope: UniPlot grammar and retained scene

## Context

Retained raster layers position one owned UniImage behind a plot, but an image
mark needs row-wise data mapping and deterministic interleaving with other
marks. Storing pixel buffers in DataFrame columns would weaken its scalar
tabular model, complicate bindings and make ownership ambiguous.

## Decision

PlotSpec owns an insertion-ordered registry of named Gray, RGB or RGBA8
UniImage snapshots. An image-mark layer maps a categorical resource-name column
and numeric `xMin`, `xMax`, `yMin` and `yMax` columns. Compilation resolves each
finite row to one scene image node in row and layer order.

Resource names are unique, non-empty strings. Images and their placement are
validated both contractually and at runtime. Missing resource names are typed
PlotError failures; they are never dropped silently. Image marks initially
require linear Cartesian axes, matching retained raster-layer semantics.

The schema-v1 JSON representation gains optional ordered `imageResources` and
the additive `image` mapping field. C and Python procedural bindings may add a
single owned image mark directly, but must construct the same PlotSpec values
and preserve caller ownership through an explicit copy.

## Consequences

- DataFrame remains a scalar, renderer-independent table.
- Pixel ownership is explicit and retained plots cannot borrow caller memory.
- JSON round trips remain deterministic and self-contained.
- CPU, SVG and WGPU receive identical resolved image nodes.
- A later semantic GPU resource cache can key the same named resources without
  exposing backend handles in the grammar or scene.
