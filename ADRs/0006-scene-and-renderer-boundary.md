<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0006: Scene and renderer boundary

- Status: Accepted
- Date: 2026-08-15
- Scope: CPU and GPU backends

## Decision

The compiled scene is renderer-neutral and uses ordered paths and positioned
semantic text. A shared lowering step resolves every text node through UniGlyph
with the caller-supplied font before SVG, raster or GPU drawing. Backends never
shape or measure text independently.

SVG serialises scene primitives. The raster backend lowers paths through
UniVector and pixels through UniImage. Backends may cache resources by stable
identifiers but must not change geometry, guide placement or text layout.

## Consequences

- Reference images can compare backends at the scene boundary.
- Export does not require a window system.
- Picking can attach stable node identifiers without coupling the core to an
  event loop.
- PDF can be added as another consumer of the same scene.
