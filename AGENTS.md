<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniPlot

## Purpose

UniPlot is the renderer-neutral scientific visualisation engine of the Uni*
family. CPU output is the reference. GPU support is an optional consumer of the
same scene and must never enter the default import graph.

## Required dependency direction

```text
common < data < scales < stats < grammar < scene < guides < render < c_api
```

Allowed engines are UniMath, UniLinalg, UniColor, UniImage, UniVector,
UniGlyph and UniCrypto. Domain engines are forbidden dependencies.

## Build and gates

```bash
nimble lint
nimble checkVGraph
nimble test
nimble testRelease
nimble testAll
nimble example
nimble ctest
nimble pyTest
nimble coverage
nimble book
nimble docs
```

## Code conventions

- Preserve deterministic layer and node order.
- Reject non-finite public layout inputs.
- Keep statistics in data space and rendering in resolved scene space.
- Do not parse fonts or approximate text metrics; call UniGlyph.
- Do not introduce backend handles into public plot or scene types.
- Keep C header, C implementation and Cython declarations synchronised.
- C entry points use `uplot_` and never let a Nim exception cross the ABI.
- Use concise English comments and SPDX headers.

## Scope discipline

UniPlot owns general plotting semantics. Domain adapters belong to their domain
repositories. WGPU integration is optional and runtime-loaded; headless CPU
builds and imports cannot depend on it.
