# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPlot

suite "statistics":
  test "histogram counts every finite sample":
    let bins = histogram([0.0, 0.2, 0.8, 1.0], 2)
    check bins.len == 2
    check bins[0].count + bins[1].count == 4

  test "histogram recipe produces one bar per bin":
    let spec = histogramPlot([0.0, 0.2, 0.8, 1.0], 2)
    check spec.layers.len == 1
    check spec.data.rowCount == 2

  test "histograms reject invalid bin counts and ignore non-finite input":
    expect PlotError: discard histogram([1.0], 0)
    check histogram([NaN, Inf], 3).len == 0
