<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0001: UniPlot DAG and anti-cycle invariants

- Status: Accepted
- Date: 2026-08-15
- Scope: UniPlot and its adapters

## Decision

UniPlot consumes only lower-level engines: UniMath, UniLinalg, UniColor,
UniImage, UniVector, UniGlyph and UniCrypto. It imports no domain engine.
Adapters for UniGeom, UniGraph, UniMusic or application data live with those
consumers.

## Internal order

```text
common < data < scales < stats < grammar < scene < guides < render < c_api
```

A module may import its own layer or a lower layer. Backends live at `render`;
they cannot train scales, run statistics or mutate plot specifications.

## Invariants

1. No library depends on an application.
2. No UniPlot core module imports a domain engine.
3. UniGlyph owns font parsing, shaping and text layout.
4. UniVector owns vector paths and CPU rasterisation.
5. UniImage owns pixel storage and image encoding.
6. WGPU is optional runtime infrastructure and never a core dependency.
7. UniCrypto owns stable digests; UniPlot does not implement hashing.
