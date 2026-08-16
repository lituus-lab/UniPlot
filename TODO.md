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
- [x] Strict explicit numeric and categorical x domains with
  backward-compatible schema-v1 serialization.
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
- [x] Add exact CPU/GPU pixel-parity fixtures for pixel-aligned geometry and
  single-layer RGBA8 publication; bound stacked translucent differences to one
  RGBA8 unit because CPU quantizes after every layer while GPU retains RGBA16F.
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
- [x] Explicit subplot grids with independent axes and retained-scene output.
- [x] Shared numeric domains and categorical x order across explicit plot
  grids, including C and Python bindings.
- [x] One-dimensional categorical facets in Nim, C and Python.
- [x] Two-dimensional categorical facet matrices preserving empty Cartesian
  cells in Nim, C and Python.
- [x] Affine secondary y guides sharing primary positions in Nim, C and Python.
- [x] Categorical colour aesthetic mappings through UniColor palettes.
- [x] Numeric size and alpha aesthetic mappings with explicit ranges.
- [x] Fill, shape and line-style aesthetic mappings.
- [x] Continuous colour maps, discrete palettes and colour bars.
- [x] Logarithmic transformed and reversed Cartesian axes.
- [x] Deterministic UTC date/time and signed-duration axes using the numeric
  retained-scene path defined by ADR-0010.
- [ ] Additional numeric transforms and polar coordinates.
- [x] Error bars and ribbons with explicit numeric bounds and missing-value
      policies.
- [x] Grouped box plots with type-7 quartiles, Tukey whiskers and outliers in
  Nim, C and Python.
- [x] Categorical heatmaps with complete count/sum/mean/min/max aggregation in
  Nim, C and Python.
- [x] Variable-size numeric vector-cell heatmaps in Nim, C and Python.
- [ ] Violin plots, kernel density, contours and raster/image heatmaps.
- [x] Type-7 quantiles and reusable descriptive summaries with Tukey whiskers.
- [x] First-seen categorical two-dimensional aggregation with explicit absent
  cells and UniAccurate compensated sum/mean.
- [x] Explicit finite, strictly ordered histogram boundaries in Nim, C and
  Python, with documented out-of-domain handling.
- [x] First-seen one-dimensional grouped count, sum, mean, minimum and maximum
  in Nim, C and Python, using UniAccurate for compensated sum and mean.
- [x] Retained numeric rectangle marks and variable-width count/density
  histograms in Nim, C and Python.
- [x] Automatic square-root, Sturges, Rice, Scott and Freedman–Diaconis
  histogram bin selection through UniMath, including C and Python bindings.
- [ ] Smoothing, multi-column or windowed grouped transforms and confidence
  intervals.
- [x] Reference lines and reference bands in numeric data coordinates.
- [x] Plain data-coordinate text annotations and arrows in Nim, C and Python.
- [ ] Rich multi-style text runs after UniGlyph exposes run-level styling.
- [x] Data-mapped image marks through the ordered owned-resource design in
      ADR-0009; retained raster layers are implemented.
- [x] Missing-value policies and intentional line breaks.
- [x] Theme inheritance, reusable style values and publication presets.
- [ ] Deterministic PDF output through a lower-level Uni* backend.
- [x] Declarative JSON serialization with a versioned schema and deterministic
      round trips.

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
- [x] Keep a configurable, count- and byte-bounded LRU of `WgpuPreparedScene`
  mesh buffers, image-quad buffers and logical RGBA8 textures by unique
  process-local handle identity, with independent direct-stream buffers and
  explicit hit/miss/upload/eviction tests. The byte budget covers allocated
  prepared-buffer capacities and resident texture payloads.
- [x] Split vertex/index queue uploads into configurable aligned byte-bounded
  writes, with exact call/byte diagnostics and pixel-identity tests.
- [x] Enforce a total configurable bound over UniPlot-managed prepared/direct
  buffer capacities, readback capacity and logical RGBA16F target bytes, with
  component/high-water diagnostics and LRU pressure tests. Opaque driver
  allocations remain explicitly outside this accounting boundary.
- [x] Rotate direct uploads through a configurable managed streaming ring,
  retaining real wgpu-native submission indices and synchronizing a slot before
  reuse; cover readback/idle release, exact diagnostics and drained-burst
  benchmarks.
- [ ] Level-of-detail, decimation and visibility culling for large series.
- [ ] Instanced points, lines and rectangles; indirect draws where supported.
- [ ] Timestamp-query instrumentation with wall-clock fallback.
- [ ] Notebook/web embedding and an explicit remote-rendering protocol.

## Performance investigations

- [x] Train continuous and band scale domains incrementally without retaining
  or sorting concatenated samples.
- [x] Compile layers through allocation-light row filters while preserving the
  materialising `finiteRows` compatibility helper.
- [x] Expose reusable CPU/SVG and WGPU prepared scenes that retain shaped,
      flattened and tessellated paths.
- [x] Add count- and logical-payload-bounded automatic prepared-scene caching
  by a versioned BLAKE3-256 key over canonical render values and UniGlyph's
  exact font-content identity, with mutation/LRU/oversize tests, diagnostics,
  an explicit purge and separate key/hit/automatic-submit benchmarks.
- [ ] Batch compatible CPU fills and GPU draw calls without changing ordering.
- [x] Use a prepared or batch ordered-palette sampler supplied by UniColor;
  never duplicate its interpolation, gamut mapping or palette semantics in
  UniPlot.
- [ ] Measure SIMD opportunities through UniMath/UniLinalg rather than local
  vector kernels.
- [ ] Measure parallel scene compilation before adding concurrency.
- [ ] Replace materialised facet-frame copies with an immutable indexed data
  view after measuring its effects on compilation and binding ownership.
- [x] Track isolated process RSS and Nim heap high-water marks for scene
  compilation, preparation and real SVG/PNG publication.
- [ ] Track cumulative bytes allocated per rendered frame once a supported
  allocator-instrumentation boundary exists; never relabel live heap growth or
  allocation counts as byte traffic.
- [x] Add 10³, 10⁵ and 10⁶-point workloads with explicit output semantics.
- [x] Compare warm and cold paths separately for every provider.
- [x] Keep benchmark dependency installation explicit and outside library
  installation.
