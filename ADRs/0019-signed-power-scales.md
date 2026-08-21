# ADR-0019: Signed power scales

## Status

Accepted for UniPlot 1.0.0.

## Decision

Configurable power coordinates use the monotone signed transform
`sign(x) * abs(x)^exponent` with a finite exponent strictly greater than zero.
The inverse uses exponent `1 / exponent`. This definition admits negative,
zero and positive numeric domains without the complex-valued ambiguity of a
plain fractional power.

The exponent belongs to the axis specification, participates in equality,
composition and schema-v1 serialization, and is copied into trained continuous
scales. C and Python expose dedicated power-axis setters rather than changing
the existing scale-kind setter ABI.

## Consequences

All guide, mark and backend code continues to consume mapped Cartesian
coordinates. Ticks are equally spaced in transformed space and labelled in
data space. Exponent one is equivalent to a linear mapping, exponent below one
expands values near zero, and exponent above one compresses them. Polar
coordinates remain a separate coordinate-system decision.
