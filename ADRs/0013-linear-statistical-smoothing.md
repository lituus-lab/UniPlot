# ADR-0013: Linear statistical smoothing

## Status

Accepted for UniPlot 1.0.0.

## Decision

UniPlot materialises linear smoothing as ordinary retained ribbon and line
layers. UniStatistics owns fitting, Student-t critical values, leverage, and
confidence intervals; UniAccurate owns the scale-separated centered norm used
by that fit. UniPlot only filters paired finite rows, selects a deterministic
evaluation grid, and constructs the plotting data.

The public recipe uses a 95% mean-confidence band and 100 grid points by
default. Callers may disable the band, change its level, or change the grid
density. Inputs remain caller-owned and the returned PlotSpec owns snapshots.

## Consequences

CPU, SVG, and WGPU consume the same retained marks. No backend contains a
statistical implementation, and no range-sensitive regression arithmetic is
duplicated in UniPlot.
