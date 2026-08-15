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

## The five geometries

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
validatePage("grammar.html", minSvg = 9)
