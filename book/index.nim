# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib

nbInit
nb.title = "UniPlot 1.0"

nbText: """
# UniPlot 1.0

UniPlot compiles typed data and a plotting grammar into a retained scene. The
same scene feeds vector and raster backends, so layout, guides and layer order
do not drift between export formats.

## Data and grammar
"""

nbCode:
  import UniPlot

  var frame = initDataFrame()
  frame.addColumn("time", [0.0, 1.0, 2.0, 3.0])
  frame.addColumn("value", [1.0, 3.0, 2.0, 4.0])

  var figure = plot(frame)
  figure.geomLine(aes("time", "value"), color = "#3366cc")
  figure.geomPoint(aes("time", "value"), color = "#cc3344")
  figure.labels(title = "Measured value", x = "time", y = "value")

  let scene = figure.compileScene(Size(width: 640, height: 400))
  echo "version ", UniPlotVersion
  echo "layers ", figure.layers.len
  echo "scene nodes ", scene.nodes.len

nbText: """
Finite values train the shared scales. Grid lines, tick labels and data marks
become ordered scene nodes. Each data mark receives a stable identifier that a
future interactive backend can reuse for picking.

## Statistics
"""

nbCode:
  let bins = histogram([0.1, 0.2, 0.8, 1.0, 1.1, 1.8], 3)
  var total = 0
  for bin in bins: total += bin.count
  echo "bins ", bins.len
  echo "samples ", total

nbText: """
Statistics run in data space before scale transformation. Invalid bin counts
and empty scale-training inputs are explicit errors.

## Rendering

Text is shaped and outlined by UniGlyph. Paths are filled by UniVector and PNG
encoding belongs to UniImage. A caller supplies the font, making the result
reproducible and avoiding platform font discovery.
"""

nbCode:
  import UniGlyph
  let font = loadTtf("tests/DejaVuSans.ttf")
  let svg = scene.toSvg(font)
  let png = scene.encodePng(font)
  echo "svg prefix ", svg[0 .. 3]
  echo "png signature ", png[0 .. 3]

nbText: """
## Backend boundary

The core scene contains paths, text runs, colours and stable identifiers but no
window, device, queue or shader handle. SVG and PNG are the 1.0 reference
backends. WGPU consumes the same scene through an optional package and never
becomes a dependency of the default import.
"""

nbSave
