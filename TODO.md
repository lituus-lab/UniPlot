<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPlot implementation roadmap

This file distinguishes the production 1.0 contract from later competitor
parity. Checked items are implemented and must remain covered by tests.
Unchecked 1.0 items are release blockers. Later items may extend the retained
scene without weakening its deterministic CPU semantics.

## 1.0 foundation

- [x] Typed numeric and categorical columns with finite-row filtering.
- [x] Layered, value-oriented plot specifications and stable scene node IDs.
- [x] Linear, logarithmic and band scales with deterministic ticks.
- [x] Line, point, bar, area and text marks; histogram recipe.
- [x] Axes, grid, tick labels, titles, axis labels and themes.
- [x] UniColor styling, UniGlyph text, UniVector paths and UniImage output.
- [x] Deterministic SVG and PNG backends consuming the same scene.
- [x] CLI plus versioned C and Python bindings.
- [x] Multipage executable nimib manual, including C and Python pages.
- [x] Rosetta examples and same-machine Matplotlib, Plotly, ggplot2 and
  Plots.jl benchmark harness.
- [x] Debug contracts, release tests, import-layer validation and lint gates.
- [x] Add direct regression tests for public constructors and rejection
  families, including release-mode runtime guards where contracts compile
  away and NULL/argument validation across the C ABI.
- [x] Record a clean full-suite debug/release/C/Python/book result for the
  release candidate.

## 1.0 GPU and performance

- [x] Optional runtime loading with no WGPU dependency in the core import.
- [x] Pure-Nim installer pinned to wgpu-native 29.0.1.1.
- [x] Real adapter, device and queue creation.
- [x] Offscreen RGBA8 render passes and aligned GPU-to-CPU readback.
- [x] WGSL pipeline rendering UniVector indexed triangle meshes.
- [x] UniGlyph text and ordered retained scenes rendered through the same
  UniVector tessellation path.
- [x] Shader and render pipeline retained across frames.
- [x] Cache or pool vertex, index, texture and readback buffers by capacity.
- [x] Separate submission from optional readback so interactive frames do not
  pay a synchronous CPU transfer.
- [x] Handle uncaptured validation errors and asynchronous device loss.
- [x] Expose adapter identity and relevant limits without leaking WGPU ABI
  types.
- [x] Add an exact CPU/GPU pixel-parity fixture for pixel-aligned geometry.
- [x] Add an antialiased CPU/GPU fixture whose tolerance is confined to the
  one-pixel cells intersected by the geometric edge.
- [x] Add release benchmarks separating scene preparation, retained upload and
  submission, and readback publication throughput.
- [x] Establish adapter-bound regression thresholds from repeated same-machine
  runs; never encode cross-machine marketing claims.
- [x] Exercise Linux Vulkan and Windows DX12 in CI in addition to Metal.

## Functional parity after 1.0

These are required for broad Matplotlib/ggplot2/Plotly parity, but are not
silently claimed by the focused 1.0 publication contract.

- [x] Legends derived from named layers with explicit visibility and title
  control.
- [ ] Facets, subplot grids, shared axes and secondary axes.
- [x] Categorical colour aesthetic mappings through UniColor palettes.
- [x] Numeric size and alpha aesthetic mappings with explicit ranges.
- [x] Fill, shape and line-style aesthetic mappings.
- [x] Continuous colour maps, discrete palettes and colour bars.
- [ ] Date/time, duration, transformed, reversed and polar coordinates.
- [ ] Error bars, ribbons, box/violin plots, density, contours and heatmaps.
- [ ] Statistical transforms: binning variants, smoothing, aggregation,
  quantiles and confidence intervals.
- [ ] Annotations, reference lines/bands, arrows and rich text.
- [ ] Image marks and raster layers.
- [x] Missing-value policies and intentional line breaks.
- [ ] Theme inheritance, reusable style sheets and publication presets.
- [ ] Deterministic PDF output through a lower-level Uni* backend.
- [ ] Declarative JSON serialization with a versioned schema.

Dash arrays and marker placement now come from UniVector and are shared by the
CPU, SVG and WGPU paths. Advanced shaping, fallback and glyph atlas policy
belong in UniGlyph. UniPlot must stop and propose lower-level changes rather
than introducing competing geometry or text implementations.

## Interactive and large-data parity after 1.0

- [ ] Window/surface integration isolated from headless rendering.
- [ ] Picking buffer keyed by stable scene-node IDs.
- [ ] Pan, zoom, selection, hover and linked-view event contracts.
- [ ] Observable data updates and incremental scene diffs.
- [ ] Persistent GPU resources keyed by semantic resource IDs.
- [ ] Chunked uploads, streaming/ring buffers and bounded memory policies.
- [ ] Level-of-detail, decimation and visibility culling for large series.
- [ ] Instanced points, lines and rectangles; indirect draws where supported.
- [ ] Timestamp-query instrumentation with wall-clock fallback.
- [ ] Notebook/web embedding and an explicit remote-rendering protocol.

## Performance investigations

- [x] Train continuous and band scale domains incrementally without retaining
  or sorting concatenated samples.
- [x] Compile layers through allocation-light row filters while preserving the
  materialising `finiteRows` compatibility helper.
- [x] Expose reusable prepared scenes that retain shaped and tessellated paths.
- [ ] Add bounded automatic prepared-scene caching by stable semantic key.
- [ ] Batch compatible CPU fills and GPU draw calls without changing ordering.
- [ ] Use a prepared or batch ordered-palette sampler supplied by UniColor;
  never duplicate its interpolation, gamut mapping or palette semantics in
  UniPlot.
- [ ] Measure SIMD opportunities through UniMath/UniLinalg rather than local
  vector kernels.
- [ ] Measure parallel scene compilation before adding concurrency.
- [ ] Track peak resident memory and bytes allocated per rendered frame.
- [ ] Add 10³, 10⁵ and 10⁶-point workloads with explicit output semantics.
- [ ] Compare warm and cold paths separately for every provider.
- [ ] Keep benchmark dependency installation explicit and outside library
  installation.
