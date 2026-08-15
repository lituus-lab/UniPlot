# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Optional WGPU backend. Importing it does not load wgpu-native; opening a
## backend dynamically loads the caller-selected native library.
import contracts
import UniColor
import UniGlyph
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

  WgpuPreparedScene* = ref object
    size*: Size
    clear: array[4, float32]
    vertices: seq[float32]
    indices: seq[uint32]

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
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
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
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc prepareWgpuScene*(scene: Scene;
                       font: Font): WgpuPreparedScene {.contractual.} =
  ## Shape text and tessellate paths once for repeated GPU frames.
  require:
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  ensure:
    not result.isNil
    result.size == scene.size
    result.vertices.len mod 6 == 0
    result.indices.len mod 3 == 0
  body:
    if font.isNil:
      raise newException(WgpuError, "WGPU scene preparation requires a font")
    scene.size.validate()
    if uint64(scene.size.width) > uint64(high(uint32)) or
        uint64(scene.size.height) > uint64(high(uint32)):
      raise newException(WgpuError, "WGPU target dimensions exceed uint32")
    let convertedBackground = scene.background.to(tagSRGB)
    if convertedBackground.isErr:
      raise newException(WgpuError, "cannot convert WGPU background to sRGB")
    let clear = convertedBackground.get
    result = WgpuPreparedScene(size: scene.size,
      clear: [clear.comp(0), clear.comp(1), clear.comp(2), clear.alpha])
    for node in scene.nodes:
      let path = case node.kind
        of snPath: node.path
        of snText:
          layoutText(textStyle(font, node.fontSize), node.text)
            .combinedPath(vec2(node.position.x, node.position.y))
      let mesh = path.preparePath().tessellateFill()
      let converted = node.color.to(tagSRGB)
      if converted.isErr:
        raise newException(WgpuError, "cannot convert WGPU node color to sRGB")
      let color = converted.get
      if result.vertices.len div 6 > int(high(uint32)) - mesh.vertexCount:
        raise newException(WgpuError, "WGPU scene exceeds uint32 vertex indices")
      let base = uint32(result.vertices.len div 6)
      for i in 0 ..< mesh.vertexCount:
        let vertex = mesh.vertex(i)
        result.vertices.add(vertex.position.x * 2'f32 /
          float32(scene.size.width) - 1'f32)
        result.vertices.add(1'f32 - vertex.position.y * 2'f32 /
          float32(scene.size.height))
        result.vertices.add([color.comp(0), color.comp(1), color.comp(2),
          color.alpha * vertex.coverage])
      for index in mesh.indices: result.indices.add(base + index)

proc validateSceneTarget(backend: WgpuBackend; scene: Scene; font: Font) =
  if backend.isNil or backend.state != wbsReady:
    raise newException(WgpuError, "WGPU backend is not ready")
  if font.isNil:
    raise newException(WgpuError, "WGPU scene rendering requires a font")
  scene.size.validate()
  if uint64(scene.size.width) > uint64(high(uint32)) or
      uint64(scene.size.height) > uint64(high(uint32)):
    raise newException(WgpuError, "WGPU target dimensions exceed uint32")

proc renderWgpuPrepared*(backend: WgpuBackend;
                         prepared: WgpuPreparedScene): seq[
                             byte] {.contractual.} =
  ## Upload, submit and read one previously prepared scene as RGBA8.
  require:
    not backend.isNil and backend.state == wbsReady
    not prepared.isNil
  ensure:
    result.len == prepared.size.width * prepared.size.height * 4
  body:
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    if prepared.isNil:
      raise newException(WgpuError, "prepared WGPU scene is nil")
    try:
      result = backend.runtime.renderMeshPixels(uint32(prepared.size.width),
        uint32(prepared.size.height), prepared.clear[0], prepared.clear[1],
        prepared.clear[2], prepared.clear[3], prepared.vertices,
        prepared.indices)
    except LibraryError as error:
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc submitWgpuPrepared*(backend: WgpuBackend;
                         prepared: WgpuPreparedScene) {.contractual.} =
  ## Upload and enqueue one previously prepared scene without readback.
  require:
    not backend.isNil and backend.state == wbsReady
    not prepared.isNil
  body:
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    if prepared.isNil:
      raise newException(WgpuError, "prepared WGPU scene is nil")
    try:
      backend.runtime.submitMesh(uint32(prepared.size.width),
        uint32(prepared.size.height), prepared.clear[0], prepared.clear[1],
        prepared.clear[2], prepared.clear[3], prepared.vertices,
        prepared.indices)
    except LibraryError as error:
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc renderWgpuScene*(backend: WgpuBackend; scene: Scene;
                      font: Font): seq[byte] {.contractual.} =
  ## Prepare, submit and read one retained scene back as unpadded RGBA8.
  require:
    not backend.isNil and backend.state == wbsReady
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  ensure:
    result.len == scene.size.width * scene.size.height * 4
  body:
    validateSceneTarget(backend, scene, font)
    backend.renderWgpuPrepared(scene.prepareWgpuScene(font))

proc submitWgpuScene*(backend: WgpuBackend; scene: Scene;
                      font: Font) {.contractual.} =
  ## Prepare and enqueue one retained scene without a GPU-to-CPU transfer.
  require:
    not backend.isNil and backend.state == wbsReady
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  body:
    validateSceneTarget(backend, scene, font)
    backend.submitWgpuPrepared(scene.prepareWgpuScene(font))
