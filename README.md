<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPlot

UniPlot is the pure-Nim scientific visualisation engine of the Uni* family. It
turns typed data and plotting specifications into a renderer-neutral scene,
then exports that scene through deterministic CPU backends. UniGlyph owns text;
UniVector and UniImage own vector and raster primitives.

Version 1.0 covers publication-quality two-dimensional plots. Its public model
supports both a concise procedural API and a composable grammar so applications
can choose a Matplotlib-like or ggplot2-like workflow without maintaining two
rendering engines.

## What is inside

- typed columns, rows and finite-value filtering;
- linear, logarithmic, symmetric-logarithmic and categorical scales;
- CSS colour styling through UniColor;
- categorical colour mappings backed by immutable UniColor palettes;
- numeric colour and fill mappings with UniColor ramps and color bars;
- categorical fill and marker-shape mappings with semantic legends;
- solid, dashed, dotted, dot-dash and long-dash line styles;
- explicit drop, break and reject policies for non-finite mapped values;
- numeric size and alpha mappings with explicit output ranges;
- line, point, bar, area and text layers, plus histogram recipes;
- Cartesian axes, ticks, labels, titles and themes;
- explicit layer-derived legends with deterministic layout;
- an inspectable retained scene shared by SVG and raster rendering;
- deterministic SVG and PNG export;
- value-oriented plot specifications and deterministic scene compilation;
- a `uniplot` CLI, C ABI and Python binding;
- an optional native WGPU backend for offscreen scene rendering and readback,
  with no GPU dependency in the core.

## Architecture

```text
data -> mappings -> UniStatistics-backed recipes -> scales -> guides -> scene -> backend
                                                     |-> SVG
                                                     |-> raster/PNG
                                                     `-> optional WGPU
```

The dependency direction is fixed:

```text
common < data < scales < stats < grammar < scene < guides < render < c_api
```

Backends consume the scene. They never participate in scale training, layout or
statistics. Type-7 quantiles and range-safe means delegate to UniStatistics,
keeping CPU and GPU output equivalent without a second implementation.
Gaussian density and violin recipes likewise reuse UniStatistics bandwidths
and kernels, then materialise ordinary retained area, line and polygon marks.

## 1.0 contract

The stable unit is a renderer-neutral plot specification plus its compiled
scene. Equal specifications, dimensions and font inputs produce equal scene
ordering and deterministic vector output. Errors are typed; invalid dimensions,
non-finite layout parameters and incompatible mappings are rejected rather than
silently repaired.

UniPlot 1.0 does not promise a complete clone of any single plotting library,
nonlinear smoothers, 3D scenes, volume rendering,
arbitrary shader injection, a GUI event loop, or a bundled WGPU runtime.
Interactivity, picking, observables and streaming use explicit extension points
and may grow without changing the CPU scene contract.

## The Uni* family

UniPlot depends only on lower-level engines: UniMath, UniAccurate,
UniStatistics, UniLinalg, UniColor, UniImage, UniVector and UniGlyph. Domain
libraries such as UniGeom and UniGraph
may provide adapters that consume UniPlot; UniPlot never imports them. The
[family overview](https://github.com/lituus-lab/.github) documents the shared
architecture and contribution principles.

## Provenance & development

UniPlot translates established plotting concepts from Python, R and Julia into
the typed, dependency-directed Uni* architecture. Its implementation was built
with LLM-assisted review over the family design and existing hand-written Nim
engines; the short linear history records that reconstruction, not the full
history of the underlying design work.

## Benchmarks

`nimble benchmark` runs the reproducible off-screen UniPlot, Matplotlib, Plotly,
ggplot2 and Plots.jl baseline described in `benchmarks/README.md`, using the
providers available in its isolated environments. It records construction/scene
compilation, SVG and PNG stages with warmups, distribution statistics,
dependency versions and machine metadata. Results are intended for same-machine
regression tracking; the suite makes no universal performance claim.

## Build

```bash
nimble install -y
nimble test
nimble testRelease
nimble testAll
nimble example
nimble ctest
nimble pyTest
nimble benchmarkDeps  # optional isolated Matplotlib/Plotly/ggplot2/Plots.jl setup
nimble benchmark
nimble book
nimble docs
```

## GPU boundary

The core contains renderer-neutral resource identifiers, meshes, paths, text
runs and clip nodes. The optional WGPU backend dynamically opens the pinned
`wgpu-native` runtime and creates an adapter, device and queue. Importing
`UniPlot` never loads or links WGPU, and CPU rendering remains the reference
semantics on every supported platform.

Install the pinned runtime with `nimble wgpuDeps`, then validate the native
device path with `nimble wgpuTest`. Both tasks are implemented in Nim; the
downloaded runtime stays in the ignored `.deps` directory.

`prepareWgpuScene` shapes UniGlyph text and tessellates UniVector paths once,
including UniVector marker geometry and expanded dashed strokes.
`submitWgpuScene` and `renderWgpuScene` first derive a BLAKE3-256 key from the
canonical render semantics and UniGlyph's exact font-content identity. A
backend retains up to 16 host preparations and 256 MiB of prepared mesh,
image-quad and logical RGBA8 texture payload by default; `sceneCacheCapacity`
and `sceneCacheByteBudget` configure
those independent bounds. Node IDs and path-builder cursor state are excluded
because neither changes pixels. Any render value or text-bearing font change
causes a miss. `clearWgpuSceneCache` releases retained host preparations while
preserving lifetime counters.

The first `submitWgpuPrepared` uploads that geometry; repeated submission or
publication keeps prepared scenes resident and does not issue another upload
on a cache hit. `openWgpuBackend` accepts contractual bounds of 1 through 64
entries and at least 512 bytes; the defaults are four entries and 256 MiB.
Least-recently-used entries are evicted until both bounds are satisfied, and a
single prepared scene larger than the byte budget is rejected. The byte count
covers allocated prepared mesh/image buffer capacities and logical RGBA8
texture bytes. Direct streaming buffers,
the render target and readback storage are separate and are not included in
that prepared-cache budget. They are included in the separate managed-resource
budget together with prepared and direct-stream buffers. Its default is
512 MiB and `managedGpuByteBudget` must contain the configured prepared-cache
budget. Growth evicts unprotected least-recently-used prepared entries first,
then fails before allocation if the bound still cannot hold. Diagnostics expose
each component, the current sum and its high-water mark. Texture accounting is
the logical RGBA8 payload requested by UniPlot; driver metadata, alignment and
internal allocations are not observable and are not claimed.
Queue uploads are split into aligned writes of at most 4 MiB by default.
`uploadChunkBytes` configures a multiple of four bytes from 4 bytes through
64 MiB; diagnostics expose the call count, transferred bytes and largest
write. This bounds each native queue write; it is independent of the managed
resource-capacity budget.
Direct `submitWgpuMeshTarget` uploads rotate through three streaming slots by
default (configurable from one through eight). Each slot retains the exact
submission index returned by wgpu-native and is reused only after
`wgpuDevicePoll` has synchronized that submission. Readback completion and
`waitWgpuIdle` release completed slots explicitly. Ring capacity is included
in the managed byte budget, and diagnostics distinguish selections from
synchronization calls; they do not infer how long a fence blocked.
`renderWgpuPrepared` returns unpadded RGBA8 pixels. Convenience scene overloads
use the automatic host cache and then the GPU-residency cache. Diagnostics keep
their hits, misses, evictions and byte counters distinct. `nimble wgpuBenchmark`
measures identity construction, host-cache lookup, automatic submission,
explicit preparation, forced GPU LRU misses, resident submission and
publication separately.

Each `WgpuBackend` belongs to the thread that opened it. All backend operations,
including diagnostics, cache purge and close, must run on that thread; debug
contracts reject violations and release builds raise `WgpuError`. Renderer-free
scene construction and `prepareWgpuScene` do not carry this backend affinity.

## License

Apache-2.0. Contributions require a DCO sign-off.
