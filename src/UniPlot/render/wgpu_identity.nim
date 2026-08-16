# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Canonical retained-scene identity for automatic WGPU preparation caching.
import UniColor
import UniGlyph
import UniVector
import UniCrypto/hash/blake3/blake3 as ublake3
import UniPlot/[common, scene]

type WgpuSceneIdentity* = array[32, byte]

proc addByte(hasher: var ublake3.Hasher; value: byte) {.inline.} =
  let encoded = [value]
  hasher.update(encoded)

proc addU32(hasher: var ublake3.Hasher; value: uint32) {.inline.} =
  let encoded = [
    byte(value), byte(value shr 8), byte(value shr 16), byte(value shr 24)]
  hasher.update(encoded)

proc addU64(hasher: var ublake3.Hasher; value: uint64) {.inline.} =
  let encoded = [
    byte(value), byte(value shr 8), byte(value shr 16), byte(value shr 24),
    byte(value shr 32), byte(value shr 40), byte(value shr 48),
    byte(value shr 56)]
  hasher.update(encoded)

proc addFloat(hasher: var ublake3.Hasher; value: float32) {.inline.} =
  hasher.addU32(cast[uint32](value))

proc addString(hasher: var ublake3.Hasher; value: string) =
  hasher.addU64(uint64(value.len))
  if value.len > 0:
    hasher.update(value.toOpenArrayByte(0, value.high))

proc addColor(hasher: var ublake3.Hasher; value: Color) =
  hasher.addU32(cast[uint32](value.spaceTag.id))
  for component in 0 .. 2:
    hasher.addFloat(value.comp(component))
  hasher.addFloat(value.alpha)

func commandCode(kind: PathCommandKind): byte =
  ## Explicit codes keep the key format independent of enum storage details.
  case kind
  of pClose: 0
  of pMove: 1
  of pLine: 2
  of pHLine: 3
  of pVLine: 4
  of pCubic: 5
  of pSCubic: 6
  of pQuad: 7
  of pTQuad: 8
  of pArc: 9
  of pRMove: 10
  of pRLine: 11
  of pRHLine: 12
  of pRVLine: 13
  of pRCubic: 14
  of pRSCubic: 15
  of pRQuad: 16
  of pRTQuad: 17
  of pRArc: 18

func nodeCode(kind: SceneNodeKind): byte =
  case kind
  of snPath: 0
  of snText: 1

func anchorCode(anchor: TextAnchor): byte =
  case anchor
  of textStart: 0
  of textMiddle: 1
  of textEnd: 2

proc addPoint(hasher: var ublake3.Hasher; point: Vec2) {.inline.} =
  hasher.addFloat(point.x)
  hasher.addFloat(point.y)

proc addCommand(hasher: var ublake3.Hasher; command: PathCommand) =
  hasher.addByte(command.kind.commandCode)
  case command.kind
  of pClose:
    discard
  of pMove, pLine, pRMove, pRLine, pTQuad, pRTQuad:
    hasher.addPoint(command.p)
  of pHLine, pRHLine, pVLine, pRVLine:
    hasher.addFloat(command.v)
  of pCubic, pRCubic:
    hasher.addPoint(command.c1)
    hasher.addPoint(command.c2)
    hasher.addPoint(command.c3)
  of pSCubic, pRSCubic, pQuad, pRQuad:
    hasher.addPoint(command.c)
    hasher.addPoint(command.e)
  of pArc, pRArc:
    hasher.addPoint(command.r)
    hasher.addFloat(command.rot)
    hasher.addByte(byte(command.largeArc))
    hasher.addByte(byte(command.sweep))
    hasher.addPoint(command.a)

proc addPath(hasher: var ublake3.Hasher; path: Path) =
  ## Builder cursor fields are excluded: rendering consumes commands only.
  hasher.addU64(uint64(path.commands.len))
  for command in path.commands:
    hasher.addCommand(command)

proc sceneIdentity*(scene: Scene; font: Font): WgpuSceneIdentity =
  var hasher = ublake3.newHasher()
  hasher.addString("lituus-lab/UniPlot/wgpu-scene/v1")
  hasher.addU64(uint64(scene.size.width))
  hasher.addU64(uint64(scene.size.height))
  hasher.addColor(scene.background)
  hasher.addU64(uint64(scene.nodes.len))
  var usesFont = false
  for node in scene.nodes:
    hasher.addByte(node.kind.nodeCode)
    hasher.addColor(node.color)
    case node.kind
    of snPath:
      hasher.addPath(node.path)
    of snText:
      usesFont = true
      hasher.addString(node.text)
      hasher.addFloat(node.position.x)
      hasher.addFloat(node.position.y)
      hasher.addFloat(node.fontSize)
      hasher.addByte(node.anchor.anchorCode)
  hasher.addByte(byte(usesFont))
  if usesFont:
    let identity = font.fontIdentity
    hasher.update(identity)
  hasher.finalize(result)
