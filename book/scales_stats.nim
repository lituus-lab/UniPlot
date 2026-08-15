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
  import UniPlot
  import UniGlyph

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

## Plot-level transformed and reversed axes
"""

nbCode:
  var transformed = linePlot([1.0, 10.0, 100.0, 1000.0],
    [1.0, 4.0, 16.0, 64.0], color = "#7a3db8")
  transformed.geomPoint(aes("x", "y"), color = "#d65f2d", radius = 5)
  transformed.scaleX(skLog10, reversed = true)
  transformed.scaleY(skLog10)
  transformed.labels(title = "Logarithmic x, reversed",
    x = "frequency", y = "power")
  let transformedSvg = transformed.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(transformedSvg,
  "A real scene using a logarithmic, reversed x coordinate and logarithmic y.")

nbText: """
`scaleX` and `scaleY` select `skLinear` or `skLog10` and independently reverse
the output direction. Logarithmic coordinates reject non-positive mapped
values. Categorical x coordinates remain linear; bars and areas reject a
logarithmic y coordinate because their current semantic baseline is zero.

`xLimits(minimum, maximum)` and `yLimits(minimum, maximum)` fix a numeric
domain. Limits are finite and strictly increasing, and must contain all marks,
uncertainty bounds, baselines and reference annotations. UniPlot rejects a
limit that would silently draw outside the panel. Calling `scaleX` or `scaleY`
does not erase an existing limit; `clearXLimits` and `clearYLimits` restore
automatic training. The optional limits round-trip through schema-v1 JSON.

`xCategories(["beta", "alpha", "gamma"])` fixes a categorical x order and
may retain categories absent from a particular panel. It must contain every
observed category and cannot contain duplicates. `clearXCategories` restores
first-seen automatic ordering; the optional order also round-trips through
schema-v1 JSON.

```nim
var bounded = linePlot([1.0, 2.0, 3.0], [4.0, 6.0, 5.0])
bounded.xLimits(0.0, 4.0)
bounded.yLimits(0.0, 8.0)
```

## Secondary y guide

The secondary guide is a bijective affine view of primary y values:
`secondary = primary × scale + offset`. It does not train an independent
domain and cannot be used to align unrelated series visually.
"""

nbCode:
  var temperature = linePlot([0.0, 1.0, 2.0, 3.0],
    [0.0, 10.0, 20.0, 30.0], color = "#267a5e")
  temperature.geomPoint(aes("x", "y"), color = "#d65f2d", radius = 5)
  temperature.labels(title = "One quantity, two units",
    x = "sample", y = "celsius")
  temperature.secondaryY(scale = 1.8, offset = 32.0, label = "fahrenheit")
  let secondarySvg = temperature.compileScene(
    Size(width: 760, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(secondarySvg,
  "Celsius positions with a right-side affine Fahrenheit guide.")

nbText: """
`scale` must be finite and non-zero; `offset` must be finite. A transformed
tick that overflows is rejected. The guide reserves its own right-side width
and coexists with a right legend without overlap. `clearSecondaryY` removes it.
The optional transform round-trips through schema-v1 JSON.

## Retained annotations
"""

nbCode:
  var annotated = linePlot([0.0, 1.0, 2.0, 3.0],
    [1.0, 2.2, 1.7, 3.4], color = "#2457c5")
  annotated.geomPoint(aes("x", "y"), color = "#d64255", radius = 5)
  annotated.labels(title = "Data-coordinate annotations", x = "sample",
    y = "value")
  annotated.annotateText(3.0, 3.4, "maximum", color = "#7a3db8",
    fontSize = 14)
  annotated.annotateArrow(2.25, 2.5, 3.0, 3.4, color = "#7a3db8",
    width = 2, headSize = 9)
  let annotatedSvg = annotated.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(annotatedSvg,
  "Plain text and a UniVector arrow retained in the plot specification.")

nbText: """
`annotateText` and `annotateArrow` use numeric data coordinates, participate
in automatic domain training and render above marks. Font size, shaft width
and arrow-head size are screen-space values, so zooming the data domain does
not make them unreadable. Arrow geometry is built by UniVector and text is
shaped by UniGlyph; the same scene nodes feed CPU, SVG, PNG and WGPU rendering.

Annotations currently require numeric x coordinates. They repeat in every
observed facet because they belong to the retained plot rather than to one
panel. `clearAnnotations` removes all of them. Schema-v1 JSON preserves their
order and complete style.

This API deliberately supports plain text only. Multi-style text runs remain
blocked on a run-level styling primitive in UniGlyph; UniPlot does not create
a competing rich-text model.

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

## Quantiles and descriptive summaries

`quantile(values, probability)` filters non-finite observations and uses the
Hyndman–Fan type-7 interpolation also used by the default quantiles in R and
NumPy. The probability belongs to `[0, 1]`; an all-non-finite sample is an
error rather than an invented statistic.
"""

nbCode:
  let sampleSummary = summarize([1.0, 2.0, 2.0, 3.0, 4.0, 100.0, NaN])
  echo "quartiles: ", sampleSummary.firstQuartile, ", ",
    sampleSummary.median, ", ", sampleSummary.thirdQuartile
  echo "whiskers: ", sampleSummary.lowerWhisker, " .. ",
    sampleSummary.upperWhisker
  echo "outliers: ", sampleSummary.outliers

nbText: """
`summarize` returns count, extrema, quartiles, mean, Tukey whiskers and retained
outliers. Its whisker multiplier defaults to `1.5` and must be finite and
non-negative. The mean normalizes the sample and delegates compensated
summation to UniAccurate, avoiding a local numerical kernel and preventing
avoidable overflow for large finite values. This value object is the shared
statistical basis for boxplots; rendering code does not recompute quartiles.

## Grouped boxplots
"""

nbCode:
  let boxGroups = ["control", "control", "control", "control", "control",
    "treated", "treated", "treated", "treated", "treated"]
  let boxValues = [1.0, 1.4, 1.8, 2.1, 5.2,
    2.0, 2.4, 2.7, 3.0, 3.3]
  var boxes = boxPlot(boxGroups, boxValues, color = "#267a5e",
    outlierColor = "#d64255")
  boxes.labels(title = "Grouped distribution", x = "cohort", y = "response")
  let boxesSvg = boxes.compileScene(Size(width: 720, height: 420)).toSvg(
    loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(boxesSvg,
  "Type-7 quartiles, Tukey whiskers and an explicitly retained outlier.")

nbText: """
`boxPlot(groups, values)` preserves first-seen group order, ignores non-finite
observations within a group and rejects a group with no finite sample. It
materialises one validated summary row per group plus separate outlier rows.
The `mkBoxPlot` renderer only consumes those precomputed columns; it verifies
`lower whisker ≤ Q1 ≤ median ≤ Q3 ≤ upper whisker` and never hides a second
statistical implementation. Boxes and outliers become ordinary retained
UniVector scene paths, so CPU, SVG, PNG and WGPU share the same geometry.

`geomBoxPlot` is also public for callers that already own summary columns.
Its `boxWidth` is a fraction in `(0, 1]` of the categorical band (or the
available numeric slot), while its outline width is in screen pixels.

## Categorical heatmaps and two-dimensional aggregation
"""

nbCode:
  let heatX = ["morning", "morning", "afternoon", "evening", "evening"]
  let heatY = ["north", "north", "north", "north", "south"]
  let heatValues = [2.0, 4.0, 7.0, 5.0, 9.0]
  let cells = aggregate2D(heatX, heatY, heatValues, agMean)
  for cell in cells:
    echo cell.x, " / ", cell.y, ": ", cell.value, " (n=", cell.count, ")"

  var heat = heatmapPlot(heatX, heatY, heatValues, agMean,
    legend = "mean response")
  heat.labels(title = "Categorical response matrix", x = "period",
    y = "region")
  let heatSvg = heat.compileScene(Size(width: 720, height: 420)).toSvg(
    loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(heatSvg,
  "Repeated observations are averaged; an unobserved pair remains empty.")

nbText: """
`aggregate2D` supports `agCount`, `agSum`, `agMean`, `agMinimum` and
`agMaximum`. It filters non-finite observations, preserves first-seen x and y
order, and returns the complete Cartesian matrix. An unobserved pair has
`count == 0` and `value == NaN`; count aggregation instead represents an
observed pair containing only missing values as zero. Sum and mean delegate
compensated accumulation to UniAccurate.

`heatmapPlot` builds a categorical x/y tile layer from this matrix and maps its
finite values to a continuous colour guide. Missing cells are retained in the
axis domains but have no painted tile. Both categorical axes can be fixed with
`xCategories` and `yCategories`; `clearXCategories` and `clearYCategories`
restore first-seen order. Tile rectangles are UniVector paths shared by CPU,
SVG, PNG and WGPU rendering.

This is deliberately a categorical heatmap. Numeric raster grids, image
sampling and contour estimation remain separate roadmap items rather than
being approximated through categorical labels.

Next: [Scenes and rendering](scene_rendering.html).
"""

nbSave
validatePage("scales_stats.html", minSvg = 5)
