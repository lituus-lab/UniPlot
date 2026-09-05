# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/os
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Scenes and rendering

`compileScene` performs validation, finite-row filtering, scale training,
layout and guide generation. The result contains ordered paths, text runs,
colours and stable identifiers — never a window, queue or GPU device.

## Inspect a compiled scene
"""

nbCode:
  import UniPlot
  import UniGlyph

  let font = loadTtf("../../tests/DejaVuSans.ttf")
  var figure = linePlot([0.0, 1.0, 2.0, 3.0], [1.0, 3.0, 2.0, 4.0])
  figure.geomPoint(aes("x", "y"), color = "#cc3344", radius = 5)
  figure.labels(title = "Inspectable scene", x = "x", y = "y")
  let scene = figure.compileScene(Size(width: 720, height: 420))

  var pathNodes = 0
  var textNodes = 0
  var imageNodes = 0
  var semanticIds: seq[uint64]
  for node in scene.nodes:
    case node.kind
    of snPath: inc pathNodes
    of snText: inc textNodes
    of snImage: inc imageNodes
    if node.id != 0: semanticIds.add node.id
  echo "paths: ", pathNodes, ", text: ", textNodes,
    ", images: ", imageNodes
  echo "stable mark ids: ", semanticIds

nbText: """
`SceneNodeKind` distinguishes `snPath`, `snText` and retained `snImage` nodes.
Non-zero IDs identify data
marks and survive into SVG as `data-uniplot-id`, providing a future picking key.
Text nodes also retain `textStart`, `textMiddle` or `textEnd` anchoring.
The renderer resolves the anchor from UniGlyph's shaped advance, so CPU, SVG
and WGPU place centered tick labels and axis titles identically.

## Construct a scene directly

Adapters can bypass the grammar with `initScene`, `addPath` and `addText`.
`Bounds`, `Point`, `Size` and `Insets` are the shared geometry value types.
"""

nbCode:
  import UniColor
  import UniVector

  var direct = initScene(Size(width: 500, height: 220),
    parseColor("#ffffff").get)
  var rectangle = newPath()
  rectangle.rect(60, 80, 380, 70)
  direct.addPath(rectangle, parseColor("#457b9d").get, id = 42)
  direct.addText("Direct retained scene", Point(x: 130, y: 55), 20,
    parseColor("#1d3557").get, id = 43, anchor = textStart)
  let directSvg = direct.toSvg(font)

nbRawHtml svgFigure(directSvg,
  "A scene built from a UniVector path and a UniGlyph text run.")

nbText: """
## SVG and PNG from one scene

`toSvg` returns XML. `renderImage` returns a UniImage image. `encodePng`
returns PNG bytes. `saveSvg` and `savePng` are file conveniences.
"""

nbCode:
  let svg = scene.toSvg(font)
  let png = scene.encodePng(font)
  let image = scene.renderImage(font)
  echo "SVG prefix: ", svg[0 .. 3]
  echo "PNG signature: ", png[0 .. 3]
  echo "raster size: ", image.width, " × ", image.height

nbRawHtml gallery([
  svgFigure(svg, "Deterministic vector output."),
  pngFigure(pngDataUri(png), "The same scene rasterised and embedded in HTML.",
    "UniPlot line and point plot rendered as PNG")
])

nbText: """
## Reusable CPU preparation

For repeated export, `prepareScene` shapes every UniGlyph text node and
flattens every UniVector path once. The resulting `PreparedScene` owns an
independent copy of its vector paths: later mutation of the source `Scene`
cannot desynchronise SVG from cached raster geometry.
"""

nbCode:
  let prepared = scene.prepareScene(font)
  let preparedSvg = prepared.toSvg()
  let preparedPng = prepared.encodePng()
  doAssert preparedSvg == svg
  doAssert preparedPng == png
  echo "prepared size: ", prepared.size.width, " × ", prepared.size.height
  echo "exact SVG/PNG parity: true"

nbText: """
`PreparedScene.toSvg`, `renderImage`, `encodePng`, `saveSvg` and `savePng` no
longer require a font because shaping is already complete. Preparation is
explicit and bounded by the caller; UniPlot does not retain an unbounded global
cache. WGPU has the analogous `WgpuPreparedScene` resource boundary.
"""

nbCode:
  let temporary = getTempDir() / "uniplot-book-export"
  scene.saveSvg(font, temporary & ".svg")
  scene.savePng(font, temporary & ".png")
  echo "saved SVG bytes: ", getFileSize(temporary & ".svg")
  echo "saved PNG bytes: ", getFileSize(temporary & ".png")
  removeFile(temporary & ".svg")
  removeFile(temporary & ".png")

nbText: """
UniGlyph converts text to paths, UniVector owns vector geometry and UniImage
owns raster encoding. An explicit font keeps output independent of host font
discovery.

Next: [Plot grids](composition.html).
"""

nbSave
validatePage("scene_rendering.html", minSvg = 2, requirePng = true)
