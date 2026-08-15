# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Recipes and layered grammar

UniPlot offers two construction styles backed by one engine. Recipes provide a
concise procedural entry point; the grammar composes mappings and layers in a
ggplot2-like workflow. Both return the same `PlotSpec` type.

## Concise recipes
"""

nbCode:
  import UniPlot
  import UniGlyph
  import UniColor

  let font = loadTtf("../../tests/DejaVuSans.ttf")

  var recipeLine = linePlot([0.0, 1.0, 2.0, 3.0],
    [0.5, 2.0, 1.4, 3.2], color = "#3366cc")
  recipeLine.labels(title = "linePlot", x = "x", y = "y")

  var recipeScatter = scatterPlot([0.0, 1.0, 2.0, 3.0],
    [2.7, 1.3, 3.1, 2.2], color = "#d1495b")
  recipeScatter.labels(title = "scatterPlot", x = "x", y = "y")

  var recipeBars = barPlot(["A", "B", "C", "D"],
    [2.0, 5.0, 3.0, 4.0], color = "#2a9d8f")
  recipeBars.labels(title = "barPlot", x = "category", y = "value")

  var recipeHistogram = histogramPlot([
    0.2, 0.3, 0.4, 0.8, 1.0, 1.1, 1.2, 1.4,
    1.7, 1.8, 2.0, 2.1, 2.4, 2.8, 3.0, 3.2
  ], binCount = 6, color = "#8e63ce")
  recipeHistogram.labels(title = "histogramPlot", x = "range", y = "count")

  let recipeSvgs = [
    recipeLine.compileScene(Size(width: 500, height: 320)).toSvg(font),
    recipeScatter.compileScene(Size(width: 500, height: 320)).toSvg(font),
    recipeBars.compileScene(Size(width: 500, height: 320)).toSvg(font),
    recipeHistogram.compileScene(Size(width: 500, height: 320)).toSvg(font)
  ]

nbRawHtml gallery([
  svgFigure(recipeSvgs[0], "Numeric line recipe."),
  svgFigure(recipeSvgs[1], "Numeric scatter recipe."),
  svgFigure(recipeSvgs[2], "Categorical bar recipe."),
  svgFigure(recipeSvgs[3], "Histogram statistic and bar geometry.")
])

nbText: """
Recipes are not a separate rendering path. Their result can be labelled,
themed or extended with additional layers.

## Core geometries

`aes(x, y, label)` maps columns. `geomLine`, `geomPoint`, `geomBar`, `geomArea`
and `geomText` append typed layers. Multiple layers share trained scales,
guides and deterministic scene order.
"""

nbCode:
  var series = initDataFrame()
  series.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
  series.addColumn("y", [1.0, 2.8, 2.1, 4.2, 3.7, 5.1])
  series.addColumn("label", ["A", "B", "C", "D", "E", "F"])

  var layered = plot(series)
  layered.geomArea(aes("x", "y"), color = "#dbe7ff")
  layered.geomLine(aes("x", "y"), color = "#3366cc", width = 3)
  layered.geomPoint(aes("x", "y"), color = "#cc3344", radius = 5)
  layered.geomText(aes("x", "y", "label"), color = "#202124", size = 13)
  layered.labels(title = "Area, line, point and text", x = "time", y = "value")
  let layeredSvg = layered.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(layeredSvg,
  "Four geometries share numeric scales; geomBar appears in the recipe gallery.")

nbText: """
Layer order is rendering order. A zero line width or point radius selects the
theme default; an explicit positive value overrides it for that layer. Text
requires the mapped label column to be categorical.

## Reference lines and bands

References live in data coordinates and participate in scale training. They
therefore remain correct under logarithmic or reversed axes and may extend a
domain when they lie outside the observed samples.
"""

nbCode:
  var referenced = linePlot([0.0, 1.0, 2.0, 3.0, 4.0, 5.0],
    [1.0, 2.8, 2.1, 4.2, 3.7, 5.1], color = "#2457c5")
  referenced.geomPoint(aes("x", "y"), color = "#d64255", radius = 5)
  referenced.referenceX(3.0, color = "#7a3db8", width = 2,
    label = "intervention")
  referenced.referenceY(4.0, color = "#267a5e", label = "threshold")
  referenced.referenceXBand(1.0, 2.0, color = "#d9e2f380",
    label = "window")
  referenced.referenceYBand(2.4, 3.2, color = "#f4c95d60")
  referenced.labels(title = "References in data coordinates", x = "time",
    y = "value")
  let referencedSvg = referenced.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(referencedSvg,
  "Reference bands are behind the data; labels and lines use the same trained scales.")

nbText: """
`referenceX`, `referenceY`, `referenceXBand` and `referenceYBand` require
finite coordinates. Bands require positive extent. X references require a
numeric x coordinate, and logarithmic-axis references must be positive. The
compiler revalidates public `Reference` values even when callers construct
them directly instead of using these contractual helpers.

## Error bars and ribbons

Uncertainty layers map an x coordinate plus explicit `yMin` and `yMax`
columns. They do not require a synthetic centre column: a ribbon fills the
envelope, while error bars draw one vertical interval and two optional caps
per finite row.
"""

nbCode:
  var uncertaintyData = initDataFrame()
  uncertaintyData.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
  uncertaintyData.addColumn("estimate", [1.5, 2.1, 2.7, 3.0, 3.7, 4.2])
  uncertaintyData.addColumn("lower", [0.9, 1.5, 2.0, 2.2, 2.8, 3.3])
  uncertaintyData.addColumn("upper", [2.1, 2.8, 3.5, 3.9, 4.5, 5.0])

  var uncertainty = plot(uncertaintyData)
  let interval = aes("x", "", yMin = "lower", yMax = "upper")
  uncertainty.geomRibbon(interval, color = "#4f7bd955")
  uncertainty.geomErrorBar(interval, color = "#234a99", width = 1.5,
    capWidth = 10)
  uncertainty.geomLine(aes("x", "estimate"), color = "#c23b4a", width = 3)
  uncertainty.geomPoint(aes("x", "estimate"), color = "#c23b4a", radius = 4)
  uncertainty.labels(title = "Estimate and uncertainty", x = "sample",
    y = "value")
  let uncertaintySvg = uncertainty.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(uncertaintySvg,
  "The ribbon, capped intervals, centre line and samples share trained scales.")

nbText: """
Bounds must be numeric and finite after applying the layer's missing-value
policy, and each lower value must not exceed its upper value. Ribbons default
to `BreakOnMissing`, preserving gaps as separate polygons. Error bars default
to `DropMissing`; `capWidth = 0` retains only the vertical stem. Invalid cap
widths are rejected by a contract in debug builds and by `PlotError` in
release builds.

## Legends

A non-empty `legend` argument names a layer. Calling `legend` on the plot
enables a deterministic right-side guide compiled into the same retained scene
as the data marks. `lpNone` disables it explicitly.
"""

nbCode:
  var documented = linePlot([0.0, 1.0, 2.0, 3.0],
    [1.0, 2.5, 2.0, 4.0], color = "#3366cc", legend = "Trend")
  documented.geomPoint(aes("x", "y"), color = "#d1495b", radius = 5,
    legend = "Samples")
  documented.labels(title = "Layer-derived legend", x = "x", y = "y")
  documented.legend(title = "Series")
  let documentedSvg = documented.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(documentedSvg,
  "Line and point swatches are derived from their layer geometry and colour.")

nbText: """
Legend entries are opt-in: unnamed layers never appear accidentally. The guide
reserves layout space before scales are trained, so it cannot cover the data
area. SVG, PNG and WGPU need no legend-specific rendering code.

## Categorical colour mapping

The optional `color` aesthetic names a categorical column. UniPlot preserves
first-occurrence order and indexes an immutable UniColor discrete palette. The
default is UniColor's Okabe–Ito palette; `categoricalPalette` accepts another
discrete `Palette` explicitly.
"""

nbCode:
  var groupedData = initDataFrame()
  groupedData.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
  groupedData.addColumn("y", [1.0, 2.6, 1.8, 3.8, 3.1, 4.7])
  groupedData.addColumn("group", ["control", "treated", "control",
    "treated", "control", "treated"])
  var grouped = plot(groupedData)
  grouped.geomPoint(aes("x", "y", color = "group"), radius = 6)
  grouped.labels(title = "Categorical colour", x = "sample", y = "value")
  grouped.legend(title = "Group")
  let groupedSvg = grouped.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(groupedSvg,
  "Categories share stable UniColor values and generate matching swatches.")

nbText: """
Point, bar, text and line layers support categorical colours. A line segment
uses the category of its ending row. An area is one polygon and therefore
rejects per-row colour mappings instead of silently choosing one colour.

## Continuous colour and fill

A numeric `color` or `fill` mapping trains a continuous scale and samples an
ordered immutable UniColor palette. The default is UniColor's scientific
viridis ramp. `continuousPalette` accepts `palOrdered`, `palScientific` or
`palContinuous`; unordered categorical palettes are rejected. Enabling the
legend derives one color bar per distinct numeric mapping.
"""

nbCode:
  var heatData = initDataFrame()
  heatData.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
  heatData.addColumn("y", [1.0, 2.6, 1.9, 3.7, 3.0, 4.4, 4.0])
  heatData.addColumn("temperature", [12.0, 14.0, 17.0, 21.0, 25.0,
    29.0, 33.0])
  var heat = plot(heatData)
  heat.geomPoint(aes("x", "y", color = "temperature"), radius = 8)
  heat.continuousPalette(viridis(7).get)
  heat.labels(title = "Continuous UniColor mapping", x = "sample", y = "value")
  heat.legend(title = "Measurement")
  let heatSvg = heat.compileScene(Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(heatSvg,
  "Numeric values sample an ordered UniColor ramp and derive one color bar.")

nbText: """
Non-finite colour values participate in the layer's missing-value policy. The
resolved colours and color-bar swatches are ordinary retained scene paths, so
SVG, PNG and WGPU consume identical semantics.

## Fill, shape and line-style mappings

`fill` maps categorical colours specifically for filled point and bar marks.
`shape` maps point categories to UniVector's circle, square, triangle, diamond,
plus and cross paths. A line selects `SolidLine`, `DashedLine`, `DottedLine`,
`DotDashLine` or `LongDashLine`; the non-solid forms are expanded by
UniVector's validated dash engine before any backend sees the scene.
"""

nbCode:
  var styled = plot(groupedData)
  styled.geomLine(aes("x", "y"), color = "#495057", width = 2,
    lineStyle = DotDashLine, legend = "trend")
  styled.geomPoint(aes("x", "y", fill = "group", shape = "group"),
    radius = 7)
  styled.labels(title = "UniVector plot geometry", x = "sample", y = "value")
  styled.legend(title = "Group")
  let styledSvg = styled.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(styledSvg,
  "Fill and shape share one categorical legend; the trend uses a dot-dash stroke.")

nbText: """
First-occurrence order is deterministic. A shape mapping accepts at most the
six distinct UniVector markers, and a line-style mapping at most five styles;
exceeding either visual capacity is a typed error rather than silent recycling.
`color` and `fill` cannot both be mapped on one layer because the current scene
stores one paint per filled path.

## Missing values and intentional gaps

Every layer has an explicit `MissingValuePolicy`. Lines and areas default to
`BreakOnMissing`, so a `NaN` or infinity starts a new subpath instead of
drawing a misleading bridge across absent observations. Points, bars and text
default to `DropMissing`. Pass `DropMissing` to reconnect the remaining line
samples, or `RejectMissing` when incomplete input must be a typed error.
"""

nbCode:
  var gapData = initDataFrame()
  gapData.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0])
  gapData.addColumn("y", [1.0, 2.5, NaN, 2.2, 3.8])

  var broken = plot(gapData)
  broken.geomLine(aes("x", "y"), width = 3)
  broken.geomPoint(aes("x", "y"), radius = 5)
  broken.labels(title = "BreakOnMissing", x = "x", y = "y")

  var reconnected = plot(gapData)
  reconnected.geomLine(aes("x", "y"), width = 3,
    missingValues = DropMissing)
  reconnected.geomPoint(aes("x", "y"), radius = 5)
  reconnected.labels(title = "DropMissing", x = "x", y = "y")

  let missingSvgs = [
    broken.compileScene(Size(width: 500, height: 320)).toSvg(font),
    reconnected.compileScene(Size(width: 500, height: 320)).toSvg(font)
  ]

nbRawHtml gallery([
  svgFigure(missingSvgs[0], "The default retains the observational gap."),
  svgFigure(missingSvgs[1], "DropMissing deliberately reconnects finite rows.")
])

nbText: """
Scale training ignores non-finite values in all three modes. The policy applies
when marks are compiled: `RejectMissing` fails at that boundary, while drop and
break remain deterministic across SVG, PNG and WGPU because the resulting
scene contains the resolved UniVector paths.

## Numeric size and alpha mappings

The `size` and `alpha` aesthetics map numeric columns through the existing
continuous-scale implementation. `sizeRange` and `alphaRange` define explicit
finite output ranges; alpha composes with the immutable UniColor value instead
of mutating it.
"""

nbCode:
  var weightedData = initDataFrame()
  weightedData.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0])
  weightedData.addColumn("y", [1.0, 3.0, 2.0, 4.5, 3.7])
  weightedData.addColumn("weight", [1.0, 3.0, 2.0, 5.0, 4.0])
  weightedData.addColumn("confidence", [0.2, 0.8, 0.4, 1.0, 0.7])
  var weighted = plot(weightedData)
  weighted.geomPoint(aes("x", "y", size = "weight", alpha = "confidence"),
    color = "#7b2cbf")
  weighted.sizeRange(3, 11)
  weighted.alphaRange(0.25, 1)
  weighted.labels(title = "Numeric aesthetics", x = "x", y = "y")
  let weightedSvg = weighted.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(weightedSvg,
  "Point radius and opacity are trained from independent numeric columns.")

nbText: """
Non-finite mapped values remove the corresponding row consistently with x and
y filtering. Lines use the ending row's width and opacity; bars use mapped size
as width; text uses it as font size. Areas reject per-row aesthetics because an
area layer produces one polygon.

## Labels and themes

`labels` sets the title and axis labels. `defaultTheme()` exposes background,
foreground, grid colour, margins, default point size and default line width.
"""

nbCode:
  import UniColor

  var themed = scatterPlot([0.0, 1.0, 2.0, 3.0, 4.0],
    [1.0, 4.0, 2.0, 5.0, 3.0], color = "#ffb703")
  themed.labels(title = "Custom theme", x = "sample", y = "score")
  themed.theme.background = parseColor("#14213d").get
  themed.theme.foreground = parseColor("#f8f9fa").get
  themed.theme.gridColor = parseColor("#415a77").get
  themed.theme.pointSize = 7
  themed.theme.lineWidth = 3
  themed.theme.margins = Insets(left: 80, top: 60, right: 35, bottom: 65)
  let themedSvg = themed.compileScene(Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(themedSvg,
  "Theme controls the plot surface, guides, text, margins and default sizes.")

nbText: """
Colours use UniColor's CSS parser. Invalid colours fail while constructing the
theme or layer. Margins must leave a positive plotting rectangle, and all mark
sizes must be finite and positive at compilation.

Next: [Scales and statistics](scales_stats.html).
"""

nbSave
validatePage("grammar.html", minSvg = 11)
