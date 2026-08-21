# ADR-0018: Dense raster heatmaps

## Status

Accepted for UniPlot 1.0.0.

## Decision

UniPlot may turn a finite-sized row-major float64 matrix into one retained
RGBA8 raster before scene compilation. The recipe accepts explicit numeric
data extents, derives its finite value domain once, and prepares a 256-entry
RGBA8 lookup table from UniPlot's ordered UniColor palette. Every finite cell
indexes that table after range-safe normalization. This matches the published
8-bit raster contract without repeating perceptual gamut mapping per pixel. A
non-finite value becomes a fully transparent pixel. A constant finite matrix
samples the palette midpoint.

Matrix row zero is the top image row and therefore corresponds to the maximum
y extent, matching the retained-raster convention. The generated image is
owned by the PlotSpec and uses the existing raster filter and CPU/SVG/WGPU
paths. Backends never receive scalar values and never implement colour-scale
logic.

## Consequences

Dense heatmaps avoid one vector path per cell and preserve a single colour and
ownership implementation across bindings. Version 1 requires at least one
finite value and exact `width * height` storage with overflow-safe validation.
It does not add a colour-bar guide for raster payloads, resample irregular
cells, or infer spatial coordinates from the scalar matrix.
