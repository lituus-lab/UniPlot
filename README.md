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
- linear, logarithmic and categorical scales;
- CSS colour styling through UniColor;
- line, point, bar, area and text layers, plus histogram recipes;
- Cartesian axes, ticks, labels, titles and themes;
- an inspectable retained scene shared by SVG and raster rendering;
- deterministic SVG and PNG export;
- value-oriented plot specifications and deterministic scene compilation;
- a `uniplot` CLI, C ABI and Python binding;
- an optional native WGPU backend for offscreen scene rendering and readback,
  with no GPU dependency in the core.

## Architecture

```text
data -> mappings -> statistics -> scales -> guides -> scene -> backend
                                                     |-> SVG
                                                     |-> raster/PNG
                                                     `-> optional WGPU
```

The dependency direction is fixed:

```text
common < data < scales < stats < grammar < scene < guides < render < c_api
```

Backends consume the scene. They never participate in scale training, layout or
statistics. This keeps CPU and future GPU output semantically equivalent.

## 1.0 contract

The stable unit is a renderer-neutral plot specification plus its compiled
scene. Equal specifications, dimensions and font inputs produce equal scene
ordering and deterministic vector output. Errors are typed; invalid dimensions,
non-finite layout parameters and incompatible mappings are rejected rather than
silently repaired.

UniPlot 1.0 does not promise a complete clone of any single plotting library,
facets, statistical smoothing, date-aware ticks, 3D scenes, volume rendering,
arbitrary shader injection, a GUI event loop, or a bundled WGPU runtime.
Interactivity, picking, observables and streaming use explicit extension points
and may grow without changing the CPU scene contract.

## The Uni* family

UniPlot depends only on lower-level engines: UniMath, UniLinalg, UniColor,
UniImage, UniVector and UniGlyph. Domain libraries such as UniGeom and UniGraph
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

`renderWgpuScene` compiles retained paths and UniGlyph text through UniVector,
uploads indexed meshes, submits a WGSL render pass and returns unpadded RGBA8
pixels. `nimble wgpuBenchmark` measures that complete warm-frame path.

## License

Apache-2.0. Contributions require a DCO sign-off.
