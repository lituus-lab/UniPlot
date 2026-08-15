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

The repository provides a pure-Nim installer for the pinned 29.0.1.1 release.
The native test dynamically loads that runtime and must create an adapter,
device and queue. Downloaded binaries remain outside the package in `.deps`.

## Current scope and deferred work

The backend freezes its runtime boundary against wgpu-native 29.0.1.1 and does
not bundle native binaries. It currently opens the first available adapter and
owns a real device and queue. Scene drawing, explicit adapter selection, window
surfaces, asynchronous device loss and shader packaging remain separate
milestones. Additional raw declarations must continue to match the pinned
release's `ffi/webgpu-headers/webgpu.h` and `ffi/wgpu.h` exactly.
