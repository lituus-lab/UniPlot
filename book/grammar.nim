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
  import UniImage/core as uimg

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
  ], hrFreedmanDiaconis, color = "#8e63ce")
  recipeHistogram.labels(title = "Freedman–Diaconis", x = "value", y = "count")

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
  svgFigure(recipeSvgs[3],
    "Automatic Freedman–Diaconis selection and numeric rectangle geometry.")
])

nbText: """
Recipes are not a separate rendering path. Their result can be labelled,
themed or extended with additional layers.

Automatic histograms accept `hrSquareRoot`, `hrSturges`, `hrRice`, `hrScott`
and `hrFreedmanDiaconis`; `hrAuto` uses Freedman–Diaconis with a deterministic
Sturges fallback. Non-finite samples are ignored. The resulting numeric
rectangles are ordinary retained marks shared by CPU, SVG and WGPU.

## Core geometries

`aes(x, y, label)` maps columns. `geomLine`, `geomPoint`, `geomBar`, `geomArea`
and `geomText` append typed layers. `geomRect` instead maps explicit numeric
`xMin`, `xMax`, `yMin` and `yMax` bounds; x bounds increase strictly while y
bounds may coincide for a zero-height rectangle. Multiple layers share trained
scales, guides and deterministic scene order.
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
## Retained raster layers

`raster` places a Gray, RGB or straight-alpha RGBA8 `UniImage` in numeric data
coordinates. UniPlot snapshots the pixels, trains both axes on the requested
extent and renders the image behind grid lines and vector marks. `RasterNearest`
preserves pixel cells; `RasterBilinear` and `RasterBox` use UniImage's
alpha-correct premultiplied filtering. The same retained image reaches CPU,
SVG and WGPU renderers. Reversed linear axes mirror the pixels with the data
coordinates. Nonlinear axes are rejected until an explicit raster-warp
primitive is available, avoiding a silently incorrect uniform resize.
"""

nbCode:
  var rasterImage = uimg.newImage[uint8](4, 3, uimg.csRgba)
  for y in 0 ..< rasterImage.height:
    for x in 0 ..< rasterImage.width:
      let offset = (y * rasterImage.width + x) * 4
      rasterImage.data[offset] = uint8(40 + x * 55)
      rasterImage.data[offset + 1] = uint8(45 + y * 75)
      rasterImage.data[offset + 2] = uint8(220 - x * 35)
      rasterImage.data[offset + 3] = uint8(100 + (x + y) * 25)
  var rasterPlot = plot(initDataFrame())
  rasterPlot.raster(rasterImage, 0.0, 4.0, 0.0, 3.0, RasterNearest)
  rasterPlot.labels(title = "Retained RGBA raster", x = "x", y = "y")
  let rasterPng = rasterPlot.compileScene(
    Size(width: 640, height: 400)).encodePng(font)

nbRawHtml pngFigure(pngDataUri(rasterPng),
  "A raster-only PlotSpec rendered to an embedded PNG.",
  "RGBA raster layer rendered by UniPlot")

nbText: """
## Data-mapped image marks

`addImageResource` snapshots a named UniImage once. `geomImage` maps a
categorical resource-name column and numeric `xMin`, `xMax`, `yMin`, `yMax`
columns, so each retained image participates in ordinary layer and row order.
The registry is insertion ordered, names are unique, and missing names are
typed errors. Linear reversed axes mirror the image; nonlinear axes are
rejected until an explicit warp contract exists.
"""

nbCode:
  var imageData = initDataFrame()
  imageData.addColumn("left", [0.0, 2.2])
  imageData.addColumn("right", [1.8, 4.0])
  imageData.addColumn("bottom", [0.0, 0.5])
  imageData.addColumn("top", [1.8, 2.3])
  imageData.addColumn("resource", ["warm", "cool"])
  var warm = uimg.newImage[uint8](2, 2, uimg.csRgba)
  warm.data = @[245'u8, 100, 70, 255, 255, 190, 70, 220,
    190, 45, 80, 220, 255, 235, 150, 255]
  var cool = uimg.newImage[uint8](2, 2, uimg.csRgba)
  cool.data = @[45'u8, 120, 220, 255, 85, 210, 220, 220,
    35, 65, 155, 220, 170, 235, 245, 255]
  var imageMarks = plot(imageData)
  imageMarks.addImageResource("warm", warm)
  imageMarks.addImageResource("cool", cool)
  imageMarks.geomImage(aes("", "", xMin = "left", xMax = "right",
    yMin = "bottom", yMax = "top", image = "resource"), RasterNearest)
  imageMarks.labels(title = "Data-mapped image resources", x = "x", y = "y")
  let imageMarkPng = imageMarks.compileScene(
    Size(width: 720, height: 420)).encodePng(font)

nbRawHtml pngFigure(pngDataUri(imageMarkPng),
  "Two named resources resolved from categorical row data.",
  "Data-mapped image marks rendered by the Nim API")

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

## Linear smoothing

`linearSmoothPlot` delegates fitting, leverage and Student-t intervals to
UniStatistics. UniAccurate supplies the scale-separated centered norm, so
extreme finite predictors do not force `Inf / Inf`. UniPlot only filters
paired missing values and materialises an ordinary ribbon followed by a line.
The resulting retained marks therefore render identically through CPU, SVG and
WGPU.
"""

nbCode:
  let smoothed = linearSmoothPlot(
    [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
    [1.3, 1.8, 3.4, 3.7, 5.2, 5.8, 7.1], pointCount = 80,
    confidenceLevel = 0.95, lineColor = "#2457c5",
    bandColor = "#2457c540")
  let smoothedSvg = smoothed.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(smoothedSvg,
  "Linear fit and 95% mean-confidence band computed by UniStatistics.")

nbText: """
The recipe requires at least three finite pairs, a varying predictor, 2 to
10,000 evaluation points, and a confidence level strictly between zero and
one. Set `showConfidence = false` to materialise only the fitted line.

## Kernel density

`densityPlot` delegates Gaussian kernels, exact accumulation and automatic
bandwidth selection to UniStatistics. UniPlot filters non-finite observations
and materialises the estimate as an area followed by its outline.
"""

nbCode:
  let density = densityPlot(
    [-2.4, -2.0, -1.7, -1.1, -0.8, 0.6, 0.9, 1.2, 1.7, 2.1, 2.5],
    pointCount = 160, fillColor = "#7a3db840",
    lineColor = "#7a3db8")
  let densitySvg = density.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(densitySvg,
  "Gaussian density with an automatic UniStatistics bandwidth.")

nbText: """
At least two finite observations are required. `bandwidth = 0` selects the
automatic rule; any explicit bandwidth must be finite and positive. The
evaluation grid accepts between 2 and 100,000 points.

## Violin density

`violinPlot` reuses the same UniStatistics estimate, normalises its maximum to
the requested visual width and mirrors the ordered curve into one retained
polygon. It does not introduce a backend-specific density renderer.
"""

nbCode:
  let violin = violinPlot(
    [-2.4, -2.0, -1.7, -1.1, -0.8, 0.6, 0.9, 1.2, 1.7, 2.1, 2.5],
    pointCount = 160, width = 0.8, color = "#267a5e99")
  let violinSvg = violin.compileScene(
    Size(width: 560, height: 420)).toSvg(font)

nbRawHtml svgFigure(violinSvg,
  "Mirrored Gaussian density materialised as one retained polygon.")

nbText: """
The single-sample recipe represents observations on the y axis. Width is
finite, positive and unitless. The grouped overload uses first-seen categories
and numeric `xOffset` values expressed as fractions of band width, never
implicit backend pixels.
"""

nbCode:
  let groupedViolin = violinPlot(
    ["control", "treated", "control", "treated", "control", "treated"],
    [-1.2, 0.4, -0.2, 1.3, 0.8, 2.1], pointCount = 96,
    color = "#d65f2d99")
  let groupedViolinSvg = groupedViolin.compileScene(
    Size(width: 640, height: 420)).toSvg(font)

nbRawHtml svgFigure(groupedViolinSvg,
  "First-seen grouped violins placed in categorical band coordinates.")

nbText: """
Each rendered group requires at least two finite observations. Missing values
are ignored; empty group names and groups with fewer than two retained values
are rejected before publication.

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

`fill` maps categorical or continuous colours for supported filled point, bar,
tile and rectangle marks.
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

`labels` sets the title and axis labels. Themes are ordinary reusable values.
`defaultTheme`, `minimalTheme` and `darkTheme` provide explicit presets;
`deriveTheme` inherits unspecified colours and sizes, while `withMargins`
replaces all four margins without sentinel values.
"""

nbCode:
  let publicationStyle = minimalTheme().deriveTheme(
    foreground = "#162238", pointSize = 6)
  let compactPublicationStyle = publicationStyle.withMargins(
    Insets(left: 58, top: 48, right: 24, bottom: 54))

  var lightPlot = scatterPlot([0.0, 1.0, 2.0, 3.0, 4.0],
    [1.0, 4.0, 2.0, 5.0, 3.0], color = "#ffb703")
  lightPlot.labels(title = "Reusable publication style", x = "sample",
    y = "score")
  lightPlot.applyTheme(compactPublicationStyle)

  var darkPlot = linePlot([0.0, 1.0, 2.0, 3.0, 4.0],
    [1.0, 4.0, 2.0, 5.0, 3.0], color = "#63d2ff")
  darkPlot.geomPoint(aes("x", "y"), color = "#ffcf56", radius = 5)
  darkPlot.labels(title = "Dark preset", x = "sample", y = "score")
  darkPlot.applyTheme(darkTheme())

  let themeSvgs = [
    lightPlot.compileScene(Size(width: 500, height: 320)).toSvg(font),
    darkPlot.compileScene(Size(width: 500, height: 320)).toSvg(font)
  ]

nbRawHtml gallery([
  svgFigure(themeSvgs[0], "A derived minimal publication style."),
  svgFigure(themeSvgs[1], "The reusable dark preset.")
])

nbText: """
Colours use UniColor's CSS parser. Invalid colours fail during derivation.
Sizes and margins have debug contracts plus release-mode runtime guards, and
`compileScene` revalidates public fields. Applying one `Theme` to several plots
does not introduce shared mutable state because colours and theme values are
immutable/value-oriented.

Next: [Scales and statistics](scales_stats.html).
"""

nbSave
validatePage("grammar.html", minSvg = 12)
