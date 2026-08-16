# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Minimal dynamically loaded wgpu-native 29 ABI used by the optional backend.
import std/[atomics, dynlib, os]

type
  WgpuStringView {.bycopy.} = object
    data: cstring
    length: csize_t

  WgpuAdapterInfo {.bycopy.} = object
    nextInChain: pointer
    vendor, architecture, device, description: WgpuStringView
    backendType, adapterType, vendorId, deviceId: uint32
    subgroupMinSize, subgroupMaxSize: uint32

  WgpuLimits {.bycopy.} = object
    nextInChain: pointer
    maxTextureDimension1D, maxTextureDimension2D, maxTextureDimension3D: uint32
    maxTextureArrayLayers, maxBindGroups: uint32
    maxBindGroupsPlusVertexBuffers, maxBindingsPerBindGroup: uint32
    maxDynamicUniformBuffersPerPipelineLayout: uint32
    maxDynamicStorageBuffersPerPipelineLayout: uint32
    maxSampledTexturesPerShaderStage, maxSamplersPerShaderStage: uint32
    maxStorageBuffersPerShaderStage, maxStorageTexturesPerShaderStage: uint32
    maxUniformBuffersPerShaderStage: uint32
    maxUniformBufferBindingSize, maxStorageBufferBindingSize: uint64
    minUniformBufferOffsetAlignment, minStorageBufferOffsetAlignment: uint32
    maxVertexBuffers: uint32
    maxBufferSize: uint64
    maxVertexAttributes, maxVertexBufferArrayStride: uint32
    maxInterStageShaderVariables, maxColorAttachments: uint32
    maxColorAttachmentBytesPerSample, maxComputeWorkgroupStorageSize: uint32
    maxComputeInvocationsPerWorkgroup: uint32
    maxComputeWorkgroupSizeX, maxComputeWorkgroupSizeY: uint32
    maxComputeWorkgroupSizeZ, maxComputeWorkgroupsPerDimension: uint32
    maxImmediateSize: uint32

  NativeAdapterCapabilities* = object
    name*, vendor*, architecture*, description*, backend*: string
    vendorId*, deviceId*, maxTextureDimension2D*: uint32
    maxBufferSize*: uint64

  WgpuFuture {.bycopy.} = object
    id: uint64

  WgpuExtent3D {.bycopy.} = object
    width, height, depthOrArrayLayers: uint32

  WgpuColor {.bycopy.} = object
    r, g, b, a: float64

  WgpuTextureDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    usage: uint64
    dimension: uint32
    size: WgpuExtent3D
    format, mipLevelCount, sampleCount: uint32
    viewFormatCount: csize_t
    viewFormats: ptr uint32

  WgpuRenderPassColorAttachment {.bycopy.} = object
    nextInChain, view: pointer
    depthSlice: uint32
    resolveTarget: pointer
    loadOp, storeOp: uint32
    clearValue: WgpuColor

  WgpuRenderPassDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    colorAttachmentCount: csize_t
    colorAttachments: ptr WgpuRenderPassColorAttachment
    depthStencilAttachment, occlusionQuerySet, timestampWrites: pointer

  WgpuBufferDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    usage, size: uint64
    mappedAtCreation: uint32

  WgpuOrigin3D {.bycopy.} = object
    x, y, z: uint32

  WgpuTexelCopyBufferLayout {.bycopy.} = object
    offset: uint64
    bytesPerRow, rowsPerImage: uint32

  WgpuTexelCopyBufferInfo {.bycopy.} = object
    layout: WgpuTexelCopyBufferLayout
    buffer: pointer

  WgpuTexelCopyTextureInfo {.bycopy.} = object
    texture: pointer
    mipLevel: uint32
    origin: WgpuOrigin3D
    aspect: uint32

  WgpuChainedStruct {.bycopy.} = object
    next: pointer
    sType: uint32

  WgpuShaderSourceWgsl {.bycopy.} = object
    chain: WgpuChainedStruct
    code: WgpuStringView

  WgpuShaderModuleDescriptor {.bycopy.} = object
    nextInChain: ptr WgpuChainedStruct
    label: WgpuStringView

  WgpuSamplerDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    addressModeU, addressModeV, addressModeW: uint32
    magFilter, minFilter, mipmapFilter: uint32
    lodMinClamp, lodMaxClamp: float32
    compare: uint32
    maxAnisotropy: uint16

  WgpuBindGroupEntry {.bycopy.} = object
    nextInChain: pointer
    binding: uint32
    buffer: pointer
    offset, size: uint64
    sampler, textureView: pointer

  WgpuBindGroupDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    layout: pointer
    entryCount: csize_t
    entries: ptr WgpuBindGroupEntry

  WgpuVertexAttribute {.bycopy.} = object
    nextInChain: pointer
    format: uint32
    offset: uint64
    shaderLocation: uint32

  WgpuVertexBufferLayout {.bycopy.} = object
    nextInChain: pointer
    stepMode: uint32
    arrayStride: uint64
    attributeCount: csize_t
    attributes: ptr WgpuVertexAttribute

  WgpuVertexState {.bycopy.} = object
    nextInChain, module: pointer
    entryPoint: WgpuStringView
    constantCount: csize_t
    constants: pointer
    bufferCount: csize_t
    buffers: ptr WgpuVertexBufferLayout

  WgpuBlendComponent {.bycopy.} = object
    operation, srcFactor, dstFactor: uint32

  WgpuBlendState {.bycopy.} = object
    color, alpha: WgpuBlendComponent

  WgpuColorTargetState {.bycopy.} = object
    nextInChain: pointer
    format: uint32
    blend: ptr WgpuBlendState
    writeMask: uint64

  WgpuFragmentState {.bycopy.} = object
    nextInChain, module: pointer
    entryPoint: WgpuStringView
    constantCount: csize_t
    constants: pointer
    targetCount: csize_t
    targets: ptr WgpuColorTargetState

  WgpuPrimitiveState {.bycopy.} = object
    nextInChain: pointer
    topology, stripIndexFormat, frontFace, cullMode, unclippedDepth: uint32

  WgpuMultisampleState {.bycopy.} = object
    nextInChain: pointer
    count, mask, alphaToCoverageEnabled: uint32

  WgpuRenderPipelineDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    layout: pointer
    vertex: WgpuVertexState
    primitive: WgpuPrimitiveState
    depthStencil: pointer
    multisample: WgpuMultisampleState
    fragment: ptr WgpuFragmentState

  WgpuRequestDeviceCallback = proc(status: uint32; device: pointer;
      message: WgpuStringView; userdata1, userdata2: pointer) {.cdecl.}

  WgpuRequestDeviceCallbackInfo {.bycopy.} = object
    nextInChain: pointer
    mode: uint32
    callback: WgpuRequestDeviceCallback
    userdata1, userdata2: pointer

  WgpuBufferMapCallback = proc(status: uint32; message: WgpuStringView;
      userdata1, userdata2: pointer) {.cdecl.}

  WgpuBufferMapCallbackInfo {.bycopy.} = object
    nextInChain: pointer
    mode: uint32
    callback: WgpuBufferMapCallback
    userdata1, userdata2: pointer

  WgpuDeviceLostCallback = proc(device: pointer; reason: uint32;
      message: WgpuStringView; userdata1, userdata2: pointer) {.cdecl.}

  WgpuUncapturedErrorCallback = proc(device: pointer; errorType: uint32;
      message: WgpuStringView; userdata1, userdata2: pointer) {.cdecl.}

  WgpuDeviceLostCallbackInfo {.bycopy.} = object
    nextInChain: pointer
    mode: uint32
    callback: WgpuDeviceLostCallback
    userdata1, userdata2: pointer

  WgpuUncapturedErrorCallbackInfo {.bycopy.} = object
    nextInChain: pointer
    callback: WgpuUncapturedErrorCallback
    userdata1, userdata2: pointer

  WgpuQueueDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView

  WgpuDeviceDescriptor {.bycopy.} = object
    nextInChain: pointer
    label: WgpuStringView
    requiredFeatureCount: csize_t
    requiredFeatures, requiredLimits: pointer
    defaultQueue: WgpuQueueDescriptor
    deviceLostCallbackInfo: WgpuDeviceLostCallbackInfo
    uncapturedErrorCallbackInfo: WgpuUncapturedErrorCallbackInfo

  CreateInstanceProc = proc(descriptor: pointer): pointer {.cdecl.}
  EnumerateAdaptersProc = proc(instance, options: pointer;
      adapters: ptr pointer): csize_t {.cdecl.}
  ProcessEventsProc = proc(instance: pointer) {.cdecl.}
  RequestDeviceProc = proc(adapter, descriptor: pointer;
      callbackInfo: WgpuRequestDeviceCallbackInfo): WgpuFuture {.cdecl.}
  HasFeatureProc = proc(adapter: pointer; feature: uint32): uint32 {.cdecl.}
  GetAdapterInfoProc = proc(adapter: pointer;
      info: ptr WgpuAdapterInfo): uint32 {.cdecl.}
  FreeAdapterInfoProc = proc(info: WgpuAdapterInfo) {.cdecl.}
  GetAdapterLimitsProc = proc(adapter: pointer;
      limits: ptr WgpuLimits): uint32 {.cdecl.}
  GetQueueProc = proc(device: pointer): pointer {.cdecl.}
  GetVersionProc = proc(): uint32 {.cdecl.}
  ReleaseProc = proc(handle: pointer) {.cdecl.}
  CreateTextureProc = proc(device: pointer;
      descriptor: ptr WgpuTextureDescriptor): pointer {.cdecl.}
  CreateTextureViewProc = proc(texture, descriptor: pointer): pointer {.cdecl.}
  CreateCommandEncoderProc = proc(device,
      descriptor: pointer): pointer {.cdecl.}
  BeginRenderPassProc = proc(encoder: pointer;
      descriptor: ptr WgpuRenderPassDescriptor): pointer {.cdecl.}
  EndRenderPassProc = proc(renderPass: pointer) {.cdecl.}
  FinishCommandEncoderProc = proc(encoder,
      descriptor: pointer): pointer {.cdecl.}
  SubmitForIndexProc = proc(queue: pointer; count: csize_t;
      commands: ptr pointer): uint64 {.cdecl.}
  CreateBufferProc = proc(device: pointer;
      descriptor: ptr WgpuBufferDescriptor): pointer {.cdecl.}
  CopyTextureToBufferProc = proc(encoder: pointer;
      source: ptr WgpuTexelCopyTextureInfo;
      destination: ptr WgpuTexelCopyBufferInfo;
      copySize: ptr WgpuExtent3D) {.cdecl.}
  MapBufferProc = proc(buffer: pointer; mode: uint64; offset, size: csize_t;
      callbackInfo: WgpuBufferMapCallbackInfo): WgpuFuture {.cdecl.}
  GetMappedRangeProc = proc(buffer: pointer; offset,
      size: csize_t): pointer {.cdecl.}
  UnmapBufferProc = proc(buffer: pointer) {.cdecl.}
  CreateShaderModuleProc = proc(device: pointer;
      descriptor: ptr WgpuShaderModuleDescriptor): pointer {.cdecl.}
  CreateRenderPipelineProc = proc(device: pointer;
      descriptor: ptr WgpuRenderPipelineDescriptor): pointer {.cdecl.}
  WriteBufferProc = proc(queue, buffer: pointer; offset: uint64; data: pointer;
      size: csize_t) {.cdecl.}
  SetPipelineProc = proc(renderPass, pipeline: pointer) {.cdecl.}
  SetVertexBufferProc = proc(renderPass: pointer; slot: uint32; buffer: pointer;
      offset, size: uint64) {.cdecl.}
  SetIndexBufferProc = proc(renderPass, buffer: pointer; format: uint32;
      offset, size: uint64) {.cdecl.}
  DrawIndexedProc = proc(renderPass: pointer; indexCount, instanceCount,
      firstIndex: uint32; baseVertex: int32; firstInstance: uint32) {.cdecl.}
  DrawProc = proc(renderPass: pointer; vertexCount, instanceCount,
      firstVertex, firstInstance: uint32) {.cdecl.}
  CreateSamplerProc = proc(device: pointer;
      descriptor: ptr WgpuSamplerDescriptor): pointer {.cdecl.}
  GetBindGroupLayoutProc = proc(pipeline: pointer; index: uint32): pointer {.
      cdecl.}
  CreateBindGroupProc = proc(device: pointer;
      descriptor: ptr WgpuBindGroupDescriptor): pointer {.cdecl.}
  SetBindGroupProc = proc(renderPass: pointer; groupIndex: uint32;
      bindGroup: pointer; dynamicOffsetCount: csize_t;
      dynamicOffsets: ptr uint32) {.cdecl.}
  WriteTextureProc = proc(queue: pointer;
      destination: ptr WgpuTexelCopyTextureInfo; data: pointer;
      dataSize: csize_t; layout: ptr WgpuTexelCopyBufferLayout;
      writeSize: ptr WgpuExtent3D) {.cdecl.}
  PollDeviceProc = proc(device: pointer; wait: uint32;
      submissionIndex: pointer): uint32 {.cdecl.}

  DeviceRequest = object
    status: Atomic[uint32]
    device: pointer

  DeviceEvents = object
    lostReason, errorType, mapStatus: Atomic[uint32]

  PreparedMeshBuffers = object
    token, lastUse: uint64
    vertexBuffer, indexBuffer: pointer
    vertexCapacity, indexCapacity: uint64
    vertexSize, indexSize: uint64

  StreamingMeshBuffers = object
    vertexBuffer, indexBuffer: pointer
    vertexCapacity, indexCapacity, submissionIndex: uint64

  NativeWgpuRuntime* = ref object
    library: LibHandle
    instance, adapter, device, queue: pointer
    meshShader, meshPipeline: pointer
    imageShader, imagePipeline, imageSampler: pointer
    targetTexture, targetView: pointer
    readbackBuffer: pointer
    targetWidth, targetHeight: uint32
    readbackCapacity: uint64
    preparedCacheCapacity: int
    preparedCacheByteBudget, preparedCacheBytes: uint64
    preparedCachePeakBytes: uint64
    uploadChunkBytes, uploadWriteCalls, uploadBytes: uint64
    largestUploadWrite: uint64
    managedGpuByteBudget, managedGpuPeakBytes, targetTextureBytes: uint64
    transientRasterBytes, transientRasterPeakBytes: uint64
    streamingRingCapacity, streamingRingCursor: int
    streamingRing: seq[StreamingMeshBuffers]
    streamingRingRotations, streamingRingSyncs: uint64
    preparedMeshes: seq[PreparedMeshBuffers]
    preparedUseClock: uint64
    meshUploadCount, textureUploadCount, textureUploadBytes: uint64
    preparedCacheHits, preparedCacheMisses: uint64
    preparedCacheEvictions: uint64
    events: ptr DeviceEvents
    getVersion: GetVersionProc
    hasFeature: HasFeatureProc
    processEvents: ProcessEventsProc
    pollDevice: PollDeviceProc
    destroyDevice: ReleaseProc
    releaseInstance, releaseAdapter, releaseDevice, releaseQueue: ReleaseProc
    releaseShader, releasePipeline, releaseSampler: ReleaseProc
    releaseBindGroup, releaseBindGroupLayout: ReleaseProc
    releaseTexture, releaseView, releaseBuffer: ReleaseProc
    adapterCapabilities: NativeAdapterCapabilities

  NativeDrawKind* = enum
    ndMesh
    ndImage

  NativeDrawCommand* = object
    kind*: NativeDrawKind
    first*, count*: uint32
    imageIndex*: int

  NativeImageData* = object
    width*, height*: uint32
    pixels*: seq[byte]

const
  CallbackAllowProcessEvents = 2'u32
  RequestDeviceSuccess = 1'u32
  FeatureTimestampQuery = 9'u32
  TextureUsageCopySrc = 0x1'u64
  TextureUsageCopyDst = 0x2'u64
  TextureUsageBinding = 0x4'u64
  TextureUsageRenderAttachment = 0x10'u64
  TextureDimension2D = 2'u32
  TextureFormatRgba8Unorm = 0x16'u32
  LoadOpClear = 2'u32
  StoreOpStore = 1'u32
  BufferUsageMapRead = 0x1'u64
  BufferUsageCopyDst = 0x8'u64
  MapModeRead = 0x1'u64
  MapSuccess = 1'u32
  TextureAspectAll = 1'u32
  BufferUsageIndex = 0x10'u64
  BufferUsageVertex = 0x20'u64
  STypeShaderSourceWgsl = 2'u32
  VertexFormatFloat32x2 = 0x1D'u32
  VertexFormatFloat32x4 = 0x1F'u32
  VertexStepModeVertex = 1'u32
  PrimitiveTopologyTriangleList = 4'u32
  FrontFaceCcw = 1'u32
  CullModeNone = 1'u32
  IndexFormatUint32 = 2'u32
  BlendOperationAdd = 1'u32
  BlendFactorOne = 2'u32
  BlendFactorSrcAlpha = 5'u32
  BlendFactorOneMinusSrcAlpha = 6'u32
  ColorWriteMaskAll = 0xF'u64
  AddressModeClampToEdge = 1'u32
  FilterModeLinear = 2'u32
  MipmapFilterModeNearest = 1'u32
  StatusSuccess = 1'u32

proc loadSymbol[T](library: LibHandle; name: string): T =
  let address = library.symAddr(name)
  if address == nil:
    raise newException(LibraryError, "wgpu-native symbol missing: " & name)
  cast[T](address)

proc grownCapacity(current, required: uint64): uint64 =
  result = max(current, 256'u64)
  while result < required:
    if result > high(uint64) div 2: return required
    result *= 2

proc receiveDevice(status: uint32; device: pointer; message: WgpuStringView;
                   userdata1, userdata2: pointer) {.cdecl.} =
  discard message
  discard userdata2
  let request = cast[ptr DeviceRequest](userdata1)
  request.device = device
  request.status.store(status, moRelease)

proc receiveMap(status: uint32; message: WgpuStringView;
                userdata1, userdata2: pointer) {.cdecl.} =
  discard message
  discard userdata2
  cast[ptr DeviceEvents](userdata1).mapStatus.store(status, moRelease)

proc receiveDeviceLost(device: pointer; reason: uint32; message: WgpuStringView;
                       userdata1, userdata2: pointer) {.cdecl.} =
  discard device
  discard message
  discard userdata2
  cast[ptr DeviceEvents](userdata1).lostReason.store(reason, moRelease)

proc receiveUncapturedError(device: pointer; errorType: uint32;
                            message: WgpuStringView;
                            userdata1, userdata2: pointer) {.cdecl.} =
  discard device
  discard message
  discard userdata2
  cast[ptr DeviceEvents](userdata1).errorType.store(errorType, moRelease)

proc close*(runtime: NativeWgpuRuntime) =
  if runtime.isNil: return
  if runtime.device != nil and runtime.pollDevice != nil:
    discard runtime.pollDevice(runtime.device, 1'u32, nil)
  if runtime.processEvents != nil and runtime.instance != nil:
    runtime.processEvents(runtime.instance)
  if runtime.readbackBuffer != nil and runtime.releaseBuffer != nil:
    runtime.releaseBuffer(runtime.readbackBuffer)
    runtime.readbackBuffer = nil
  if runtime.releaseBuffer != nil:
    for entry in runtime.preparedMeshes.mitems:
      if entry.indexBuffer != nil:
        runtime.releaseBuffer(entry.indexBuffer)
        entry.indexBuffer = nil
      if entry.vertexBuffer != nil:
        runtime.releaseBuffer(entry.vertexBuffer)
        entry.vertexBuffer = nil
  runtime.preparedMeshes.setLen(0)
  runtime.preparedCacheBytes = 0
  if runtime.releaseBuffer != nil:
    for slot in runtime.streamingRing.mitems:
      if slot.indexBuffer != nil:
        runtime.releaseBuffer(slot.indexBuffer)
        slot.indexBuffer = nil
      if slot.vertexBuffer != nil:
        runtime.releaseBuffer(slot.vertexBuffer)
        slot.vertexBuffer = nil
  runtime.streamingRing.setLen(0)
  if runtime.targetView != nil and runtime.releaseView != nil:
    runtime.releaseView(runtime.targetView)
    runtime.targetView = nil
  if runtime.targetTexture != nil and runtime.releaseTexture != nil:
    runtime.releaseTexture(runtime.targetTexture)
    runtime.targetTexture = nil
  runtime.targetTextureBytes = 0
  if runtime.meshPipeline != nil and runtime.releasePipeline != nil:
    runtime.releasePipeline(runtime.meshPipeline)
    runtime.meshPipeline = nil
  if runtime.meshShader != nil and runtime.releaseShader != nil:
    runtime.releaseShader(runtime.meshShader)
    runtime.meshShader = nil
  if runtime.imageSampler != nil and runtime.releaseSampler != nil:
    runtime.releaseSampler(runtime.imageSampler)
    runtime.imageSampler = nil
  if runtime.imagePipeline != nil and runtime.releasePipeline != nil:
    runtime.releasePipeline(runtime.imagePipeline)
    runtime.imagePipeline = nil
  if runtime.imageShader != nil and runtime.releaseShader != nil:
    runtime.releaseShader(runtime.imageShader)
    runtime.imageShader = nil
  if runtime.queue != nil and runtime.releaseQueue != nil:
    runtime.releaseQueue(runtime.queue)
    runtime.queue = nil
  if runtime.device != nil and runtime.releaseDevice != nil:
    if runtime.destroyDevice != nil:
      runtime.destroyDevice(runtime.device)
    if runtime.processEvents != nil and runtime.instance != nil:
      runtime.processEvents(runtime.instance)
    runtime.releaseDevice(runtime.device)
    runtime.device = nil
    if runtime.processEvents != nil and runtime.instance != nil:
      runtime.processEvents(runtime.instance)
  if runtime.events != nil:
    deallocShared(runtime.events)
    runtime.events = nil
  if runtime.adapter != nil and runtime.releaseAdapter != nil:
    runtime.releaseAdapter(runtime.adapter)
    runtime.adapter = nil
  if runtime.instance != nil and runtime.releaseInstance != nil:
    runtime.releaseInstance(runtime.instance)
    runtime.instance = nil
  if runtime.library != nil:
    runtime.library.unloadLib()
    runtime.library = nil

proc toString(view: WgpuStringView): string =
  if view.data == nil or view.length == 0: return ""
  if uint64(view.length) > uint64(high(int)):
    raise newException(LibraryError, "wgpu-native returned an oversized string")
  result = newString(int(view.length))
  copyMem(addr result[0], view.data, result.len)

proc backendName(value: uint32): string =
  case value
  of 1: "null"
  of 2: "webgpu"
  of 3: "d3d11"
  of 4: "d3d12"
  of 5: "metal"
  of 6: "vulkan"
  of 7: "opengl"
  of 8: "opengles"
  else: "unknown"

proc openNativeWgpu*(libraryPath: string;
                     preparedCacheCapacity: int;
                     preparedCacheByteBudget: uint64;
                     uploadChunkBytes: uint64;
                     managedGpuByteBudget: uint64;
                     streamingRingCapacity: int): NativeWgpuRuntime =
  ## Load wgpu-native, select its first adapter, and create a real device/queue.
  if preparedCacheCapacity <= 0:
    raise newException(LibraryError,
      "prepared WGPU cache capacity must be positive")
  if preparedCacheByteBudget < 512'u64:
    raise newException(LibraryError,
      "prepared WGPU cache byte budget must be at least 512")
  if uploadChunkBytes < 4'u64 or
      uploadChunkBytes > 64'u64 * 1024'u64 * 1024'u64 or
      uploadChunkBytes mod 4'u64 != 0:
    raise newException(LibraryError,
      "WGPU upload chunk size must be a multiple of 4 bytes in 4..67108864")
  if managedGpuByteBudget < 1024'u64 or
      preparedCacheByteBudget > managedGpuByteBudget:
    raise newException(LibraryError,
      "managed WGPU byte budget must contain the prepared-cache budget")
  if streamingRingCapacity notin 1 .. 8:
    raise newException(LibraryError,
      "WGPU streaming ring capacity must be in 1..8")
  let library = loadLib(libraryPath)
  if library == nil:
    raise newException(LibraryError, "cannot load wgpu-native: " & libraryPath)
  result = NativeWgpuRuntime(library: library,
    preparedCacheCapacity: preparedCacheCapacity,
    preparedCacheByteBudget: preparedCacheByteBudget,
    uploadChunkBytes: uploadChunkBytes,
    managedGpuByteBudget: managedGpuByteBudget,
    streamingRingCapacity: streamingRingCapacity,
    streamingRing: newSeq[StreamingMeshBuffers](streamingRingCapacity))
  try:
    let
      createInstance = loadSymbol[CreateInstanceProc](library,
          "wgpuCreateInstance")
      enumerateAdapters = loadSymbol[EnumerateAdaptersProc](library,
          "wgpuInstanceEnumerateAdapters")
      requestDevice = loadSymbol[RequestDeviceProc](library,
          "wgpuAdapterRequestDevice")
      processEvents = loadSymbol[ProcessEventsProc](library,
          "wgpuInstanceProcessEvents")
      getQueue = loadSymbol[GetQueueProc](library, "wgpuDeviceGetQueue")
      getAdapterInfo = loadSymbol[GetAdapterInfoProc](library,
          "wgpuAdapterGetInfo")
      freeAdapterInfo = loadSymbol[FreeAdapterInfoProc](library,
          "wgpuAdapterInfoFreeMembers")
      getAdapterLimits = loadSymbol[GetAdapterLimitsProc](library,
          "wgpuAdapterGetLimits")
    result.getVersion = loadSymbol[GetVersionProc](library, "wgpuGetVersion")
    result.processEvents = processEvents
    result.pollDevice = loadSymbol[PollDeviceProc](library, "wgpuDevicePoll")
    result.destroyDevice = loadSymbol[ReleaseProc](library,
        "wgpuDeviceDestroy")
    result.hasFeature = loadSymbol[HasFeatureProc](library,
        "wgpuAdapterHasFeature")
    result.releaseInstance = loadSymbol[ReleaseProc](library,
        "wgpuInstanceRelease")
    result.releaseAdapter = loadSymbol[ReleaseProc](library,
        "wgpuAdapterRelease")
    result.releaseDevice = loadSymbol[ReleaseProc](library,
        "wgpuDeviceRelease")
    result.releaseQueue = loadSymbol[ReleaseProc](library, "wgpuQueueRelease")

    result.events = cast[ptr DeviceEvents](allocShared0(sizeof(DeviceEvents)))
    if result.events == nil:
      raise newException(LibraryError, "cannot allocate WGPU device event state")

    result.instance = createInstance(nil)
    if result.instance == nil:
      raise newException(LibraryError, "wgpu-native did not create an instance")
    let adapterCount = enumerateAdapters(result.instance, nil, nil)
    if adapterCount == 0:
      raise newException(LibraryError, "wgpu-native found no adapter")
    var adapters = newSeq[pointer](int(adapterCount))
    if enumerateAdapters(result.instance, nil, addr adapters[0]) != adapterCount:
      raise newException(LibraryError, "wgpu-native adapter list changed")
    result.adapter = adapters[0]
    for i in 1 ..< adapters.len:
      result.releaseAdapter(adapters[i])

    var adapterInfo: WgpuAdapterInfo
    if getAdapterInfo(result.adapter, addr adapterInfo) != StatusSuccess:
      raise newException(LibraryError, "wgpu-native adapter info failed")
    try:
      result.adapterCapabilities.name = adapterInfo.device.toString()
      result.adapterCapabilities.vendor = adapterInfo.vendor.toString()
      result.adapterCapabilities.architecture = adapterInfo.architecture.toString()
      result.adapterCapabilities.description = adapterInfo.description.toString()
      result.adapterCapabilities.backend = backendName(adapterInfo.backendType)
      result.adapterCapabilities.vendorId = adapterInfo.vendorId
      result.adapterCapabilities.deviceId = adapterInfo.deviceId
    finally:
      freeAdapterInfo(adapterInfo)
    var limits: WgpuLimits
    if getAdapterLimits(result.adapter, addr limits) != StatusSuccess:
      raise newException(LibraryError, "wgpu-native adapter limits failed")
    result.adapterCapabilities.maxTextureDimension2D =
      limits.maxTextureDimension2D
    result.adapterCapabilities.maxBufferSize = limits.maxBufferSize

    let request = cast[ptr DeviceRequest](allocShared0(sizeof(DeviceRequest)))
    if request == nil:
      raise newException(LibraryError, "cannot allocate WGPU request state")
    let emptyLabel = WgpuStringView(data: "".cstring, length: 0)
    var deviceDescriptor = WgpuDeviceDescriptor(label: emptyLabel,
      defaultQueue: WgpuQueueDescriptor(label: emptyLabel),
      deviceLostCallbackInfo: WgpuDeviceLostCallbackInfo(
        mode: CallbackAllowProcessEvents, callback: receiveDeviceLost,
        userdata1: result.events),
      uncapturedErrorCallbackInfo: WgpuUncapturedErrorCallbackInfo(
        callback: receiveUncapturedError, userdata1: result.events))
    discard requestDevice(result.adapter, addr deviceDescriptor,
        WgpuRequestDeviceCallbackInfo(mode: CallbackAllowProcessEvents,
          callback: receiveDevice, userdata1: request))
    var attempts = 0
    while request.status.load(moAcquire) == 0'u32 and attempts < 10_000:
      processEvents(result.instance)
      inc attempts
      sleep(1)
    let
      requestStatus = request.status.load(moAcquire)
      requestedDevice = request.device
    deallocShared(request)
    if requestStatus == 0'u32:
      raise newException(LibraryError, "wgpu-native device request timed out")
    if requestStatus != RequestDeviceSuccess or requestedDevice == nil:
      raise newException(LibraryError, "wgpu-native did not create a device")
    result.device = requestedDevice
    result.queue = getQueue(result.device)
    if result.queue == nil:
      raise newException(LibraryError, "wgpu-native did not create a queue")
  except:
    result.close()
    raise

proc implementationVersion*(runtime: NativeWgpuRuntime): uint32 =
  if runtime.isNil or runtime.getVersion == nil: 0'u32
  else: runtime.getVersion()

proc supportsTimestampQueries*(runtime: NativeWgpuRuntime): bool =
  not runtime.isNil and runtime.adapter != nil and runtime.hasFeature != nil and
    runtime.hasFeature(runtime.adapter, FeatureTimestampQuery) != 0

proc adapterCapabilities*(runtime: NativeWgpuRuntime): NativeAdapterCapabilities =
  if runtime.isNil or runtime.adapter == nil:
    raise newException(LibraryError, "wgpu-native runtime is not ready")
  runtime.adapterCapabilities

proc deviceLostReason*(runtime: NativeWgpuRuntime): uint32 =
  if runtime.isNil or runtime.events == nil: 0'u32
  else: runtime.events.lostReason.load(moAcquire)

proc waitIdle*(runtime: NativeWgpuRuntime) =
  if runtime.isNil or runtime.device == nil or runtime.pollDevice == nil:
    raise newException(LibraryError, "wgpu-native runtime is not ready")
  discard runtime.pollDevice(runtime.device, 1'u32, nil)
  for slot in runtime.streamingRing.mitems: slot.submissionIndex = 0
  if runtime.deviceLostReason() != 0'u32:
    raise newException(LibraryError, "wgpu-native device was lost")

proc takeUncapturedError*(runtime: NativeWgpuRuntime): uint32 =
  if runtime.isNil or runtime.events == nil: result = 0'u32
  else: result = runtime.events.errorType.exchange(0'u32, moAcquireRelease)

proc meshUploadCount*(runtime: NativeWgpuRuntime): uint64 =
  ## Return vertex/index upload pairs issued through the queue.
  if runtime.isNil: 0'u64 else: runtime.meshUploadCount

proc textureUploadStats*(runtime: NativeWgpuRuntime): tuple[
    uploads, bytes: uint64] =
  if runtime.isNil: (0'u64, 0'u64)
  else: (runtime.textureUploadCount, runtime.textureUploadBytes)

proc preparedCacheStats*(runtime: NativeWgpuRuntime): tuple[
    hits, misses, evictions, bytes, peakBytes, byteBudget: uint64;
    entries, capacity: int] =
  if runtime.isNil:
    return (0'u64, 0'u64, 0'u64, 0'u64, 0'u64, 0'u64, 0, 0)
  (runtime.preparedCacheHits, runtime.preparedCacheMisses,
    runtime.preparedCacheEvictions, runtime.preparedCacheBytes,
    runtime.preparedCachePeakBytes, runtime.preparedCacheByteBudget,
    runtime.preparedMeshes.len, runtime.preparedCacheCapacity)

proc uploadStats*(runtime: NativeWgpuRuntime): tuple[
    writeCalls, bytes, largestWrite, chunkBytes: uint64;
    managedBytes, managedPeakBytes, managedBudget: uint64;
    streamingBytes, targetBytes, readbackBytes: uint64;
    rasterPeakBytes: uint64;
    ringRotations, ringSyncs: uint64; ringEntries, ringCapacity: int] =
  if runtime.isNil:
    return (0'u64, 0'u64, 0'u64, 0'u64, 0'u64, 0'u64, 0'u64,
      0'u64, 0'u64, 0'u64, 0'u64, 0'u64, 0'u64, 0, 0)
  var streamingBytes = 0'u64
  var ringEntries = 0
  for slot in runtime.streamingRing:
    streamingBytes += slot.vertexCapacity + slot.indexCapacity
    if slot.vertexBuffer != nil or slot.indexBuffer != nil: inc ringEntries
  (runtime.uploadWriteCalls, runtime.uploadBytes, runtime.largestUploadWrite,
    runtime.uploadChunkBytes, runtime.preparedCacheBytes +
      streamingBytes + runtime.targetTextureBytes + runtime.readbackCapacity,
    runtime.managedGpuPeakBytes, runtime.managedGpuByteBudget,
    streamingBytes, runtime.targetTextureBytes, runtime.readbackCapacity,
    runtime.transientRasterPeakBytes,
    runtime.streamingRingRotations, runtime.streamingRingSyncs, ringEntries,
    runtime.streamingRingCapacity)

proc streamingBytes(runtime: NativeWgpuRuntime): uint64 =
  for slot in runtime.streamingRing:
    result += slot.vertexCapacity + slot.indexCapacity

proc evictOldestPrepared(runtime: NativeWgpuRuntime;
                         protectedToken = 0'u64): bool =
  var victim = -1
  for index, entry in runtime.preparedMeshes:
    if entry.token != protectedToken and
        (victim < 0 or entry.lastUse < runtime.preparedMeshes[victim].lastUse):
      victim = index
  if victim < 0: return false
  let released = runtime.preparedMeshes[victim].vertexCapacity +
    runtime.preparedMeshes[victim].indexCapacity
  if runtime.preparedMeshes[victim].indexBuffer != nil:
    runtime.releaseBuffer(runtime.preparedMeshes[victim].indexBuffer)
  if runtime.preparedMeshes[victim].vertexBuffer != nil:
    runtime.releaseBuffer(runtime.preparedMeshes[victim].vertexBuffer)
  runtime.preparedMeshes.delete(victim)
  runtime.preparedCacheBytes -= released
  inc runtime.preparedCacheEvictions
  true

proc makeManagedRoom(runtime: NativeWgpuRuntime;
                     streamingBytes, targetBytes,
                     readbackBytes: uint64; incomingPrepared = 0'u64;
                     protectedToken = 0'u64) =
  var base = streamingBytes
  for value in [targetBytes, readbackBytes, runtime.transientRasterBytes]:
    if base > high(uint64) - value:
      raise newException(LibraryError,
        "managed WGPU resource capacities overflow uint64")
    base += value
  if base > runtime.managedGpuByteBudget or
      incomingPrepared > runtime.managedGpuByteBudget - base:
    raise newException(LibraryError,
      "managed WGPU resources exceed the byte budget")
  let preparedLimit = runtime.managedGpuByteBudget - base - incomingPrepared
  while runtime.preparedCacheBytes > preparedLimit:
    if not runtime.evictOldestPrepared(protectedToken):
      raise newException(LibraryError,
        "managed WGPU resources exceed the byte budget")

proc recordManagedPeak(runtime: NativeWgpuRuntime) =
  let current = runtime.preparedCacheBytes + runtime.streamingBytes() +
    runtime.targetTextureBytes + runtime.readbackCapacity +
    runtime.transientRasterBytes
  runtime.managedGpuPeakBytes = max(runtime.managedGpuPeakBytes, current)

proc writeBufferChunked(runtime: NativeWgpuRuntime;
                        writeBuffer: WriteBufferProc; buffer: pointer;
                        data: pointer; size: uint64) =
  ## Bound each queue write while preserving the byte-exact buffer payload.
  var offset = 0'u64
  while offset < size:
    let chunk = min(runtime.uploadChunkBytes, size - offset)
    writeBuffer(runtime.queue, buffer, offset,
      cast[pointer](cast[uint](data) + uint(offset)), csize_t(chunk))
    inc runtime.uploadWriteCalls
    runtime.uploadBytes += chunk
    runtime.largestUploadWrite = max(runtime.largestUploadWrite, chunk)
    offset += chunk

proc renderPixels(runtime: NativeWgpuRuntime; width, height: uint32;
                  red, green, blue, alpha: float64;
                  meshVertices: openArray[float32];
                  meshIndices: openArray[uint32];
                  imageVertices: openArray[float32];
                  images: openArray[NativeImageData];
                  commands: openArray[NativeDrawCommand];
                  readback: bool; uploadToken: uint64): seq[byte] =
  ## Render, read back, and remove WebGPU's per-row copy padding.
  if runtime.isNil or runtime.device == nil or runtime.queue == nil:
    raise newException(LibraryError, "wgpu-native runtime is not ready")
  if width == 0 or height == 0:
    raise newException(LibraryError, "WGPU target dimensions must be positive")
  if meshIndices.len > 0 and
      (meshVertices.len == 0 or meshVertices.len mod 6 != 0):
    raise newException(LibraryError, "invalid WGPU mesh vertex layout")
  if uint64(meshIndices.len) > uint64(high(uint32)):
    raise newException(LibraryError, "WGPU mesh index count exceeds uint32")
  if imageVertices.len mod 4 != 0:
    raise newException(LibraryError, "invalid WGPU image vertex layout")
  for image in images:
    if image.width == 0 or image.height == 0 or
        uint64(image.width) * uint64(image.height) * 4'u64 !=
          uint64(image.pixels.len):
      raise newException(LibraryError, "invalid WGPU RGBA image payload")
    if image.width > runtime.adapterCapabilities.maxTextureDimension2D or
        image.height > runtime.adapterCapabilities.maxTextureDimension2D:
      raise newException(LibraryError,
        "WGPU image dimensions exceed the adapter limit")
  for command in commands:
    case command.kind
    of ndMesh:
      if uint64(command.first) + uint64(command.count) >
          uint64(meshIndices.len):
        raise newException(LibraryError, "WGPU mesh command exceeds indices")
    of ndImage:
      if command.imageIndex notin 0 ..< images.len or
          uint64(command.first) + uint64(command.count) >
            uint64(imageVertices.len div 4):
        raise newException(LibraryError, "WGPU image command is invalid")
  if uint64(imageVertices.len) > high(uint64) div uint64(sizeof(float32)):
    raise newException(LibraryError, "WGPU raster working set overflows uint64")
  var rasterBytes = uint64(imageVertices.len) * uint64(sizeof(float32))
  for image in images:
    if uint64(image.pixels.len) > high(uint64) - rasterBytes:
      raise newException(LibraryError,
        "WGPU raster working set overflows uint64")
    rasterBytes += uint64(image.pixels.len)
  runtime.transientRasterBytes = rasterBytes
  runtime.transientRasterPeakBytes = max(runtime.transientRasterPeakBytes,
    rasterBytes)
  defer: runtime.transientRasterBytes = 0
  if runtime.deviceLostReason() != 0'u32:
    raise newException(LibraryError, "wgpu-native device was lost")
  if runtime.takeUncapturedError() != 0'u32:
    raise newException(LibraryError, "wgpu-native reported an uncaptured error")
  let
    createTexture = loadSymbol[CreateTextureProc](runtime.library,
        "wgpuDeviceCreateTexture")
    createView = loadSymbol[CreateTextureViewProc](runtime.library,
        "wgpuTextureCreateView")
    createEncoder = loadSymbol[CreateCommandEncoderProc](runtime.library,
        "wgpuDeviceCreateCommandEncoder")
    beginPass = loadSymbol[BeginRenderPassProc](runtime.library,
        "wgpuCommandEncoderBeginRenderPass")
    endPass = loadSymbol[EndRenderPassProc](runtime.library,
        "wgpuRenderPassEncoderEnd")
    finishEncoder = loadSymbol[FinishCommandEncoderProc](runtime.library,
        "wgpuCommandEncoderFinish")
    submitForIndex = loadSymbol[SubmitForIndexProc](runtime.library,
        "wgpuQueueSubmitForIndex")
    releaseTexture = loadSymbol[ReleaseProc](runtime.library,
        "wgpuTextureRelease")
    releaseView = loadSymbol[ReleaseProc](runtime.library,
        "wgpuTextureViewRelease")
    releaseEncoder = loadSymbol[ReleaseProc](runtime.library,
        "wgpuCommandEncoderRelease")
    releasePass = loadSymbol[ReleaseProc](runtime.library,
        "wgpuRenderPassEncoderRelease")
    releaseCommand = loadSymbol[ReleaseProc](runtime.library,
        "wgpuCommandBufferRelease")
    createBuffer = loadSymbol[CreateBufferProc](runtime.library,
        "wgpuDeviceCreateBuffer")
    copyTextureToBuffer = loadSymbol[CopyTextureToBufferProc](runtime.library,
        "wgpuCommandEncoderCopyTextureToBuffer")
    mapBuffer = loadSymbol[MapBufferProc](runtime.library,
        "wgpuBufferMapAsync")
    getMappedRange = loadSymbol[GetMappedRangeProc](runtime.library,
        "wgpuBufferGetConstMappedRange")
    unmapBuffer = loadSymbol[UnmapBufferProc](runtime.library,
        "wgpuBufferUnmap")
    processEvents = loadSymbol[ProcessEventsProc](runtime.library,
        "wgpuInstanceProcessEvents")
    releaseBuffer = loadSymbol[ReleaseProc](runtime.library,
        "wgpuBufferRelease")
    createShader = loadSymbol[CreateShaderModuleProc](runtime.library,
        "wgpuDeviceCreateShaderModule")
    createPipeline = loadSymbol[CreateRenderPipelineProc](runtime.library,
        "wgpuDeviceCreateRenderPipeline")
    writeBuffer = loadSymbol[WriteBufferProc](runtime.library,
        "wgpuQueueWriteBuffer")
    setPipeline = loadSymbol[SetPipelineProc](runtime.library,
        "wgpuRenderPassEncoderSetPipeline")
    setVertexBuffer = loadSymbol[SetVertexBufferProc](runtime.library,
        "wgpuRenderPassEncoderSetVertexBuffer")
    setIndexBuffer = loadSymbol[SetIndexBufferProc](runtime.library,
        "wgpuRenderPassEncoderSetIndexBuffer")
    drawIndexed = loadSymbol[DrawIndexedProc](runtime.library,
        "wgpuRenderPassEncoderDrawIndexed")
    draw = loadSymbol[DrawProc](runtime.library,
        "wgpuRenderPassEncoderDraw")
    createSampler = loadSymbol[CreateSamplerProc](runtime.library,
        "wgpuDeviceCreateSampler")
    getBindGroupLayout = loadSymbol[GetBindGroupLayoutProc](runtime.library,
        "wgpuRenderPipelineGetBindGroupLayout")
    createBindGroup = loadSymbol[CreateBindGroupProc](runtime.library,
        "wgpuDeviceCreateBindGroup")
    setBindGroup = loadSymbol[SetBindGroupProc](runtime.library,
        "wgpuRenderPassEncoderSetBindGroup")
    writeTexture = loadSymbol[WriteTextureProc](runtime.library,
        "wgpuQueueWriteTexture")
  let emptyLabel = WgpuStringView(data: "".cstring, length: 0)
  runtime.releaseTexture = releaseTexture
  runtime.releaseView = releaseView
  runtime.releaseBuffer = releaseBuffer
  runtime.releaseSampler = loadSymbol[ReleaseProc](runtime.library,
    "wgpuSamplerRelease")
  runtime.releaseBindGroup = loadSymbol[ReleaseProc](runtime.library,
    "wgpuBindGroupRelease")
  runtime.releaseBindGroupLayout = loadSymbol[ReleaseProc](runtime.library,
    "wgpuBindGroupLayoutRelease")
  var streamingIndex = -1
  if width > runtime.adapterCapabilities.maxTextureDimension2D or
      height > runtime.adapterCapabilities.maxTextureDimension2D:
    raise newException(LibraryError,
      "WGPU target dimensions exceed the adapter limit")
  if uint64(width) > high(uint64) div uint64(height) div 4'u64:
    raise newException(LibraryError, "WGPU target byte size overflows uint64")
  let requestedTargetBytes = uint64(width) * uint64(height) * 4'u64
  if runtime.targetTexture == nil or runtime.targetWidth != width or
      runtime.targetHeight != height:
    runtime.makeManagedRoom(runtime.streamingBytes(), requestedTargetBytes,
      runtime.readbackCapacity)
    if runtime.targetView != nil:
      releaseView(runtime.targetView)
      runtime.targetView = nil
    if runtime.targetTexture != nil:
      releaseTexture(runtime.targetTexture)
      runtime.targetTexture = nil
    runtime.targetTextureBytes = 0
    var textureDescriptor = WgpuTextureDescriptor(
      label: emptyLabel,
      usage: TextureUsageCopySrc or TextureUsageRenderAttachment,
      dimension: TextureDimension2D,
      size: WgpuExtent3D(width: width, height: height,
        depthOrArrayLayers: 1),
      format: TextureFormatRgba8Unorm,
      mipLevelCount: 1,
      sampleCount: 1)
    runtime.targetTexture = createTexture(runtime.device,
      addr textureDescriptor)
    if runtime.targetTexture == nil:
      raise newException(LibraryError, "wgpu-native did not create a texture")
    runtime.targetView = createView(runtime.targetTexture, nil)
    if runtime.targetView == nil:
      releaseTexture(runtime.targetTexture)
      runtime.targetTexture = nil
      raise newException(LibraryError,
        "wgpu-native did not create a texture view")
    runtime.targetWidth = width
    runtime.targetHeight = height
    runtime.targetTextureBytes = requestedTargetBytes
    runtime.recordManagedPeak()
  if meshIndices.len > 0 and uploadToken == 0:
    streamingIndex = runtime.streamingRingCursor
    runtime.streamingRingCursor = (runtime.streamingRingCursor + 1) mod
      runtime.streamingRingCapacity
    inc runtime.streamingRingRotations
    var slot = addr runtime.streamingRing[streamingIndex]
    if slot.submissionIndex != 0:
      var pending = slot.submissionIndex
      discard runtime.pollDevice(runtime.device, 1'u32, addr pending)
      slot.submissionIndex = 0
      inc runtime.streamingRingSyncs
  let encoder = createEncoder(runtime.device, nil)
  if encoder == nil:
    raise newException(LibraryError, "wgpu-native did not create an encoder")
  defer: releaseEncoder(encoder)
  var attachment = WgpuRenderPassColorAttachment(
    view: runtime.targetView,
    depthSlice: high(uint32),
    loadOp: LoadOpClear,
    storeOp: StoreOpStore,
    clearValue: WgpuColor(r: red * alpha, g: green * alpha,
      b: blue * alpha, a: alpha))
  var passDescriptor = WgpuRenderPassDescriptor(
    label: emptyLabel,
    colorAttachmentCount: 1,
    colorAttachments: addr attachment)
  let renderPass = beginPass(encoder, addr passDescriptor)
  if renderPass == nil:
    raise newException(LibraryError, "wgpu-native did not create a render pass")
  var renderPassOpen = true
  defer:
    if renderPassOpen:
      endPass(renderPass)
      releasePass(renderPass)
  var activeVertexBuffer, activeIndexBuffer: pointer
  if meshIndices.len > 0:
    const shaderCode = """
struct VertexOut {
  @builtin(position) position: vec4f,
  @location(0) color: vec4f,
}
@vertex fn vs_main(@location(0) position: vec2f,
                   @location(1) color: vec4f) -> VertexOut {
  var out: VertexOut;
  out.position = vec4f(position, 0.0, 1.0);
  out.color = color;
  return out;
}
@fragment fn fs_main(input: VertexOut) -> @location(0) vec4f {
  return input.color;
}
"""
    if runtime.meshPipeline == nil:
      runtime.releaseShader = loadSymbol[ReleaseProc](runtime.library,
          "wgpuShaderModuleRelease")
      runtime.releasePipeline = loadSymbol[ReleaseProc](runtime.library,
          "wgpuRenderPipelineRelease")
      var shaderSource = WgpuShaderSourceWgsl(
        chain: WgpuChainedStruct(sType: STypeShaderSourceWgsl),
        code: WgpuStringView(data: shaderCode.cstring,
          length: csize_t(shaderCode.len)))
      var shaderDescriptor = WgpuShaderModuleDescriptor(
        nextInChain: addr shaderSource.chain, label: emptyLabel)
      runtime.meshShader = createShader(runtime.device, addr shaderDescriptor)
      if runtime.meshShader == nil:
        raise newException(LibraryError, "wgpu-native did not create a shader")
      var attributes = [
        WgpuVertexAttribute(format: VertexFormatFloat32x2, shaderLocation: 0),
        WgpuVertexAttribute(format: VertexFormatFloat32x4, offset: 8,
          shaderLocation: 1)]
      var vertexLayout = WgpuVertexBufferLayout(
        stepMode: VertexStepModeVertex, arrayStride: 24,
        attributeCount: csize_t(attributes.len), attributes: addr attributes[0])
      let vertexEntry = "vs_main"
      let fragmentEntry = "fs_main"
      var blend = WgpuBlendState(
        color: WgpuBlendComponent(operation: BlendOperationAdd,
          srcFactor: BlendFactorSrcAlpha,
          dstFactor: BlendFactorOneMinusSrcAlpha),
        alpha: WgpuBlendComponent(operation: BlendOperationAdd,
          srcFactor: BlendFactorOne,
          dstFactor: BlendFactorOneMinusSrcAlpha))
      var target = WgpuColorTargetState(format: TextureFormatRgba8Unorm,
        blend: addr blend, writeMask: ColorWriteMaskAll)
      var fragment = WgpuFragmentState(module: runtime.meshShader,
        entryPoint: WgpuStringView(data: fragmentEntry.cstring,
          length: csize_t(fragmentEntry.len)), targetCount: 1,
        targets: addr target)
      var pipelineDescriptor = WgpuRenderPipelineDescriptor(label: emptyLabel,
        vertex: WgpuVertexState(module: runtime.meshShader,
          entryPoint: WgpuStringView(data: vertexEntry.cstring,
            length: csize_t(vertexEntry.len)), bufferCount: 1,
          buffers: addr vertexLayout),
        primitive: WgpuPrimitiveState(
          topology: PrimitiveTopologyTriangleList,
          frontFace: FrontFaceCcw, cullMode: CullModeNone),
        multisample: WgpuMultisampleState(count: 1, mask: high(uint32)),
        fragment: addr fragment)
      runtime.meshPipeline = createPipeline(runtime.device,
        addr pipelineDescriptor)
      if runtime.meshPipeline == nil:
        runtime.releaseShader(runtime.meshShader)
        runtime.meshShader = nil
        raise newException(LibraryError, "wgpu-native did not create a pipeline")
    let
      vertexSize = uint64(meshVertices.len) * uint64(sizeof(float32))
      indexSize = uint64(meshIndices.len) * uint64(sizeof(uint32))
    template ensureBuffer(buffer, capacity: untyped;
                          required, bufferUsage: uint64;
                          description: string) =
      if capacity < required:
        if buffer != nil:
          releaseBuffer(buffer)
          buffer = nil
        capacity = grownCapacity(capacity, required)
        var descriptor = WgpuBufferDescriptor(label: emptyLabel,
          usage: BufferUsageCopyDst or bufferUsage, size: capacity)
        buffer = createBuffer(runtime.device, addr descriptor)
        if buffer == nil:
          capacity = 0
          raise newException(LibraryError,
            "wgpu-native did not create a " & description & " buffer")

    if uploadToken == 0:
      var slot = addr runtime.streamingRing[streamingIndex]
      let
        desiredVertexCapacity = grownCapacity(slot.vertexCapacity,
          vertexSize)
        desiredIndexCapacity = grownCapacity(slot.indexCapacity, indexSize)
        desiredStreamingBytes = runtime.streamingBytes() -
          slot.vertexCapacity - slot.indexCapacity + desiredVertexCapacity +
          desiredIndexCapacity
      runtime.makeManagedRoom(desiredStreamingBytes,
        runtime.targetTextureBytes, runtime.readbackCapacity)
      ensureBuffer(slot.vertexBuffer, slot.vertexCapacity, vertexSize,
        BufferUsageVertex, "vertex")
      ensureBuffer(slot.indexBuffer, slot.indexCapacity, indexSize,
        BufferUsageIndex, "index")
      runtime.recordManagedPeak()
      runtime.writeBufferChunked(writeBuffer, slot.vertexBuffer,
        unsafeAddr meshVertices[0], vertexSize)
      runtime.writeBufferChunked(writeBuffer, slot.indexBuffer,
        unsafeAddr meshIndices[0], indexSize)
      inc runtime.meshUploadCount
      activeVertexBuffer = slot.vertexBuffer
      activeIndexBuffer = slot.indexBuffer
    else:
      var entryIndex = -1
      for index, entry in runtime.preparedMeshes:
        if entry.token == uploadToken:
          entryIndex = index
          break
      if entryIndex >= 0:
        let entry = runtime.preparedMeshes[entryIndex]
        if entry.vertexSize != vertexSize or entry.indexSize != indexSize:
          raise newException(LibraryError,
            "prepared WGPU token changed its mesh size")
        inc runtime.preparedCacheHits
      else:
        inc runtime.preparedCacheMisses
        let
          requiredVertexCapacity = grownCapacity(0, vertexSize)
          requiredIndexCapacity = grownCapacity(0, indexSize)
        if requiredVertexCapacity > high(uint64) - requiredIndexCapacity:
          raise newException(LibraryError,
            "prepared WGPU buffer capacities overflow uint64")
        let requiredBytes = requiredVertexCapacity + requiredIndexCapacity
        if requiredBytes > runtime.preparedCacheByteBudget:
          raise newException(LibraryError,
            "prepared WGPU scene exceeds the cache byte budget")
        runtime.makeManagedRoom(runtime.streamingBytes(),
          runtime.targetTextureBytes, runtime.readbackCapacity,
          incomingPrepared = requiredBytes)
        while runtime.preparedMeshes.len >= runtime.preparedCacheCapacity or
            runtime.preparedCacheBytes >
              runtime.preparedCacheByteBudget - requiredBytes:
          if not runtime.evictOldestPrepared():
            raise newException(LibraryError,
              "prepared WGPU cache could not evict an entry")
        runtime.preparedMeshes.add PreparedMeshBuffers()
        entryIndex = runtime.preparedMeshes.high
        var entry = addr runtime.preparedMeshes[entryIndex]
        try:
          ensureBuffer(entry.vertexBuffer, entry.vertexCapacity, vertexSize,
            BufferUsageVertex, "prepared vertex")
          ensureBuffer(entry.indexBuffer, entry.indexCapacity, indexSize,
            BufferUsageIndex, "prepared index")
        except:
          if entry.indexBuffer != nil: releaseBuffer(entry.indexBuffer)
          if entry.vertexBuffer != nil: releaseBuffer(entry.vertexBuffer)
          runtime.preparedMeshes.delete(entryIndex)
          raise
        runtime.preparedCacheBytes += entry.vertexCapacity +
          entry.indexCapacity
        runtime.preparedCachePeakBytes = max(runtime.preparedCachePeakBytes,
          runtime.preparedCacheBytes)
        runtime.recordManagedPeak()
        runtime.writeBufferChunked(writeBuffer, entry.vertexBuffer,
          unsafeAddr meshVertices[0], vertexSize)
        runtime.writeBufferChunked(writeBuffer, entry.indexBuffer,
          unsafeAddr meshIndices[0], indexSize)
        entry.token = uploadToken
        entry.vertexSize = vertexSize
        entry.indexSize = indexSize
        inc runtime.meshUploadCount
      if runtime.preparedUseClock == high(uint64):
        for entry in runtime.preparedMeshes.mitems: entry.lastUse = 0
        runtime.preparedUseClock = 1
      else:
        inc runtime.preparedUseClock
      runtime.preparedMeshes[entryIndex].lastUse = runtime.preparedUseClock
      activeVertexBuffer = runtime.preparedMeshes[entryIndex].vertexBuffer
      activeIndexBuffer = runtime.preparedMeshes[entryIndex].indexBuffer
    discard

  var imageVertexBuffer: pointer
  var imageTextures, imageViews, imageBindGroups: seq[pointer]
  defer:
    for bindGroup in imageBindGroups:
      if bindGroup != nil: runtime.releaseBindGroup(bindGroup)
    for view in imageViews:
      if view != nil: releaseView(view)
    for texture in imageTextures:
      if texture != nil: releaseTexture(texture)
    if imageVertexBuffer != nil: releaseBuffer(imageVertexBuffer)
  if images.len > 0:
    const imageShaderCode = """
struct VertexOut {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
}
@group(0) @binding(0) var image_sampler: sampler;
@group(0) @binding(1) var image_texture: texture_2d<f32>;
@vertex fn vs_image(@location(0) packed: vec4f) -> VertexOut {
  var out: VertexOut;
  out.position = vec4f(packed.xy, 0.0, 1.0);
  out.uv = packed.zw;
  return out;
}
@fragment fn fs_image(input: VertexOut) -> @location(0) vec4f {
  return textureSample(image_texture, image_sampler, input.uv);
}
"""
    if runtime.imagePipeline == nil:
      runtime.releaseShader = loadSymbol[ReleaseProc](runtime.library,
        "wgpuShaderModuleRelease")
      runtime.releasePipeline = loadSymbol[ReleaseProc](runtime.library,
        "wgpuRenderPipelineRelease")
      var shaderSource = WgpuShaderSourceWgsl(
        chain: WgpuChainedStruct(sType: STypeShaderSourceWgsl),
        code: WgpuStringView(data: imageShaderCode.cstring,
          length: csize_t(imageShaderCode.len)))
      var shaderDescriptor = WgpuShaderModuleDescriptor(
        nextInChain: addr shaderSource.chain, label: emptyLabel)
      runtime.imageShader = createShader(runtime.device, addr shaderDescriptor)
      if runtime.imageShader == nil:
        raise newException(LibraryError,
          "wgpu-native did not create the image shader")
      var attribute = WgpuVertexAttribute(format: VertexFormatFloat32x4,
        shaderLocation: 0)
      var vertexLayout = WgpuVertexBufferLayout(
        stepMode: VertexStepModeVertex, arrayStride: 16,
        attributeCount: 1, attributes: addr attribute)
      let vertexEntry = "vs_image"
      let fragmentEntry = "fs_image"
      var blend = WgpuBlendState(
        color: WgpuBlendComponent(operation: BlendOperationAdd,
          srcFactor: BlendFactorSrcAlpha,
          dstFactor: BlendFactorOneMinusSrcAlpha),
        alpha: WgpuBlendComponent(operation: BlendOperationAdd,
          srcFactor: BlendFactorOne,
          dstFactor: BlendFactorOneMinusSrcAlpha))
      var target = WgpuColorTargetState(format: TextureFormatRgba8Unorm,
        blend: addr blend, writeMask: ColorWriteMaskAll)
      var fragment = WgpuFragmentState(module: runtime.imageShader,
        entryPoint: WgpuStringView(data: fragmentEntry.cstring,
          length: csize_t(fragmentEntry.len)), targetCount: 1,
        targets: addr target)
      var descriptor = WgpuRenderPipelineDescriptor(label: emptyLabel,
        vertex: WgpuVertexState(module: runtime.imageShader,
          entryPoint: WgpuStringView(data: vertexEntry.cstring,
            length: csize_t(vertexEntry.len)), bufferCount: 1,
          buffers: addr vertexLayout),
        primitive: WgpuPrimitiveState(
          topology: PrimitiveTopologyTriangleList,
          frontFace: FrontFaceCcw, cullMode: CullModeNone),
        multisample: WgpuMultisampleState(count: 1, mask: high(uint32)),
        fragment: addr fragment)
      runtime.imagePipeline = createPipeline(runtime.device, addr descriptor)
      if runtime.imagePipeline == nil:
        runtime.releaseShader(runtime.imageShader)
        runtime.imageShader = nil
        raise newException(LibraryError,
          "wgpu-native did not create the image pipeline")
    if runtime.imageSampler == nil:
      var descriptor = WgpuSamplerDescriptor(label: emptyLabel,
        addressModeU: AddressModeClampToEdge,
        addressModeV: AddressModeClampToEdge,
        addressModeW: AddressModeClampToEdge,
        magFilter: FilterModeLinear, minFilter: FilterModeLinear,
        mipmapFilter: MipmapFilterModeNearest, lodMaxClamp: 32,
        maxAnisotropy: 1)
      runtime.imageSampler = createSampler(runtime.device, addr descriptor)
      if runtime.imageSampler == nil:
        raise newException(LibraryError,
          "wgpu-native did not create the image sampler")
    let imageVertexSize = uint64(imageVertices.len) * uint64(sizeof(float32))
    var descriptor = WgpuBufferDescriptor(label: emptyLabel,
      usage: BufferUsageCopyDst or BufferUsageVertex, size: imageVertexSize)
    imageVertexBuffer = createBuffer(runtime.device, addr descriptor)
    if imageVertexBuffer == nil:
      raise newException(LibraryError,
        "wgpu-native did not create the image vertex buffer")
    runtime.writeBufferChunked(writeBuffer, imageVertexBuffer,
      unsafeAddr imageVertices[0], imageVertexSize)
    let layout = getBindGroupLayout(runtime.imagePipeline, 0)
    if layout == nil:
      raise newException(LibraryError,
        "wgpu-native did not expose the image bind-group layout")
    defer: runtime.releaseBindGroupLayout(layout)
    imageTextures.setLen(images.len)
    imageViews.setLen(images.len)
    imageBindGroups.setLen(images.len)
    for index, image in images:
      var textureDescriptor = WgpuTextureDescriptor(label: emptyLabel,
        usage: TextureUsageCopyDst or TextureUsageBinding,
        dimension: TextureDimension2D,
        size: WgpuExtent3D(width: image.width, height: image.height,
          depthOrArrayLayers: 1), format: TextureFormatRgba8Unorm,
        mipLevelCount: 1, sampleCount: 1)
      imageTextures[index] = createTexture(runtime.device,
        addr textureDescriptor)
      if imageTextures[index] == nil:
        raise newException(LibraryError,
          "wgpu-native did not create an image texture")
      imageViews[index] = createView(imageTextures[index], nil)
      if imageViews[index] == nil:
        raise newException(LibraryError,
          "wgpu-native did not create an image texture view")
      var destination = WgpuTexelCopyTextureInfo(
        texture: imageTextures[index], aspect: TextureAspectAll)
      var copyLayout = WgpuTexelCopyBufferLayout(
        bytesPerRow: image.width * 4, rowsPerImage: image.height)
      var copySize = WgpuExtent3D(width: image.width, height: image.height,
        depthOrArrayLayers: 1)
      writeTexture(runtime.queue, addr destination,
        unsafeAddr image.pixels[0], csize_t(image.pixels.len),
        addr copyLayout, addr copySize)
      inc runtime.textureUploadCount
      runtime.textureUploadBytes += uint64(image.pixels.len)
      var entries = [
        WgpuBindGroupEntry(binding: 0, sampler: runtime.imageSampler),
        WgpuBindGroupEntry(binding: 1, textureView: imageViews[index])]
      var bindDescriptor = WgpuBindGroupDescriptor(label: emptyLabel,
        layout: layout, entryCount: 2, entries: addr entries[0])
      imageBindGroups[index] = createBindGroup(runtime.device,
        addr bindDescriptor)
      if imageBindGroups[index] == nil:
        raise newException(LibraryError,
          "wgpu-native did not create an image bind group")

  for command in commands:
    case command.kind
    of ndMesh:
      setPipeline(renderPass, runtime.meshPipeline)
      let
        vertexSize = uint64(meshVertices.len) * uint64(sizeof(float32))
        indexSize = uint64(meshIndices.len) * uint64(sizeof(uint32))
      setVertexBuffer(renderPass, 0, activeVertexBuffer, 0, vertexSize)
      setIndexBuffer(renderPass, activeIndexBuffer, IndexFormatUint32, 0,
        indexSize)
      drawIndexed(renderPass, command.count, 1, command.first, 0, 0)
    of ndImage:
      setPipeline(renderPass, runtime.imagePipeline)
      setVertexBuffer(renderPass, 0, imageVertexBuffer, 0,
        uint64(imageVertices.len) * uint64(sizeof(float32)))
      setBindGroup(renderPass, 0, imageBindGroups[command.imageIndex], 0, nil)
      draw(renderPass, command.count, 1, command.first, 0)
  endPass(renderPass)
  releasePass(renderPass)
  renderPassOpen = false
  var unpaddedRow, paddedRow, bufferSize: uint64
  if readback:
    unpaddedRow = uint64(width) * 4'u64
    paddedRow = (unpaddedRow + 255'u64) and not 255'u64
    if paddedRow > uint64(high(uint32)) or
        paddedRow > uint64(high(int)) div uint64(height):
      raise newException(LibraryError, "WGPU readback size exceeds host limits")
    bufferSize = paddedRow * uint64(height)
    if runtime.readbackCapacity < bufferSize:
      let desiredReadbackCapacity = grownCapacity(runtime.readbackCapacity,
        bufferSize)
      runtime.makeManagedRoom(runtime.streamingBytes(),
        runtime.targetTextureBytes, desiredReadbackCapacity,
        protectedToken = uploadToken)
      if runtime.readbackBuffer != nil:
        releaseBuffer(runtime.readbackBuffer)
        runtime.readbackBuffer = nil
      runtime.readbackCapacity = desiredReadbackCapacity
      var descriptor = WgpuBufferDescriptor(label: emptyLabel,
        usage: BufferUsageMapRead or BufferUsageCopyDst,
        size: runtime.readbackCapacity)
      runtime.readbackBuffer = createBuffer(runtime.device, addr descriptor)
      if runtime.readbackBuffer == nil:
        runtime.readbackCapacity = 0
        raise newException(LibraryError,
          "wgpu-native did not create a readback buffer")
      runtime.recordManagedPeak()
    var source = WgpuTexelCopyTextureInfo(texture: runtime.targetTexture,
      aspect: TextureAspectAll)
    var destination = WgpuTexelCopyBufferInfo(
      layout: WgpuTexelCopyBufferLayout(bytesPerRow: uint32(paddedRow),
        rowsPerImage: height), buffer: runtime.readbackBuffer)
    var copySize = WgpuExtent3D(width: width, height: height,
      depthOrArrayLayers: 1)
    copyTextureToBuffer(encoder, addr source, addr destination, addr copySize)
  let command = finishEncoder(encoder, nil)
  if command == nil:
    raise newException(LibraryError, "wgpu-native did not create a command buffer")
  defer: releaseCommand(command)
  var submittedCommand = command
  let submissionIndex = submitForIndex(runtime.queue, 1, addr submittedCommand)
  if streamingIndex >= 0 and submissionIndex == 0:
    discard runtime.pollDevice(runtime.device, 1'u32, nil)
    raise newException(LibraryError,
      "wgpu-native returned an invalid submission index")
  if streamingIndex >= 0:
    runtime.streamingRing[streamingIndex].submissionIndex = submissionIndex
  if not readback:
    processEvents(runtime.instance)
    if runtime.deviceLostReason() != 0'u32:
      raise newException(LibraryError, "wgpu-native device was lost")
    if runtime.takeUncapturedError() != 0'u32:
      raise newException(LibraryError,
        "wgpu-native reported an uncaptured error")
    return @[]
  runtime.events.mapStatus.store(0'u32, moRelease)
  discard mapBuffer(runtime.readbackBuffer, MapModeRead, 0, csize_t(bufferSize),
    WgpuBufferMapCallbackInfo(mode: CallbackAllowProcessEvents,
      callback: receiveMap, userdata1: runtime.events))
  var attempts = 0
  while runtime.events.mapStatus.load(moAcquire) == 0'u32 and
      attempts < 10_000:
    processEvents(runtime.instance)
    inc attempts
    sleep(1)
  let mapStatus = runtime.events.mapStatus.load(moAcquire)
  if mapStatus == 0'u32:
    raise newException(LibraryError, "wgpu-native buffer mapping timed out")
  if mapStatus != MapSuccess:
    raise newException(LibraryError, "wgpu-native buffer mapping failed")
  if streamingIndex >= 0:
    runtime.streamingRing[streamingIndex].submissionIndex = 0
  let mapped = getMappedRange(runtime.readbackBuffer, 0, csize_t(bufferSize))
  if mapped == nil:
    raise newException(LibraryError, "wgpu-native returned no mapped data")
  defer: unmapBuffer(runtime.readbackBuffer)
  let outputSize = int(unpaddedRow * uint64(height))
  result = newSeq[byte](outputSize)
  let sourceBytes = cast[ptr UncheckedArray[byte]](mapped)
  for row in 0 ..< int(height):
    copyMem(addr result[row * int(unpaddedRow)],
      unsafeAddr sourceBytes[row * int(paddedRow)], int(unpaddedRow))
  for offset in countup(0, result.high, 4):
    let outputAlpha = uint32(result[offset + 3])
    if outputAlpha == 0:
      result[offset] = 0
      result[offset + 1] = 0
      result[offset + 2] = 0
    elif outputAlpha < 255:
      for channel in 0 ..< 3:
        result[offset + channel] = byte(min(255'u32,
          (uint32(result[offset + channel]) * 255'u32 + outputAlpha div 2) div
            outputAlpha))
  if runtime.deviceLostReason() != 0'u32:
    raise newException(LibraryError, "wgpu-native device was lost")
  if runtime.takeUncapturedError() != 0'u32:
    raise newException(LibraryError, "wgpu-native reported an uncaptured error")

proc renderClearPixels*(runtime: NativeWgpuRuntime; width, height: uint32;
                        red, green, blue, alpha: float64): seq[byte] =
  runtime.renderPixels(width, height, red, green, blue, alpha, [], [], [], [],
    [], true, 0)

proc renderPreparedScenePixels*(runtime: NativeWgpuRuntime;
                                width, height: uint32;
                                red, green, blue, alpha: float64;
                                meshVertices: openArray[float32];
                                meshIndices: openArray[uint32];
                                imageVertices: openArray[float32];
                                images: openArray[NativeImageData];
                                commands: openArray[NativeDrawCommand];
                                uploadToken: uint64): seq[byte] =
  if uploadToken == 0:
    raise newException(LibraryError, "prepared WGPU upload token is zero")
  runtime.renderPixels(width, height, red, green, blue, alpha, meshVertices,
    meshIndices, imageVertices, images, commands, true, uploadToken)

proc submitPreparedScene*(runtime: NativeWgpuRuntime; width, height: uint32;
                          red, green, blue, alpha: float64;
                          meshVertices: openArray[float32];
                          meshIndices: openArray[uint32];
                          imageVertices: openArray[float32];
                          images: openArray[NativeImageData];
                          commands: openArray[NativeDrawCommand];
                          uploadToken: uint64) =
  if uploadToken == 0:
    raise newException(LibraryError, "prepared WGPU upload token is zero")
  discard runtime.renderPixels(width, height, red, green, blue, alpha,
    meshVertices, meshIndices, imageVertices, images, commands, false,
    uploadToken)

proc renderMeshPixels*(runtime: NativeWgpuRuntime; width, height: uint32;
                       red, green, blue, alpha: float64;
                       vertices: openArray[float32];
                       indices: openArray[uint32]): seq[byte] =
  let commands = if indices.len == 0: newSeq[NativeDrawCommand]() else:
    @[NativeDrawCommand(kind: ndMesh, count: uint32(indices.len))]
  runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, [], [], commands, true, 0)

proc renderPreparedMeshPixels*(runtime: NativeWgpuRuntime;
                               width, height: uint32;
                               red, green, blue, alpha: float64;
                               vertices: openArray[float32];
                               indices: openArray[uint32];
                               uploadToken: uint64): seq[byte] =
  if uploadToken == 0:
    raise newException(LibraryError, "prepared WGPU upload token is zero")
  let commands = if indices.len == 0: newSeq[NativeDrawCommand]() else:
    @[NativeDrawCommand(kind: ndMesh, count: uint32(indices.len))]
  runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, [], [], commands, true, uploadToken)

proc submitMesh*(runtime: NativeWgpuRuntime; width, height: uint32;
                 red, green, blue, alpha: float64;
                 vertices: openArray[float32]; indices: openArray[uint32]) =
  let commands = if indices.len == 0: newSeq[NativeDrawCommand]() else:
    @[NativeDrawCommand(kind: ndMesh, count: uint32(indices.len))]
  discard runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, [], [], commands, false, 0)

proc submitPreparedMesh*(runtime: NativeWgpuRuntime; width, height: uint32;
                         red, green, blue, alpha: float64;
                         vertices: openArray[float32];
                         indices: openArray[uint32]; uploadToken: uint64) =
  if uploadToken == 0:
    raise newException(LibraryError, "prepared WGPU upload token is zero")
  let commands = if indices.len == 0: newSeq[NativeDrawCommand]() else:
    @[NativeDrawCommand(kind: ndMesh, count: uint32(indices.len))]
  discard runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, [], [], commands, false, uploadToken)
