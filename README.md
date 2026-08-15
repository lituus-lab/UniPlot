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
- an optional backend boundary for WGPU, with no GPU dependency in the core.

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

UniPlot 1.0 has no benchmark suite: rendering performance is dominated by the
lower UniGlyph, UniVector and UniImage engines, while this repository currently
prioritises deterministic semantic output and cross-backend equivalence. Any
future performance claim will be backed by a reproducible, machine-tagged run.

## Build

```bash
nimble install -y
nimble test
nimble testRelease
nimble testAll
nimble example
nimble ctest
nimble pyTest
nimble book
nimble docs
```

## GPU boundary

The core contains renderer-neutral resource identifiers, meshes, paths, text
runs and clip nodes. An optional WGPU backend may translate those resources to
`wgpu-native`, but importing `UniPlot` never loads or links WGPU. CPU rendering
is the reference semantics and remains available on every supported platform.

## License

Apache-2.0. Contributions require a DCO sign-off.
