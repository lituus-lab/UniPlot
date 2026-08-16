<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0008: Canonical WGPU scene identity and host preparation cache

- Status: Accepted
- Date: 2026-08-16
- Scope: optional WGPU renderer

## Context

Explicit `WgpuPreparedScene` handles avoid repeated shaping and tessellation,
but the scene convenience functions previously rebuilt on every call. Pointer
identity cannot detect an independently reconstructed equivalent scene, and
font paths, names and metrics do not identify exact outline content.

## Decision

UniPlot streams a versioned canonical binary representation directly into
UniCrypto BLAKE3 and uses all 256 result bits as `WgpuSceneIdentity`. It includes
target size, background, ordered node kinds and colours, every typed path
command and parameter, text bytes, position, size and anchor. If any text node
exists it also includes UniGlyph's identity of the exact source font bytes.
Path-only scenes intentionally remain independent of the unused font.

Node IDs and `Path.start`/`Path.at` builder cursors are excluded: preparation
does not consume them. Floats are encoded by their exact IEEE-754 binary32 bits,
integers use fixed-width little-endian encoding, strings are length-prefixed,
and command, scene-node and text-anchor codes are explicit rather than enum
ordinals. The domain prefix is
`lituus-lab/UniPlot/wgpu-scene/v1`; a representation change requires a new
version.

Each `WgpuBackend` owns a separate count- and byte-bounded LRU mapping that key
to immutable host `WgpuPreparedScene` values. The default is 16 entries and
256 MiB. The byte budget counts retained vertex and index logical payload; it
does not claim sequence capacity, allocator metadata, object headers or total
RSS. A value larger than the budget is returned for the current operation but
not retained. Explicit purge releases entries while lifetime counters remain.

This host cache is distinct from native GPU residency. A host hit preserves the
prepared upload token and can therefore hit the GPU cache too. Host eviction
does not force immediate GPU eviction, and reconstructing later receives a new
process-local upload token.

A backend is confined to the thread that opened it. This includes native
runtime access and mutable host-cache state, diagnostics, purge, waiting and
close. Debug contracts state the affinity and release guards raise `WgpuError`
instead of permitting a data race. Backend-independent scene construction and
preparation may still be organised by callers on other threads before the
result is handed to the owner thread.

## Consequences

Convenience rendering pays an O(scene encoding) BLAKE3 pass on every call but
avoids O(shaping plus tessellation) work on a hit. Explicit prepared handles
remain the lowest-overhead path for callers that already track mutation.
BLAKE3 collision resistance is appropriate for cache identity but is not an
authenticity or provenance claim. Tests cover equivalent reconstruction,
metadata exclusion, path/text/font mutation, LRU pressure, oversized entries,
purge and real Metal upload counts; benchmarks report hashing separately.
