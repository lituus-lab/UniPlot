# ADR-0014: Kernel density plots

## Status

Accepted for UniPlot 1.0.0.

## Decision

UniPlot delegates Gaussian kernel density estimation and default bandwidth
selection to UniStatistics. The plotting recipe filters non-finite samples,
requests a deterministic grid, and materialises the result as an area followed
by a line. Explicit bandwidth zero selects UniStatistics' automatic rule.

## Consequences

The density curve follows the same retained-scene path on CPU, SVG and WGPU.
UniPlot owns no kernel, bandwidth, or accumulation implementation. Future
violin plots may reuse the same estimate and mirror its density coordinates.
