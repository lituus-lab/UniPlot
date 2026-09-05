# ADR-0016: Symmetric logarithmic scales

## Status

Accepted for UniPlot 1.0.0.

## Decision

UniPlot adds `skSymLog10` as an additive `ScaleKind`. Its fixed transform is

```text
sign(x) * log10(1 + abs(x))
```

and its inverse is evaluated with `expm1` from UniMath. The fixed unit linear
region avoids another mutable scale parameter in the version-1 PlotSpec while
supporting finite negative, zero and positive data. Tick positions are equally
spaced in transformed coordinates and are labelled in original data units.

The enum member is appended so existing ordinals and JSON documents remain
stable. Temporal labels, categorical axes and raster warping remain restricted
to linear coordinates.

## Consequences

Extreme opposite-sign float64 domains no longer require a positive-only log
workaround. CPU, SVG and WGPU still receive already-mapped retained geometry.
A configurable linear threshold may be introduced only with an additive,
serialized scale parameter and matching binding contracts.
