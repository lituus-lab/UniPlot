# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strformat
import UniGlyph
import UniImage/core as uimg
import UniImage/formats
import UniVector
import UniPlot/[common, scene]

proc nodePath(node: SceneNode; font: Font): Path =
  case node.kind
  of snPath: node.path
  of snText:
    let layout = layoutText(textStyle(font, node.fontSize), node.text)
    layout.combinedPath(vec2(node.position.x, node.position.y))

proc toSvg*(scene: Scene; font: Font): string =
  if font.isNil: raise newException(PlotError, "SVG rendering requires a font")
  let width = scene.size.width
  let height = scene.size.height
  result = &"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{width}\" " &
    &"height=\"{height}\" viewBox=\"0 0 {width} {height}\">"
  result &= &"<rect width=\"{width}\" height=\"{height}\" fill=\"" &
    toSvgColor(scene.background) & "\"/>"
  for node in scene.nodes:
    result &= "<path d=\"" & $(node.nodePath(font)) & "\" fill=\"" &
      toSvgColor(node.color) & "\""
    if node.id != 0: result &= " data-uplot-id=\"" & $node.id & "\""
    result &= "/>"
  result &= "</svg>"

proc renderImage*(scene: Scene; font: Font): uimg.Image[uint8] =
  if font.isNil: raise newException(PlotError, "raster rendering requires a font")
  result = uimg.newImage[uint8](scene.size.width, scene.size.height, uimg.csRgba)
  var background = newPath()
  background.rect(0, 0, float32(scene.size.width), float32(scene.size.height))
  result.fillPath(background, scene.background)
  for node in scene.nodes:
    result.fillPath(node.nodePath(font), node.color)

proc encodePng*(scene: Scene; font: Font): seq[byte] =
  encodeImage(scene.renderImage(font), efPng)

proc saveSvg*(scene: Scene; font: Font; path: string) =
  writeFile(path, scene.toSvg(font))

proc savePng*(scene: Scene; font: Font; path: string) =
  writeFile(path, cast[string](scene.encodePng(font)))
