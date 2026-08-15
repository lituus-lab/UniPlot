<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0007: Optional WGPU backend

- Status: Accepted
- Date: 2026-08-15
- Scope: interactive and accelerated rendering

## Decision

WGPU support is an optional backend package. The binding targets the stable C
API of `wgpu-native`; handles, descriptors and callbacks are wrapped in Nim and
do not leak into the core plot or scene types.

The backend owns adapters, devices, queues, surfaces, buffers, textures and
pipelines. UniPlot core owns semantic resources and renderer-neutral geometry.
Importing the core, using SVG/PNG, or running headless tests never loads WGPU.

## Validation

CPU and WGPU backends consume the same compiled scene. Parity is evaluated on
node bounds, draw order, picking identifiers and tolerance-based pixels. GPU
availability is a runtime capability, not a condition for constructing plots.

## Deferred work

The 1.0 CPU release freezes the boundary against wgpu-native 29.0.1.1 but does
not bundle it. Raw declarations will be generated from the release's
`ffi/webgpu-headers/webgpu.h` and `ffi/wgpu.h`, rather than maintained by hand.
Adapter selection, window surfaces, asynchronous device loss, shader packaging
and platform distribution are delivered with the interactive/GPU milestone.
