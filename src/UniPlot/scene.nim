# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import UniColor
import UniVector
import UniPlot/common

type
  SceneNodeKind* = enum
    snPath
    snText

  SceneNode* = object
    id*: uint64
    color*: Color
    case kind*: SceneNodeKind
    of snPath:
      path*: Path
    of snText:
      text*: string
      position*: Point
      fontSize*: float32

  Scene* = object
    size*: Size
    background*: Color
    nodes*: seq[SceneNode]

proc initScene*(size: Size; background: Color): Scene =
  size.validate()
  Scene(size: size, background: background)

proc addPath*(scene: var Scene; path: Path; color: Color; id = 0'u64) =
  scene.nodes.add SceneNode(kind: snPath, id: id, color: color, path: path)

proc addText*(scene: var Scene; text: string; position: Point;
    fontSize: float32; color: Color; id = 0'u64) =
  if fontSize <= 0 or not fontSize.isFinite:
    raise newException(PlotError, "font size must be finite and positive")
  scene.nodes.add SceneNode(kind: snText, id: id, color: color, text: text,
    position: position, fontSize: fontSize)

