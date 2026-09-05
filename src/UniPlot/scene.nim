# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import UniColor
import UniImage/core as uimg
import UniVector
import contracts
import UniPlot/common

type
  SceneNodeKind* = enum
    snPath
    snText
    snImage

  TextAnchor* = enum
    textStart
    textMiddle
    textEnd

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
      anchor*: TextAnchor
    of snImage:
      image*: uimg.Image[uint8]
      imageX*: int
      imageY*: int
      opacity*: uint8

  Scene* = object
    size*: Size
    background*: Color
    nodes*: seq[SceneNode]

func anchoredTextX*(anchor: TextAnchor; x, width: float32): float32 {.
    inline.} =
  ## Resolve the left edge of shaped text from its semantic anchor.
  case anchor
  of textStart: x
  of textMiddle: x - width * 0.5'f32
  of textEnd: x - width

proc initScene*(size: Size; background: Color): Scene {.contractual.} =
  require:
    size.width > 0 and size.height > 0
  ensure:
    result.size == size and result.nodes.len == 0
  body:
    size.validate()
    Scene(size: size, background: background)

proc addPath*(scene: var Scene; path: Path; color: Color; id = 0'u64) =
  scene.nodes.add SceneNode(kind: snPath, id: id, color: color, path: path)

proc addText*(scene: var Scene; text: string; position: Point;
    fontSize: float32; color: Color; id = 0'u64;
    anchor = textStart) {.contractual.} =
  require:
    fontSize > 0 and fontSize.isFinite
    position.x.isFinite and position.y.isFinite
  body:
    if fontSize <= 0 or not fontSize.isFinite:
      raise newException(PlotError, "font size must be finite and positive")
    if not position.x.isFinite or not position.y.isFinite:
      raise newException(PlotError, "text position must be finite")
    scene.nodes.add SceneNode(kind: snText, id: id, color: color, text: text,
      position: position, fontSize: fontSize, anchor: anchor)

func validLayerImage*(image: uimg.Image[uint8]): bool =
  if image.width <= 0 or image.height <= 0 or
      image.colorspace notin {uimg.csGray, uimg.csRgb, uimg.csRgba} or
      image.channels != uimg.ChannelCount[image.colorspace]:
    return false
  if image.width > high(int) div image.height:
    return false
  let pixels = image.width * image.height
  pixels <= high(int) div image.channels and
    image.data.len == pixels * image.channels

proc addImage*(scene: var Scene; image: uimg.Image[uint8]; x, y: int;
    opacity = 255'u8; id = 0'u64) {.contractual.} =
  ## Add a pixel-aligned raster layer. The scene retains the image buffer;
  ## `prepareScene` takes an owned snapshot for immutable repeated rendering.
  require:
    image.validLayerImage
  body:
    if not image.validLayerImage:
      raise newException(PlotError, "image layer must contain a valid Gray, RGB, or RGBA image")
    scene.nodes.add SceneNode(kind: snImage, id: id, image: image,
      imageX: x, imageY: y, opacity: opacity)
