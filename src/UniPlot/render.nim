# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strformat
import UniColor
import UniGlyph
import UniImage/core as uimg
import UniImage/formats
import UniVector
import contracts
import UniPlot/[common, scene]

type
  PreparedRenderNode = object
    id: uint64
    color: Color
    path: Path
    geometry: PreparedPath

  PreparedScene* = ref object
    sizeData: Size
    background: Color
    backgroundPath: PreparedPath
    nodes: seq[PreparedRenderNode]

func size*(prepared: PreparedScene): Size {.contractual.} =
  ## Return the immutable output dimensions of a prepared CPU scene.
  require:
    not prepared.isNil
  body:
    if prepared.isNil:
      raise newException(PlotError, "prepared scene is nil")
    prepared.sizeData

proc nodePath(node: SceneNode; font: Font): Path =
  case node.kind
  of snPath: node.path
  of snText:
    let layout = layoutText(textStyle(font, node.fontSize), node.text)
    let x = node.anchor.anchoredTextX(node.position.x, layout.width)
    layout.combinedPath(vec2(x, node.position.y))

proc prepareScene*(scene: Scene; font: Font): PreparedScene =
  ## Shape text and flatten all paths once for repeated CPU/SVG rendering.
  if font.isNil:
    raise newException(PlotError, "scene preparation requires a font")
  var background = newPath()
  background.rect(0, 0, float32(scene.size.width), float32(scene.size.height))
  result = PreparedScene(sizeData: scene.size, background: scene.background,
    backgroundPath: background.preparePath(),
    nodes: newSeqOfCap[PreparedRenderNode](scene.nodes.len))
  for node in scene.nodes:
    let path = node.nodePath(font).copy
    result.nodes.add PreparedRenderNode(id: node.id, color: node.color,
      path: path, geometry: path.preparePath())

proc toSvg*(prepared: PreparedScene): string =
  ## Serialize previously shaped paths without requiring the font again.
  if prepared.isNil:
    raise newException(PlotError, "prepared scene is nil")
  let width = prepared.sizeData.width
  let height = prepared.sizeData.height
  result = &"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{width}\" " &
    &"height=\"{height}\" viewBox=\"0 0 {width} {height}\">"
  result &= &"<rect width=\"{width}\" height=\"{height}\" fill=\"" &
    toSvgColor(prepared.background) & "\"/>"
  for node in prepared.nodes:
    result &= "<path d=\"" & $node.path & "\" fill=\"" &
      toSvgColor(node.color) & "\""
    if node.id != 0: result &= " data-uplot-id=\"" & $node.id & "\""
    result &= "/>"
  result &= "</svg>"

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

proc renderImage*(prepared: PreparedScene): uimg.Image[uint8] =
  ## Rasterise cached UniVector geometry without reshaping or reflattening.
  if prepared.isNil:
    raise newException(PlotError, "prepared scene is nil")
  result = uimg.newImage[uint8](prepared.sizeData.width,
    prepared.sizeData.height, uimg.csRgba)
  result.fillPreparedPath(prepared.backgroundPath, prepared.background)
  for node in prepared.nodes:
    result.fillPreparedPath(node.geometry, node.color)

proc encodePng*(scene: Scene; font: Font): seq[byte] =
  encodeImage(scene.renderImage(font), efPng)

proc encodePng*(prepared: PreparedScene): seq[byte] =
  encodeImage(prepared.renderImage(), efPng)

proc saveSvg*(scene: Scene; font: Font; path: string) =
  writeFile(path, scene.toSvg(font))

proc savePng*(scene: Scene; font: Font; path: string) =
  writeFile(path, cast[string](scene.encodePng(font)))

proc saveSvg*(prepared: PreparedScene; path: string) =
  writeFile(path, prepared.toSvg())

proc savePng*(prepared: PreparedScene; path: string) =
  writeFile(path, cast[string](prepared.encodePng()))
