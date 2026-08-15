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

This API is explicit subplot composition. Automatic data faceting, shared
domains, shared axes and secondary axes are not part of it yet and are not
claimed as implemented.

Next: [Versioned JSON](serialization.html).
"""

nbSave
validatePage("composition.html", minSvg = 1, requirePng = true)
