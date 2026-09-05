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
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate lint
build/unigate checkVGraph
build/unigate testAll     # debug + release + C ABI
build/unigate example
build/unigate ctest
build/unigate pyTest
build/unigate coverage
build/unigate docs        # book + API reference into pages/
build/unigate canary      # must fail
```

Never `nimble <task>` bare where the answer matters: nimble 0.22 exits 0 even
when an `exec` inside the task failed. Each task writes its own success marker
on its last line, and the gate is what turns a missing marker into a non-zero
exit -- `nimble canary` exits 0 on a file that cannot compile, `build/unigate
canary` exits 1.

## Code conventions

- Preserve deterministic layer and node order.
- Reject non-finite public layout inputs.
- Keep statistics in data space and rendering in resolved scene space.
- Do not parse fonts or approximate text metrics; call UniGlyph.
- Do not introduce backend handles into public plot or scene types.
- Keep C header, C implementation and Cython declarations synchronised.
- C entry points use `uniplot_` and never let a Nim exception cross the ABI.
- Use concise English comments and SPDX headers.

## Scope discipline

UniPlot owns general plotting semantics. Domain adapters belong to their domain
repositories. WGPU integration is optional and runtime-loaded; headless CPU
builds and imports cannot depend on it.
