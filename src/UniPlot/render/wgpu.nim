# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Optional WGPU backend. Importing it does not load wgpu-native; opening a
## backend dynamically loads the caller-selected native library.
import contracts
import UniColor
import UniVector
import UniPlot/[common, scene]
import UniPlot/render/wgpu_native

const WgpuNativeTargetVersion* = "29.0.1.1"

type
  WgpuError* = object of CatchableError

  WgpuBackendState* = enum
    wbsUnavailable
    wbsReady
    wbsDeviceLost

  WgpuCapabilities* = object
    available*: bool
    picking*, storageBuffers*, timestampQueries*: bool
    implementationVersion*: string

  WgpuResourceKind* = enum
    wrPathMesh
    wrGlyphAtlas
    wrImageTexture

  WgpuResource* = object
    id*: uint64
    kind*: WgpuResourceKind

  WgpuFrame* = object
    size*: Size
    resources*: seq[WgpuResource]
    nodeCount*: int

  WgpuBackend* = ref object
    state*: WgpuBackendState
    runtime: NativeWgpuRuntime

proc prepareWgpuFrame*(scene: Scene): WgpuFrame =
  ## Extract stable semantic resource identifiers before any device is needed.
  result.size = scene.size
  result.nodeCount = scene.nodes.len
  for node in scene.nodes:
    if node.id != 0:
      let kind = if node.kind == snText: wrGlyphAtlas else: wrPathMesh
      result.resources.add WgpuResource(id: node.id, kind: kind)

proc openWgpuBackend*(libraryPath: string): WgpuBackend {.contractual.} =
  ## Open a real wgpu-native adapter, device, and queue from `libraryPath`.
  require:
    libraryPath.len > 0
  ensure:
    not result.isNil and result.state == wbsReady
  body:
    if libraryPath.len == 0:
      raise newException(WgpuError, "wgpu-native library path is empty")
    result = WgpuBackend(state: wbsUnavailable)
    try:
      result.runtime = openNativeWgpu(libraryPath)
      result.state = wbsReady
    except LibraryError as error:
      raise newException(WgpuError, error.msg)

proc close*(backend: WgpuBackend) {.contractual.} =
  ## Release queue, device, adapter, instance, and dynamic library in order.
  ensure:
    backend.isNil or backend.state == wbsUnavailable
  body:
    if backend.isNil: return
    backend.runtime.close()
    backend.runtime = nil
    backend.state = wbsUnavailable

proc wgpuCapabilities*(backend: WgpuBackend = nil): WgpuCapabilities =
  ## Report runtime availability without causing implicit library loading.
  result.implementationVersion = WgpuNativeTargetVersion
  if not backend.isNil and backend.state == wbsReady:
    result.available = true
    result.storageBuffers = true
    result.timestampQueries = backend.runtime.supportsTimestampQueries()

proc readWgpuClearTarget*(backend: WgpuBackend; size: Size;
    color: Color): seq[byte] {.contractual.} =
  ## Clear an offscreen RGBA8 texture and read its unpadded pixels back.
  require:
    not backend.isNil and backend.state == wbsReady
    size.width > 0 and size.height > 0
    uint64(size.width) <= uint64(high(uint32))
    uint64(size.height) <= uint64(high(uint32))
  body:
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    size.validate()
    if uint64(size.width) > uint64(high(uint32)) or
        uint64(size.height) > uint64(high(uint32)):
      raise newException(WgpuError, "WGPU target dimensions exceed uint32")
    let converted = color.to(tagSRGB)
    if converted.isErr:
      raise newException(WgpuError, "cannot convert WGPU clear color to sRGB")
    let rgba = converted.get
    try:
      result = backend.runtime.renderClearPixels(uint32(size.width),
        uint32(size.height),
        rgba.comp(0), rgba.comp(1), rgba.comp(2), rgba.alpha)
    except LibraryError as error:
      raise newException(WgpuError, error.msg)

proc clearWgpuTarget*(backend: WgpuBackend; size: Size; color: Color) =
  ## Submit a real offscreen render pass, discarding its validation readback.
  discard backend.readWgpuClearTarget(size, color)

proc readWgpuMeshTarget*(backend: WgpuBackend; size: Size; background: Color;
    mesh: VectorMesh; color: Color): seq[byte] {.contractual.} =
  ## Render one UniVector indexed triangle mesh into an RGBA8 target.
  require:
    not backend.isNil and backend.state == wbsReady
    size.width > 0 and size.height > 0
    uint64(size.width) <= uint64(high(uint32))
    uint64(size.height) <= uint64(high(uint32))
    mesh.indexCount mod 3 == 0
  ensure:
    result.len == size.width * size.height * 4
  body:
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    size.validate()
    if uint64(size.width) > uint64(high(uint32)) or
        uint64(size.height) > uint64(high(uint32)):
      raise newException(WgpuError, "WGPU target dimensions exceed uint32")
    let convertedBackground = background.to(tagSRGB)
    let convertedColor = color.to(tagSRGB)
    if convertedBackground.isErr or convertedColor.isErr:
      raise newException(WgpuError, "cannot convert WGPU mesh colors to sRGB")
    let
      clear = convertedBackground.get
      fill = convertedColor.get
    var vertices = newSeq[float32](mesh.vertexCount * 6)
    for i in 0 ..< mesh.vertexCount:
      let vertex = mesh.vertex(i)
      let offset = i * 6
      vertices[offset] = vertex.position.x * 2'f32 / float32(size.width) - 1'f32
      vertices[offset + 1] = 1'f32 -
        vertex.position.y * 2'f32 / float32(size.height)
      vertices[offset + 2] = fill.comp(0)
      vertices[offset + 3] = fill.comp(1)
      vertices[offset + 4] = fill.comp(2)
      vertices[offset + 5] = fill.alpha * vertex.coverage
    try:
      result = backend.runtime.renderMeshPixels(uint32(size.width),
        uint32(size.height), clear.comp(0), clear.comp(1), clear.comp(2),
        clear.alpha, vertices, mesh.indices)
    except LibraryError as error:
      raise newException(WgpuError, error.msg)
