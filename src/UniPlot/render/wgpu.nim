# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Optional WGPU backend. Importing it does not load wgpu-native; opening a
## backend dynamically loads the caller-selected native library.
import std/atomics
import contracts
import UniColor
import UniGlyph
import UniImage/core as uimg
import UniVector
import UniPlot/[common, scene]
import UniPlot/render/wgpu_native
from UniPlot/render/wgpu_identity import WgpuSceneIdentity, sceneIdentity

export WgpuSceneIdentity

const WgpuNativeTargetVersion* = "29.0.1.1"
const MaxPreparedCacheEntries* = 64
const MinPreparedCacheByteBudget* = 512'u64
const DefaultPreparedCacheByteBudget* = 256'u64 * 1024'u64 * 1024'u64
const MinUploadChunkBytes* = 4'u64
const MaxUploadChunkBytes* = 64'u64 * 1024'u64 * 1024'u64
const DefaultUploadChunkBytes* = 4'u64 * 1024'u64 * 1024'u64
const MinManagedGpuByteBudget* = 1024'u64
const DefaultManagedGpuByteBudget* = 512'u64 * 1024'u64 * 1024'u64
const MaxStreamingRingEntries* = 8
const DefaultStreamingRingEntries* = 3
const MaxSceneCacheEntries* = 64
const MinSceneCacheByteBudget* = 512'u64
const DefaultSceneCacheByteBudget* = 256'u64 * 1024'u64 * 1024'u64
const DefaultSceneCacheEntries* = 16

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
    adapterName*, adapterVendor*, adapterArchitecture*: string
    adapterDescription*, backend*: string
    vendorId*, deviceId*, maxTextureDimension2D*: uint32
    maxBufferSize*: uint64

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

  WgpuDiagnostics* = object
    meshUploads*: uint64
    textureUploads*, textureUploadBytes*: uint64
    uploadWriteCalls*, uploadBytes*, largestUploadWrite*: uint64
    uploadChunkBytes*: uint64
    preparedCacheHits*, preparedCacheMisses*: uint64
    preparedCacheEvictions*: uint64
    preparedCacheBytes*, preparedCachePeakBytes*: uint64
    preparedCacheByteBudget*: uint64
    preparedCacheEntries*, preparedCacheCapacity*: int
    managedGpuBytes*, managedGpuPeakBytes*, managedGpuByteBudget*: uint64
    streamingBufferBytes*, targetTextureBytes*, readbackBufferBytes*: uint64
    rasterWorkingSetPeakBytes*: uint64
    streamingRingEntries*, streamingRingCapacity*: int
    streamingRingRotations*, streamingRingSyncs*: uint64
    sceneCacheHits*, sceneCacheMisses*, sceneCacheEvictions*: uint64
    sceneCacheBytes*, sceneCachePeakBytes*, sceneCacheByteBudget*: uint64
    sceneCacheEntries*, sceneCacheCapacity*: int

  WgpuPreparedScene* = ref object
    size: Size
    clear: array[4, float32]
    vertices: seq[float32]
    indices: seq[uint32]
    imageVertices: seq[float32]
    images: seq[NativeImageData]
    commands: seq[NativeDrawCommand]
    uploadToken: uint64

  SceneCacheEntry = object
    identity: WgpuSceneIdentity
    prepared: WgpuPreparedScene
    payloadBytes, stamp: uint64

  WgpuBackend* = ref object
    state*: WgpuBackendState
    runtime: NativeWgpuRuntime
    ownerThread: int
    sceneCache: seq[SceneCacheEntry]
    sceneCacheCapacity: int
    sceneCacheByteBudget, sceneCacheBytes, sceneCachePeakBytes: uint64
    sceneCacheHits, sceneCacheMisses, sceneCacheEvictions: uint64
    sceneCacheClock: uint64

var nextPreparedToken: Atomic[uint64]

proc newPreparedToken(): uint64 =
  var current = nextPreparedToken.load(moRelaxed)
  while true:
    if current == high(uint64):
      raise newException(WgpuError, "WGPU prepared-scene token space exhausted")
    let desired = current + 1'u64
    if nextPreparedToken.compareExchange(current, desired, moRelaxed,
        moRelaxed):
      return desired

proc validateBackendOwner(backend: WgpuBackend) {.inline.} =
  if not backend.isNil and backend.ownerThread != getThreadId():
    raise newException(WgpuError,
      "WGPU backend must be used from its opening thread")

func size*(prepared: WgpuPreparedScene): Size {.contractual.} =
  ## Return the immutable render target dimensions of a prepared scene.
  require:
    not prepared.isNil
  body:
    if prepared.isNil:
      raise newException(WgpuError, "prepared WGPU scene is nil")
    prepared.size

proc wgpuSceneIdentity*(scene: Scene;
                        font: Font): WgpuSceneIdentity {.contractual.} =
  ## Hash every render-relevant scene value and exact source font bytes.
  require:
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  body:
    if font.isNil:
      raise newException(WgpuError, "WGPU scene identity requires a font")
    scene.size.validate()
    sceneIdentity(scene, font)

proc prepareWgpuFrame*(scene: Scene): WgpuFrame =
  ## Extract stable semantic resource identifiers before any device is needed.
  result.size = scene.size
  result.nodeCount = scene.nodes.len
  for node in scene.nodes:
    if node.id != 0:
      let kind = case node.kind
        of snPath: wrPathMesh
        of snText: wrGlyphAtlas
        of snImage: wrImageTexture
      result.resources.add WgpuResource(id: node.id, kind: kind)

proc openWgpuBackend*(libraryPath: string;
    preparedCacheCapacity = 4;
    preparedCacheByteBudget = DefaultPreparedCacheByteBudget;
    uploadChunkBytes = DefaultUploadChunkBytes;
    managedGpuByteBudget = DefaultManagedGpuByteBudget;
    streamingRingCapacity = DefaultStreamingRingEntries;
    sceneCacheCapacity = DefaultSceneCacheEntries;
    sceneCacheByteBudget = DefaultSceneCacheByteBudget): WgpuBackend {.
    contractual.} =
  ## Open a real adapter/device/queue and a bounded prepared-mesh LRU.
  require:
    libraryPath.len > 0
    preparedCacheCapacity in 1 .. MaxPreparedCacheEntries
    preparedCacheByteBudget >= MinPreparedCacheByteBudget
    uploadChunkBytes in MinUploadChunkBytes .. MaxUploadChunkBytes
    uploadChunkBytes mod 4'u64 == 0'u64
    managedGpuByteBudget >= MinManagedGpuByteBudget
    preparedCacheByteBudget <= managedGpuByteBudget
    streamingRingCapacity in 1 .. MaxStreamingRingEntries
    sceneCacheCapacity in 1 .. MaxSceneCacheEntries
    sceneCacheByteBudget >= MinSceneCacheByteBudget
  ensure:
    not result.isNil and result.state == wbsReady
  body:
    if libraryPath.len == 0:
      raise newException(WgpuError, "wgpu-native library path is empty")
    if preparedCacheCapacity notin 1 .. MaxPreparedCacheEntries:
      raise newException(WgpuError,
        "prepared WGPU cache capacity must be in 1.." &
        $MaxPreparedCacheEntries)
    if preparedCacheByteBudget < MinPreparedCacheByteBudget:
      raise newException(WgpuError,
        "prepared WGPU cache byte budget must be at least " &
        $MinPreparedCacheByteBudget)
    if uploadChunkBytes notin MinUploadChunkBytes .. MaxUploadChunkBytes or
        uploadChunkBytes mod 4'u64 != 0:
      raise newException(WgpuError,
        "WGPU upload chunk size must be a multiple of 4 bytes in " &
        $MinUploadChunkBytes & ".." & $MaxUploadChunkBytes)
    if managedGpuByteBudget < MinManagedGpuByteBudget or
        preparedCacheByteBudget > managedGpuByteBudget:
      raise newException(WgpuError,
        "managed WGPU byte budget must be at least " &
        $MinManagedGpuByteBudget & " and contain the prepared-cache budget")
    if streamingRingCapacity notin 1 .. MaxStreamingRingEntries:
      raise newException(WgpuError,
        "WGPU streaming ring capacity must be in 1.." &
        $MaxStreamingRingEntries)
    if sceneCacheCapacity notin 1 .. MaxSceneCacheEntries:
      raise newException(WgpuError,
        "WGPU scene cache capacity must be in 1.." & $MaxSceneCacheEntries)
    if sceneCacheByteBudget < MinSceneCacheByteBudget:
      raise newException(WgpuError,
        "WGPU scene cache byte budget must be at least " &
        $MinSceneCacheByteBudget)
    result = WgpuBackend(state: wbsUnavailable, ownerThread: getThreadId(),
      sceneCacheCapacity: sceneCacheCapacity,
      sceneCacheByteBudget: sceneCacheByteBudget)
    try:
      result.runtime = openNativeWgpu(libraryPath, preparedCacheCapacity,
        preparedCacheByteBudget, uploadChunkBytes, managedGpuByteBudget,
        streamingRingCapacity)
      result.state = wbsReady
    except LibraryError as error:
      raise newException(WgpuError, error.msg)

proc close*(backend: WgpuBackend) {.contractual.} =
  ## Release queue, device, adapter, instance, and dynamic library in order.
  require:
    backend.isNil or backend.ownerThread == getThreadId()
  ensure:
    backend.isNil or backend.state == wbsUnavailable
  body:
    if backend.isNil: return
    backend.validateBackendOwner()
    backend.runtime.close()
    backend.runtime = nil
    backend.sceneCache.setLen(0)
    backend.sceneCacheBytes = 0
    backend.state = wbsUnavailable

proc waitWgpuIdle*(backend: WgpuBackend) {.contractual.} =
  ## Wait for all submitted GPU work and release streaming slots for reuse.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
  body:
    backend.validateBackendOwner()
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    try:
      backend.runtime.waitIdle()
    except LibraryError as error:
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc wgpuCapabilities*(backend: WgpuBackend = nil): WgpuCapabilities =
  ## Report runtime availability without causing implicit library loading.
  result.implementationVersion = WgpuNativeTargetVersion
  backend.validateBackendOwner()
  if not backend.isNil and backend.state == wbsReady:
    let adapter = backend.runtime.adapterCapabilities()
    result.available = true
    result.storageBuffers = true
    result.timestampQueries = backend.runtime.supportsTimestampQueries()
    result.adapterName = adapter.name
    result.adapterVendor = adapter.vendor
    result.adapterArchitecture = adapter.architecture
    result.adapterDescription = adapter.description
    result.backend = adapter.backend
    result.vendorId = adapter.vendorId
    result.deviceId = adapter.deviceId
    result.maxTextureDimension2D = adapter.maxTextureDimension2D
    result.maxBufferSize = adapter.maxBufferSize

proc wgpuDiagnostics*(backend: WgpuBackend): WgpuDiagnostics {.contractual.} =
  ## Report backend counters without exposing native WGPU handles.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
  body:
    backend.validateBackendOwner()
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    let
      cache = backend.runtime.preparedCacheStats()
      uploads = backend.runtime.uploadStats()
      textures = backend.runtime.textureUploadStats()
    WgpuDiagnostics(meshUploads: backend.runtime.meshUploadCount(),
      textureUploads: textures.uploads,
      textureUploadBytes: textures.bytes,
      uploadWriteCalls: uploads.writeCalls,
      uploadBytes: uploads.bytes,
      largestUploadWrite: uploads.largestWrite,
      uploadChunkBytes: uploads.chunkBytes,
      preparedCacheHits: cache.hits,
      preparedCacheMisses: cache.misses,
      preparedCacheEvictions: cache.evictions,
      preparedCacheBytes: cache.bytes,
      preparedCachePeakBytes: cache.peakBytes,
      preparedCacheByteBudget: cache.byteBudget,
      preparedCacheEntries: cache.entries,
      preparedCacheCapacity: cache.capacity,
      managedGpuBytes: uploads.managedBytes,
      managedGpuPeakBytes: uploads.managedPeakBytes,
      managedGpuByteBudget: uploads.managedBudget,
      streamingBufferBytes: uploads.streamingBytes,
      targetTextureBytes: uploads.targetBytes,
      readbackBufferBytes: uploads.readbackBytes,
      rasterWorkingSetPeakBytes: uploads.rasterPeakBytes,
      streamingRingEntries: uploads.ringEntries,
      streamingRingCapacity: uploads.ringCapacity,
      streamingRingRotations: uploads.ringRotations,
      streamingRingSyncs: uploads.ringSyncs,
      sceneCacheHits: backend.sceneCacheHits,
      sceneCacheMisses: backend.sceneCacheMisses,
      sceneCacheEvictions: backend.sceneCacheEvictions,
      sceneCacheBytes: backend.sceneCacheBytes,
      sceneCachePeakBytes: backend.sceneCachePeakBytes,
      sceneCacheByteBudget: backend.sceneCacheByteBudget,
      sceneCacheEntries: backend.sceneCache.len,
      sceneCacheCapacity: backend.sceneCacheCapacity)

proc readWgpuClearTarget*(backend: WgpuBackend; size: Size;
    color: Color): seq[byte] {.contractual.} =
  ## Clear an offscreen RGBA8 texture and read its unpadded pixels back.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    size.width > 0 and size.height > 0
    uint64(size.width) <= uint64(high(uint32))
    uint64(size.height) <= uint64(high(uint32))
  body:
    backend.validateBackendOwner()
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

proc wgpuMeshVertices(size: Size; mesh: VectorMesh; fill: Color): seq[float32] =
  result = newSeq[float32](mesh.vertexCount * 6)
  for i in 0 ..< mesh.vertexCount:
    let vertex = mesh.vertex(i)
    let offset = i * 6
    result[offset] = vertex.position.x * 2'f32 / float32(size.width) - 1'f32
    result[offset + 1] = 1'f32 -
      vertex.position.y * 2'f32 / float32(size.height)
    result[offset + 2] = fill.comp(0)
    result[offset + 3] = fill.comp(1)
    result[offset + 4] = fill.comp(2)
    result[offset + 5] = fill.alpha * vertex.coverage

proc readWgpuMeshTarget*(backend: WgpuBackend; size: Size; background: Color;
    mesh: VectorMesh; color: Color): seq[byte] {.contractual.} =
  ## Render one UniVector indexed triangle mesh into an RGBA8 target.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    size.width > 0 and size.height > 0
    uint64(size.width) <= uint64(high(uint32))
    uint64(size.height) <= uint64(high(uint32))
    mesh.indexCount mod 3 == 0
  ensure:
    result.len == size.width * size.height * 4
  body:
    backend.validateBackendOwner()
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
    let vertices = wgpuMeshVertices(size, mesh, fill)
    try:
      result = backend.runtime.renderMeshPixels(uint32(size.width),
        uint32(size.height), clear.comp(0), clear.comp(1), clear.comp(2),
        clear.alpha, vertices, mesh.indices)
    except LibraryError as error:
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc submitWgpuMeshTarget*(backend: WgpuBackend; size: Size;
    background: Color; mesh: VectorMesh; color: Color) {.contractual.} =
  ## Upload and enqueue one direct UniVector mesh without readback.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    size.width > 0 and size.height > 0
    uint64(size.width) <= uint64(high(uint32))
    uint64(size.height) <= uint64(high(uint32))
    mesh.indexCount mod 3 == 0
  body:
    backend.validateBackendOwner()
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
      vertices = wgpuMeshVertices(size, mesh, convertedColor.get)
    try:
      backend.runtime.submitMesh(uint32(size.width), uint32(size.height),
        clear.comp(0), clear.comp(1), clear.comp(2), clear.alpha, vertices,
        mesh.indices)
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
    uint64(scene.size.width) <= uint64(high(uint32))
    uint64(scene.size.height) <= uint64(high(uint32))
  ensure:
    not result.isNil
    result.size == scene.size
    result.vertices.len mod 6 == 0
    result.indices.len mod 3 == 0
    result.imageVertices.len mod 24 == 0
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
      uploadToken: newPreparedToken(),
      clear: [clear.comp(0), clear.comp(1), clear.comp(2), clear.alpha])
    for node in scene.nodes:
      case node.kind
      of snImage:
        if not node.image.validLayerImage:
          raise newException(WgpuError,
            "WGPU image must contain valid Gray, RGB, or RGBA pixels")
        var sourceX, sourceY, destinationX, destinationY: int
        if node.imageX < 0:
          if node.imageX <= -node.image.width: continue
          sourceX = -node.imageX
        else:
          if node.imageX >= scene.size.width: continue
          destinationX = node.imageX
        if node.imageY < 0:
          if node.imageY <= -node.image.height: continue
          sourceY = -node.imageY
        else:
          if node.imageY >= scene.size.height: continue
          destinationY = node.imageY
        let
          visibleWidth = min(node.image.width - sourceX,
            scene.size.width - destinationX)
          visibleHeight = min(node.image.height - sourceY,
            scene.size.height - destinationY)
        if visibleWidth <= 0 or visibleHeight <= 0: continue
        if visibleWidth > high(int) div visibleHeight or
            visibleWidth * visibleHeight > high(int) div 4:
          raise newException(WgpuError,
            "WGPU visible image byte size exceeds host limits")
        if uint64(result.imageVertices.len div 4) >
            uint64(high(uint32)) - 6'u64:
          raise newException(WgpuError,
            "WGPU scene exceeds uint32 image vertices")
        let
          x0 = float32(destinationX) * 2'f32 /
            float32(scene.size.width) - 1'f32
          y0 = 1'f32 - float32(destinationY) * 2'f32 /
            float32(scene.size.height)
          x1 = float32(destinationX + visibleWidth) * 2'f32 /
            float32(scene.size.width) - 1'f32
          y1 = 1'f32 - float32(destinationY + visibleHeight) * 2'f32 /
            float32(scene.size.height)
          first = uint32(result.imageVertices.len div 4)
        result.imageVertices.add [
          x0, y0, 0'f32, 0'f32, x1, y0, 1'f32, 0'f32,
          x1, y1, 1'f32, 1'f32, x0, y0, 0'f32, 0'f32,
          x1, y1, 1'f32, 1'f32, x0, y1, 0'f32, 1'f32]
        var pixels = newSeq[byte](visibleWidth * visibleHeight * 4)
        for row in 0 ..< visibleHeight:
          for column in 0 ..< visibleWidth:
            let
              pixel = row * visibleWidth + column
              source = ((sourceY + row) * node.image.width + sourceX +
                column) * node.image.channels
            case node.image.colorspace
            of uimg.csGray:
              for channel in 0 ..< 3:
                pixels[pixel * 4 + channel] = node.image.data[source]
              pixels[pixel * 4 + 3] = node.opacity
            of uimg.csRgb:
              for channel in 0 ..< 3:
                pixels[pixel * 4 + channel] = node.image.data[source + channel]
              pixels[pixel * 4 + 3] = node.opacity
            of uimg.csRgba:
              for channel in 0 ..< 3:
                pixels[pixel * 4 + channel] = node.image.data[source + channel]
              pixels[pixel * 4 + 3] = byte(
                (uint16(node.image.data[source + 3]) * uint16(node.opacity) +
                  127'u16) div 255'u16)
            else:
              raise newException(WgpuError,
                "WGPU image must use Gray, RGB, or RGBA pixels")
        result.images.add NativeImageData(width: uint32(visibleWidth),
          height: uint32(visibleHeight), pixels: pixels)
        result.commands.add NativeDrawCommand(kind: ndImage, first: first,
          count: 6, imageIndex: result.images.high)
      of snPath, snText:
        let path = case node.kind
        of snPath: node.path
        of snText:
          let layout = layoutText(textStyle(font, node.fontSize), node.text)
          layout.combinedPath(vec2(node.anchor.anchoredTextX(node.position.x,
            layout.width), node.position.y))
        of snImage:
          newPath()
        let mesh = path.preparePath().tessellateFill()
        let converted = node.color.to(tagSRGB)
        if converted.isErr:
          raise newException(WgpuError,
            "cannot convert WGPU node color to sRGB")
        let color = converted.get
        if result.vertices.len div 6 > int(high(uint32)) - mesh.vertexCount:
          raise newException(WgpuError,
            "WGPU scene exceeds uint32 vertex indices")
        let
          base = uint32(result.vertices.len div 6)
          first = uint32(result.indices.len)
        for i in 0 ..< mesh.vertexCount:
          let vertex = mesh.vertex(i)
          result.vertices.add(vertex.position.x * 2'f32 /
            float32(scene.size.width) - 1'f32)
          result.vertices.add(1'f32 - vertex.position.y * 2'f32 /
            float32(scene.size.height))
          result.vertices.add([color.comp(0), color.comp(1), color.comp(2),
            color.alpha * vertex.coverage])
        for index in mesh.indices: result.indices.add(base + index)
        if mesh.indices.len > 0:
          result.commands.add NativeDrawCommand(kind: ndMesh, first: first,
            count: uint32(mesh.indices.len))

proc validateSceneTarget(backend: WgpuBackend; scene: Scene; font: Font) =
  backend.validateBackendOwner()
  if backend.isNil or backend.state != wbsReady:
    raise newException(WgpuError, "WGPU backend is not ready")
  if font.isNil:
    raise newException(WgpuError, "WGPU scene rendering requires a font")
  scene.size.validate()
  if uint64(scene.size.width) > uint64(high(uint32)) or
      uint64(scene.size.height) > uint64(high(uint32)):
    raise newException(WgpuError, "WGPU target dimensions exceed uint32")

proc scenePayloadBytes(prepared: WgpuPreparedScene): uint64 =
  const
    VertexBytes = uint64(sizeof(float32))
    IndexBytes = uint64(sizeof(uint32))
  if uint64(prepared.vertices.len) > high(uint64) div VertexBytes or
      uint64(prepared.imageVertices.len) > high(uint64) div VertexBytes or
      uint64(prepared.indices.len) > high(uint64) div IndexBytes:
    raise newException(WgpuError, "prepared WGPU scene byte size overflow")
  let
    meshVertexBytes = uint64(prepared.vertices.len) * VertexBytes
    imageVertexBytes = uint64(prepared.imageVertices.len) * VertexBytes
  if meshVertexBytes > high(uint64) - imageVertexBytes:
    raise newException(WgpuError, "prepared WGPU scene byte size overflow")
  let vertexBytes = meshVertexBytes + imageVertexBytes
  let indexBytes = uint64(prepared.indices.len) * IndexBytes
  var imageBytes = 0'u64
  for image in prepared.images:
    if uint64(image.pixels.len) > high(uint64) - imageBytes:
      raise newException(WgpuError, "prepared WGPU scene byte size overflow")
    imageBytes += uint64(image.pixels.len)
  if vertexBytes > high(uint64) - indexBytes or
      vertexBytes + indexBytes > high(uint64) - imageBytes:
    raise newException(WgpuError, "prepared WGPU scene byte size overflow")
  vertexBytes + indexBytes + imageBytes

proc nextSceneCacheStamp(backend: WgpuBackend): uint64 =
  if backend.sceneCacheClock == high(uint64):
    raise newException(WgpuError, "WGPU scene cache clock exhausted")
  inc backend.sceneCacheClock
  backend.sceneCacheClock

proc evictSceneCacheLru(backend: WgpuBackend) =
  var oldest = 0
  for index in 1 ..< backend.sceneCache.len:
    if backend.sceneCache[index].stamp < backend.sceneCache[oldest].stamp:
      oldest = index
  backend.sceneCacheBytes -= backend.sceneCache[oldest].payloadBytes
  backend.sceneCache.delete(oldest)
  inc backend.sceneCacheEvictions

proc prepareWgpuSceneCached*(backend: WgpuBackend; scene: Scene;
                             font: Font): WgpuPreparedScene {.contractual.} =
  ## Reuse shaping and tessellation by canonical scene and font identity.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  ensure:
    not result.isNil and result.size == scene.size
  body:
    validateSceneTarget(backend, scene, font)
    let identity = sceneIdentity(scene, font)
    for entry in backend.sceneCache.mitems:
      if entry.identity == identity:
        inc backend.sceneCacheHits
        entry.stamp = backend.nextSceneCacheStamp()
        return entry.prepared

    inc backend.sceneCacheMisses
    result = scene.prepareWgpuScene(font)
    let payloadBytes = result.scenePayloadBytes()
    if payloadBytes > backend.sceneCacheByteBudget:
      return
    while backend.sceneCache.len >= backend.sceneCacheCapacity or
        backend.sceneCacheBytes > backend.sceneCacheByteBudget - payloadBytes:
      backend.evictSceneCacheLru()
    backend.sceneCache.add SceneCacheEntry(identity: identity,
      prepared: result, payloadBytes: payloadBytes,
      stamp: backend.nextSceneCacheStamp())
    backend.sceneCacheBytes += payloadBytes
    if backend.sceneCacheBytes > backend.sceneCachePeakBytes:
      backend.sceneCachePeakBytes = backend.sceneCacheBytes

proc clearWgpuSceneCache*(backend: WgpuBackend) {.contractual.} =
  ## Release all host-side automatically prepared scenes; counters continue.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
  ensure:
    backend.sceneCache.len == 0 and backend.sceneCacheBytes == 0
  body:
    backend.validateBackendOwner()
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    backend.sceneCache.setLen(0)
    backend.sceneCacheBytes = 0

proc renderWgpuPrepared*(backend: WgpuBackend;
                         prepared: WgpuPreparedScene): seq[
                             byte] {.contractual.} =
  ## Upload, submit and read one previously prepared scene as RGBA8.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    not prepared.isNil
  ensure:
    result.len == prepared.size.width * prepared.size.height * 4
  body:
    backend.validateBackendOwner()
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    if prepared.isNil:
      raise newException(WgpuError, "prepared WGPU scene is nil")
    try:
      result = backend.runtime.renderPreparedScenePixels(
        uint32(prepared.size.width),
        uint32(prepared.size.height), prepared.clear[0], prepared.clear[1],
        prepared.clear[2], prepared.clear[3], prepared.vertices,
        prepared.indices, prepared.imageVertices, prepared.images,
        prepared.commands, prepared.uploadToken)
    except LibraryError as error:
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc submitWgpuPrepared*(backend: WgpuBackend;
                         prepared: WgpuPreparedScene) {.contractual.} =
  ## Upload and enqueue one previously prepared scene without readback.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    not prepared.isNil
  body:
    backend.validateBackendOwner()
    if backend.isNil or backend.state != wbsReady:
      raise newException(WgpuError, "WGPU backend is not ready")
    if prepared.isNil:
      raise newException(WgpuError, "prepared WGPU scene is nil")
    try:
      backend.runtime.submitPreparedScene(uint32(prepared.size.width),
        uint32(prepared.size.height), prepared.clear[0], prepared.clear[1],
        prepared.clear[2], prepared.clear[3], prepared.vertices,
        prepared.indices, prepared.imageVertices, prepared.images,
        prepared.commands, prepared.uploadToken)
    except LibraryError as error:
      if backend.runtime.deviceLostReason() != 0'u32:
        backend.state = wbsDeviceLost
      raise newException(WgpuError, error.msg)

proc renderWgpuScene*(backend: WgpuBackend; scene: Scene;
                      font: Font): seq[byte] {.contractual.} =
  ## Prepare, submit and read one retained scene back as unpadded RGBA8.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  ensure:
    result.len == scene.size.width * scene.size.height * 4
  body:
    validateSceneTarget(backend, scene, font)
    backend.renderWgpuPrepared(backend.prepareWgpuSceneCached(scene, font))

proc submitWgpuScene*(backend: WgpuBackend; scene: Scene;
                      font: Font) {.contractual.} =
  ## Prepare and enqueue one retained scene without a GPU-to-CPU transfer.
  require:
    not backend.isNil and backend.state == wbsReady and
      backend.ownerThread == getThreadId()
    not font.isNil
    scene.size.width > 0 and scene.size.height > 0
  body:
    validateSceneTarget(backend, scene, font)
    backend.submitWgpuPrepared(backend.prepareWgpuSceneCached(scene, font))
