# ADR-0017: Rectilinear contours

## Status

Accepted for UniPlot 1.0.0.

## Decision

UniPlot extracts isolines from caller-owned rectilinear float64 grids with a
deterministic marching-squares transform. Coordinates and levels are finite
and strictly increasing; values are row-major. A cell containing a non-finite
sample is omitted. Ambiguous saddle cells use their finite bilinear centre
value as a fixed asymptotic decision.

Extraction returns data-coordinate segments. The plotting recipe materialises
each segment as an ordinary retained line separated by an explicit missing
row. Contour extraction therefore remains above UniMath/UniAccurate and below
the scene boundary; render backends contain no grid or topology algorithm.

## Consequences

CPU, SVG and WGPU consume identical UniVector line paths. Segment order is
level order, then row-major cell order, with a documented two-segment order for
saddles. Version 1 does not promise stitched paths, filled contours,
unstructured triangulations or interpolation across missing cells.
