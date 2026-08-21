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

Plot recipes filter retained data according to UniPlot policy, then delegate
type-7 quantiles and range-safe means to UniStatistics. Histogram geometry and
box-plot layer construction remain UniPlot responsibilities.

## Continuous scales
"""

nbCode:
  import UniPlot
  import UniGlyph

  let linear = continuousScale(0.0, 100.0, 70'f32, 670'f32)
  let logarithmic = continuousScale(1.0, 1000.0, 0'f32, 1'f32, skLog10)
  let symmetric = continuousScale(-99.0, 99.0, 0'f32, 1'f32, skSymLog10)
  let trained = trainContinuous([4.0, NaN, 8.0, 15.0], 0'f32, 300'f32)

  echo "linear 25 -> ", linear.map(25)
  echo "linear ticks -> ", linear.ticks(5)
  echo "log ticks -> ", logarithmic.ticks(4)
  echo "symmetric-log ticks -> ", symmetric.ticks(3)
  echo "trained domain -> ", trained.domainMin, " .. ", trained.domainMax
  echo "scientific label -> ", tickLabel(0.0000123)

nbText: """
`ContinuousScale` maps a finite domain into a float32 range. `skLinear` uses
ordinary interpolation; `skLog10` requires a positive domain and positive
mapped values; `skSymLog10` accepts every finite sign. `trainContinuous`
ignores non-finite samples and pads a constant
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
## UTC date/time and duration axes

Temporal axes keep the data numeric. UTC values are POSIX seconds; durations
are signed elapsed seconds. Tick placement and text are locale-independent,
and the same retained geometry is consumed by CPU, SVG and WGPU.
"""

nbCode:
  var temporal = linePlot(
    [1_704_067_200.0, 1_704_067_260.0, 1_704_067_320.0,
      1_704_067_380.0, 1_704_067_440.0],
    [0.0, 42.0, 75.0, 130.0, 190.0], color = "#2457c5")
  temporal.scaleXUtc()
  temporal.scaleYDuration()
  temporal.labels(title = "UTC observations", x = "UTC", y = "elapsed")
  let temporalSvg = temporal.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(temporalSvg,
  "POSIX seconds and elapsed seconds rendered with deterministic semantic labels.")

nbText: """
`scaleXUtc` / `scaleYUtc` format years 0001 through 9999 in UTC and use
calendar-aligned month or year ticks for long spans. `scaleXDuration` /
`scaleYDuration` use a fixed seconds ladder and signed duration labels. Temporal
labels require a linear transform. Calling ordinary `scaleX` or `scaleY`
restores numeric labels. Schema-v1 JSON stores the label kind only when it is
non-numeric.
"""

nbText: """
`scaleX` and `scaleY` select `skLinear`, `skLog10` or `skSymLog10` and
independently reverse the output direction. Logarithmic coordinates reject
non-positive mapped values. Symmetric-logarithmic coordinates use
`sign(x) * log10(1 + abs(x))`, retain zero and label ticks in original units.
`scaleXPower(exponent)` and `scaleYPower(exponent)` add a configurable,
strictly positive signed-power transform `sign(x) * abs(x)^exponent`.
Fractional exponents therefore remain real and monotone across zero. The
exponent participates in shared-axis compatibility and schema-v1 round trips.
Categorical x coordinates remain linear; bars and areas reject a
logarithmic y coordinate because their current semantic baseline is zero.

## Polar coordinates
"""

nbCode:
  import UniMath

  var polarFrame = initDataFrame()
  polarFrame.addColumn("angle", [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0,
    PI, 5.0 * PI / 4.0, 3.0 * PI / 2.0, 7.0 * PI / 4.0, 2.0 * PI])
  polarFrame.addColumn("radius", [1.0, 2.0, 1.4, 2.6, 1.2, 2.2, 1.5, 2.8,
    1.0])
  var polarSpec = plot(polarFrame)
  polarSpec.geomLine(aes("angle", "radius"), color = "#3366cc", width = 2)
  polarSpec.geomPoint(aes("angle", "radius"), color = "#d1495b", radius = 4)
  polarSpec.coordPolar()
  polarSpec.labels(title = "Retained polar projection", x = "angle (rad)",
    y = "radius")
  let polarSvg = polarSpec.compileScene(Size(width: 720, height: 520)).toSvg(
    loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(polarSvg,
  "Radians projected clockwise from twelve o'clock onto retained paths.")

nbText: """
`coordPolar()` fixes the angular contract to `[0, 2*pi]`, trains the radial
domain from zero, and emits eight spokes plus numeric radial rings. Reversing
the x scale reverses angular direction. Point, line and text layers plus text
and arrow annotations are supported in 1.0. Retained rasters, references,
secondary axes, categorical coordinates and bounded/area-like marks are
rejected explicitly because they do not yet have a defined polar geometry.
`coordCartesian()` restores ordinary projection. The optional coordinate kind
round-trips through schema-v1 JSON; Cartesian documents remain unchanged.

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

## Explicit histogram boundaries
"""

nbCode:
  let explicitBins = histogramBreaks(
    [-1.0, 0.0, 0.3, 0.9, 1.0, 1.4, 2.0, 3.0, NaN],
    [0.0, 0.5, 1.0, 2.0])
  for bin in explicitBins:
    echo "[", bin.lower, ", ", bin.upper, "] -> ", bin.count
  var explicitHistogram = histogramBreaksPlot(
    [-1.0, 0.0, 0.3, 0.9, 1.0, 1.4, 2.0, 3.0, NaN],
    [0.0, 0.5, 1.0, 2.0], color = "#267a5e")
  explicitHistogram.labels(title = "Caller-defined bins", x = "interval",
    y = "count")
  let explicitHistogramSvg = explicitHistogram.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(explicitHistogramSvg,
  "Caller-defined intervals shown as labelled categorical count bars.")

nbText: """
`histogramBreaks(values, breaks)` requires at least two finite, strictly
increasing boundaries. Every interval is lower-inclusive and upper-exclusive,
except the final interval, which includes the last boundary. Non-finite values
and finite values outside the supplied domain are excluded. The function
always returns one bin per adjacent boundary pair, including zero-count bins;
`histogramBreaksPlot` turns that retained result into categorical bars.
Those bars have equal screen width: their labels preserve the numeric
boundaries, but an interval twice as wide does not receive a bar twice as wide
and heights are raw counts rather than width-normalised densities. Numeric
geometry is available through the `histogramPlot(values, breaks, ...)`
overload below; `histogramBreaksPlot` remains useful when interval labels are
the intended categorical axis.

## Numeric histogram geometry and density
"""

nbCode:
  var densityHistogram = histogramPlot(
    [0.0, 0.2, 0.8, 1.0, 1.4, 2.0, 2.4, 3.0],
    [0.0, 0.5, 1.0, 2.0, 3.0], density = true, color = "#d65f2d")
  densityHistogram.labels(title = "Variable-width probability density",
    x = "value", y = "density")
  let densityHistogramSvg = densityHistogram.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(densityHistogramSvg,
  "Numeric rectangle widths follow the supplied intervals; total bar area is one.")

nbText: """
The explicit-break overload of `histogramPlot` uses retained numeric
`geomRect` marks with `xMin`, `xMax`, `yMin` and `yMax` mappings. With
`density = false`, heights are counts. With `density = true`, each height is
`count / (finite in-domain count × interval width)`, so the sum of rectangle
areas is one whenever at least one observation is counted. An empty in-domain
sample produces zero-height rectangles. Interval widths must remain finite;
the ordinary explicit-break validation still requires finite strictly
increasing boundaries.

The automatic overload `histogramPlot(values, rule, ...)` derives equal-width
numeric intervals with square-root, Sturges, Rice, Scott or
Freedman–Diaconis selection. `hrAuto` prefers Freedman–Diaconis and uses a
deterministic fallback when the interquartile range degenerates. Non-finite
samples are excluded consistently from selection and counting; a sample with
no finite value is rejected. The root, logarithm, ceiling and neighbouring
float operations come from UniMath, so the recipe does not depend directly on
`std/math`. Constant samples receive a finite representable interval, and a
density recipe rejects any interval whose normalised height would overflow.

## Grouped aggregation
"""

nbCode:
  let groupNames = ["beta", "alpha", "beta", "empty", "alpha"]
  let groupValues = [1.0, 4.0, 3.0, NaN, 8.0]
  for summary in aggregateGroups(groupNames, groupValues, agMean):
    echo summary.group, ": value=", summary.value,
      " finite count=", summary.count
  var grouped = groupedAggregatePlot(groupNames, groupValues, agMean,
    color = "#9b4d96")
  grouped.labels(title = "Mean by first-seen group", x = "cohort",
    y = "finite-sample mean")
  let groupedSvg = grouped.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(groupedSvg,
  "Compensated means in first-seen group order; the empty group is retained on the axis.")

nbText: """
`aggregateGroups(groups, values, aggregation)` supports `agCount`, `agSum`,
`agMean`, `agMinimum` and `agMaximum`. Inputs must have equal non-zero lengths
and group names cannot be empty. Groups retain first-seen order. Non-finite
values do not contribute; `count` records the number of finite observations.
An entirely non-finite group is still returned: its aggregate is `NaN`, except
for `agCount`, whose value is zero. This preserves the categorical domain while
the ordinary mark filtering omits a non-finite bar.

Sums and means delegate their compensated arithmetic to UniAccurate.
`groupedAggregatePlot` materialises the result as an ordinary categorical bar
specification, so it uses the same retained scene, serialization and rendering
pipeline as caller-built bars.

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

## Numeric heatmap grids
"""

nbCode:
  var numericHeat = numericHeatmapPlot(
    [0.0, 1.0, 3.0, 6.0], [10.0, 20.0, 40.0],
    [1.0, 4.0, 2.0, 6.0, NaN, 9.0], legend = "response")
  numericHeat.labels(title = "Variable-size numeric cells", x = "distance",
    y = "frequency")
  let numericHeatSvg = numericHeat.compileScene(
    Size(width: 720, height: 420)).toSvg(
      loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(numericHeatSvg,
  "Explicit numeric boundaries preserve unequal cell widths and heights.")

nbText: """
`numericHeatmapPlot(xBreaks, yBreaks, values)` consumes values in row-major
order: all x cells of the first y interval, then the next y interval. Each
boundary vector is finite and strictly increasing, every interval width must
remain finite, and the value count is exactly
`(xBreaks.len - 1) × (yBreaks.len - 1)`. A non-finite cell value is retained in
the frame but omitted by the mark's missing-value policy. At least one finite
cell is needed to train the default continuous colour guide.

The recipe produces ordinary numeric `geomRect` paths and a continuous
UniColor guide. It is a vector-cell heatmap, not an image sampler. Generic
retained rasters and data-mapped image marks are documented in the grammar
chapter.

## Dense raster heatmaps
"""

nbCode:
  var denseValues = newSeq[float64](48 * 32)
  for row in 0 ..< 32:
    for column in 0 ..< 48:
      let dx = float64(column) - 23.5
      let dy = float64(row) - 15.5
      denseValues[row * 48 + column] = dx * dx + dy * dy
  var denseHeat = rasterHeatmapPlot(48, 32, denseValues,
    0.0, 48.0, 0.0, 32.0)
  denseHeat.labels(title = "Dense UniColor raster", x = "column", y = "row")
  let denseHeatSvg = denseHeat.compileScene(Size(width: 720,
      height: 420)).toSvg(
    loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(denseHeatSvg,
  "A 48 × 32 scalar matrix retained as one palette-mapped RGBA8 image.")

nbText: """
`rasterHeatmapPlot(width, height, values, xMin, xMax, yMin, yMax)` maps a
row-major scalar matrix through the default ordered UniColor palette. The
finite minimum and maximum define the colour domain; a constant matrix samples
its midpoint. Non-finite cells become transparent and an entirely non-finite
matrix is rejected. Row zero is the top image row and corresponds to `yMax`.
UniColor prepares the 256-entry RGBA8 lookup table once per construction;
pixels then perform only range-safe normalization and table lookup.

Unlike `numericHeatmapPlot`, this recipe emits one owned raster instead of one
UniVector rectangle per cell. Nearest-neighbour filtering is the default for
cell boundaries, with the existing bilinear and box filters available. The
current raster recipe intentionally has no automatic colour-bar guide.

## Rectilinear contours
"""

nbCode:
  let contourValues = [0.0, 1.0, 2.0, 1.0, 2.0, 3.0, 2.0, 3.0, 4.0]
  var contours = contourPlot([0.0, 1.0, 2.0], [0.0, 1.0, 2.0],
    contourValues, [1.0, 2.0, 3.0], width = 2)
  contours.labels(title = "Rectilinear marching squares", x = "x", y = "y")
  let contourSvg = contours.compileScene(Size(width: 720, height: 420)).toSvg(
    loadTtf("../../tests/DejaVuSans.ttf"))

nbRawHtml svgFigure(contourSvg,
  "Three contour levels extracted once and shared by every backend.")

nbText: """
`contourSegments(xs, ys, values, levels)` accepts finite, strictly increasing
rectilinear coordinates and a row-major scalar grid. It skips a cell if any of
its four samples is non-finite. Ambiguous saddle cells use their finite centre
value as a deterministic asymptotic decider. Levels are also finite and
strictly increasing.

`contourPlot` materialises every extracted segment as a retained `geomLine`
path separated by explicit missing rows. The CPU, SVG, PNG and WGPU backends
therefore consume identical contour geometry; no backend reruns the statistic.
The current recipe uses one line style for all requested levels. Filled
contours remain outside the 1.0 contract.

Next: [Scenes and rendering](scene_rendering.html).
"""

nbSave
validatePage("scales_stats.html", minSvg = 11)
