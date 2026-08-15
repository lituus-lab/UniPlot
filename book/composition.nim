# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Plot grids

`compileGrid` lays out complete plot specifications in row-major order and
returns one ordinary retained `Scene`. Every panel retains its own data,
scales, guides, theme and background, so the result goes through the same SVG,
PNG, prepared-CPU and WGPU paths as a single plot.

## A two-by-two dashboard
"""

nbCode:
  import UniPlot
  import UniGlyph

  let font = loadTtf("../../tests/DejaVuSans.ttf")

  var wave = linePlot([0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 0.2, 1.4])
  wave.geomPoint(aes("x", "y"), radius = 4)
  wave.labels(title = "Line and points", x = "time", y = "value")

  var bars = barPlot(["A", "B", "C", "D"], [4.0, 7.0, 3.0, 6.0])
  bars.labels(title = "Categories", x = "group", y = "count")

  var areaData = initDataFrame()
  areaData.addColumn("x", [0.0, 1.0, 2.0, 3.0])
  areaData.addColumn("volume", [1.0, 2.5, 1.8, 3.2])
  var area = plot(areaData)
  area.geomArea(aes("x", "volume"))
  area.labels(title = "Area", x = "x", y = "volume")

  var points = scatterPlot([0.2, 0.8, 1.5, 2.4], [2.1, 1.2, 2.8, 1.7])
  points.labels(title = "Scatter", x = "feature", y = "response")
  points.applyTheme(darkTheme())

  let dashboard = compileGrid([wave, bars, area, points], columns = 2,
    size = Size(width: 900, height: 650), gap = 18)
  let svg = dashboard.toSvg(font)
  let png = dashboard.encodePng(font)
  echo "dashboard nodes: ", dashboard.nodes.len
  echo "SVG/PNG bytes: ", svg.len, "/", png.len

nbRawHtml gallery([
  svgFigure(svg, "Four independent plots composed into one SVG scene."),
  pngFigure(pngDataUri(png),
    "The identical grid rasterised through UniVector and UniImage.",
    "A two by two UniPlot grid with line, bar, area and scatter panels")
])

nbText: """
The `gap` is an integer pixel distance. Any division remainder is distributed
across leading rows and columns, so the final panel reaches the requested
canvas edge. Invalid column counts, negative gaps and cells too small to have
positive dimensions are rejected in debug contracts and by release guards.

Panel node IDs are deterministically namespaced. Recompiling the same grid
therefore gives stable IDs without collisions between repeated specifications.

## Shared axis domains
"""

nbCode:
  var local = linePlot([0.0, 1.0, 2.0], [10.0, 20.0, 15.0],
    color = "#3366cc")
  local.labels(title = "Local range", x = "time", y = "value")
  var distant = linePlot([4.0, 6.0, 8.0], [-20.0, 0.0, 30.0],
    color = "#cc6633")
  distant.labels(title = "Distant range", x = "time", y = "value")
  let shared = compileGrid([local, distant], columns = 2,
    size = Size(width: 900, height: 360), gap = 18,
    sharedX = true, sharedY = true)
  let sharedSvg = shared.toSvg(font)

nbRawHtml svgFigure(sharedSvg,
  "Both panels use the union of their numeric x and y domains.")

nbText: """
`sharedX` and `sharedY` default to `false`. When enabled, UniPlot accumulates
the same coordinates as ordinary scene compilation: marks, ribbon/error
bounds, zero baselines and reference annotations. Source specifications remain
unchanged. All participating axes must use the same transform and direction;
existing explicit limits must already satisfy their own plot before they join
the union.

Categorical x domains are unioned in first-seen panel order. An explicit
`xCategories` order is retained first and must contain its panel's observed
values. Numeric and categorical x coordinates cannot be mixed in one shared
grid.

"""

nbCode:
  var firstBars = barPlot(["beta", "alpha"], [3.0, 2.0])
  firstBars.labels(title = "First categories", x = "group", y = "count")
  var secondBars = barPlot(["gamma", "beta"], [4.0, 1.0])
  secondBars.labels(title = "Second categories", x = "group", y = "count")
  let categoricalShared = compileGrid([firstBars, secondBars], columns = 2,
    size = Size(width: 900, height: 360), gap = 18, sharedX = true)
  let categoricalSharedSvg = categoricalShared.toSvg(font)

nbRawHtml svgFigure(categoricalSharedSvg,
  "Both bar panels use beta, alpha, gamma in deterministic union order.")

nbText: """
Guide deduplication and secondary axes are not implemented and are not claimed.

## Data-driven categorical facets
"""

nbCode:
  var observations = initDataFrame()
  observations.addColumn("time", [0.0, 1.0, 2.0, 0.0, 1.0, 2.0])
  observations.addColumn("value", [1.0, 2.0, 1.5, 4.0, 3.0, 5.0])
  observations.addColumn("site",
    ["north", "north", "north", "south", "south", "south"])
  var measured = plot(observations)
  measured.geomLine(aes("time", "value"), color = "#267a5e")
  measured.geomPoint(aes("time", "value"), color = "#d65f2d", radius = 4)
  measured.labels(title = "Measurements", x = "time", y = "value")
  let faceted = compileFacetGrid(measured, "site", columns = 2,
    size = Size(width: 900, height: 360), gap = 18,
    sharedX = true, sharedY = true)
  let facetedSvg = faceted.toSvg(font)

nbRawHtml svgFigure(facetedSvg,
  "One complete plot specification partitioned by the site column.")

nbText: """
`facetSpecs(spec, column)` exposes the intermediate panel specifications when
custom composition is needed. It accepts an existing categorical column,
preserves all columns and row order inside each category, and orders panels by
first appearance. `compileFacetGrid` performs the split and ordinary grid
compilation in one call; its sharing flags have the same contract as
`compileGrid`.

Empty, missing or numeric facet columns are rejected. Two-dimensional facets,
guide deduplication and secondary axes remain future work.

Next: [Versioned JSON](serialization.html).
"""

nbSave
validatePage("composition.html", minSvg = 4, requirePng = true)
