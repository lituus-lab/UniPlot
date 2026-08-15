# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Scales and statistics

High-level plots train scales automatically. The public low-level API supports
custom guides, adapters and inspection.

## Continuous scales
"""

nbCode:
  import std/math
  import UniPlot

  let linear = continuousScale(0.0, 100.0, 70'f32, 670'f32)
  let logarithmic = continuousScale(1.0, 1000.0, 0'f32, 1'f32, skLog10)
  let trained = trainContinuous([4.0, NaN, 8.0, 15.0], 0'f32, 300'f32)

  echo "linear 25 -> ", linear.map(25)
  echo "linear ticks -> ", linear.ticks(5)
  echo "log ticks -> ", logarithmic.ticks(4)
  echo "trained domain -> ", trained.domainMin, " .. ", trained.domainMax
  echo "scientific label -> ", tickLabel(0.0000123)

nbText: """
`ContinuousScale` maps a finite domain into a float32 range. `skLinear` uses
ordinary interpolation; `skLog10` requires a positive domain and positive
mapped values. `trainContinuous` ignores non-finite samples and pads a constant
domain. `ticks` requires at least two ticks; `tickLabel` selects compact or
scientific notation.

## Categorical band scales
"""

nbCode:
  let bands = trainBand(["north", "south", "north", "west"],
    0'f32, 600'f32, padding = 0.2)
  echo "domain order -> ", bands.domain
  echo "north centre -> ", bands.map("north")
  echo "bandwidth -> ", bands.bandwidth

nbText: """
`BandScale` deduplicates categories in first-seen order, assigns each category a
centre position, and exposes a bandwidth. Padding belongs to `[0, 1)`.

## Histogram statistic

`histogram` filters non-finite values, produces equal-width bins and includes
the maximum in the final bin. It returns data; `histogramPlot` turns those bins
into a ready-to-compile bar specification.
"""

nbCode:
  let bins = histogram([0.0, 0.2, 0.8, 1.0, NaN], binCount = 2)
  var total = 0
  for index, bin in bins:
    total += bin.count
    echo "bin ", index, ": [", tickLabel(bin.lower), ", ",
      tickLabel(bin.upper), "] count=", bin.count
  echo "finite samples counted: ", total

nbText: """
An empty finite input returns no bins. A constant input expands to a unit-width
domain. A non-positive bin count raises `PlotError`; the contractual postcondition
ensures a non-empty result has exactly the requested number of bins.

Next: [Scenes and rendering](scene_rendering.html).
"""

nbSave
validatePage("scales_stats.html")
