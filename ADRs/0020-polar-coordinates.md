# ADR-0020: Polar coordinates are an explicit retained projection

## Status

Accepted for UniPlot 1.0.0.

## Context

Treating polar coordinates as a backend effect would give CPU, SVG and WGPU
different geometry and would make serialization ambiguous.  Reusing Cartesian
rectangles for bars, rasters or image marks would also silently invent an
undefined polar meaning.

## Decision

`coordPolar` selects an explicit `PolarCoordinates` value in `PlotSpec`.

- Numeric `x` values are angles in radians over the fixed closed domain
  `[0, 2*pi]`.
- Zero radians is at twelve o'clock and positive angles advance clockwise.
- Numeric `y` values are radii.  The trained radial domain always contains
  zero and negative radii are rejected.
- Reversing `x` reverses angular direction.  Reversing `y` reverses the radial
  scale while retaining the same circular geometry.
- Point, line and text marks, plus text and arrow annotations, are projected
  into ordinary retained paths and text nodes before rendering.  CPU, SVG and
  WGPU therefore consume the same scene.
- Polar guides are retained spokes and concentric rings.  Angle labels are
  expressed as multiples of pi; radial labels use the configured numeric
  transform.
- Categorical axes, temporal labels, secondary axes, references, retained
  rasters and area-like or bounded marks are rejected until their polar
  semantics are specified by a later ADR.

The schema remains version 1.  Cartesian coordinates omit the new field, so
existing canonical documents remain byte-for-byte stable.  Polar documents
encode `"coordinates":"PolarCoordinates"`.

## Consequences

Polar support is deliberately smaller than Cartesian support, but every
accepted specification has one documented meaning and backend-independent
geometry.  New polar geometries can be added without changing the coordinate
contract or the public ABI.
