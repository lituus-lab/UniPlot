# ADR-0015: Violin density geometry

## Status

Accepted for UniPlot 1.0.0.

## Decision

UniPlot builds violin geometry from UniStatistics Gaussian kernel-density
estimates. The recipe normalises the estimated density to a requested visual
width, mirrors it around zero, and materialises the ordered boundary as a
retained polygon. UniPlot does not implement a second kernel or bandwidth
selector.

`mkPolygon` is appended to `MarkKind`, preserving the ordinals of all existing
marks and the version-1 JSON representation. Polygon segments contain at least
three finite vertices and do not accept per-row aesthetics: one segment is one
filled semantic shape.

## Consequences

CPU, SVG and WGPU consume the same closed UniVector path. The single-sample
recipe represents its observations on the y axis and a unitless symmetric
width on the x axis. The grouped overload retains first-seen categories and
uses the additive `Aes.xOffset` mapping. Offsets are numeric fractions of
categorical band width, so grouped polygons remain data coordinates rather
than backend-specific pixel placement.
