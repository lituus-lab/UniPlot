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
  SubmitProc = proc(queue: pointer; count: csize_t;
      commands: ptr pointer) {.cdecl.}
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
  PollDeviceProc = proc(device: pointer; wait: uint32;
      submissionIndex: pointer): uint32 {.cdecl.}

  DeviceRequest = object
    status: Atomic[uint32]
    device: pointer

  DeviceEvents = object
    lostReason, errorType, mapStatus: Atomic[uint32]

  NativeWgpuRuntime* = ref object
    library: LibHandle
    instance, adapter, device, queue: pointer
    meshShader, meshPipeline: pointer
    targetTexture, targetView: pointer
    vertexBuffer, indexBuffer, readbackBuffer: pointer
    targetWidth, targetHeight: uint32
    vertexCapacity, indexCapacity, readbackCapacity: uint64
    uploadedToken, meshUploadCount: uint64
    events: ptr DeviceEvents
    getVersion: GetVersionProc
    hasFeature: HasFeatureProc
    processEvents: ProcessEventsProc
    pollDevice: PollDeviceProc
    destroyDevice: ReleaseProc
    releaseInstance, releaseAdapter, releaseDevice, releaseQueue: ReleaseProc
    releaseShader, releasePipeline: ReleaseProc
    releaseTexture, releaseView, releaseBuffer: ReleaseProc
    adapterCapabilities: NativeAdapterCapabilities

const
  CallbackAllowProcessEvents = 2'u32
  RequestDeviceSuccess = 1'u32
  FeatureTimestampQuery = 9'u32
  TextureUsageCopySrc = 0x1'u64
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
  if runtime.indexBuffer != nil and runtime.releaseBuffer != nil:
    runtime.releaseBuffer(runtime.indexBuffer)
    runtime.indexBuffer = nil
  if runtime.vertexBuffer != nil and runtime.releaseBuffer != nil:
    runtime.releaseBuffer(runtime.vertexBuffer)
    runtime.vertexBuffer = nil
  if runtime.targetView != nil and runtime.releaseView != nil:
    runtime.releaseView(runtime.targetView)
    runtime.targetView = nil
  if runtime.targetTexture != nil and runtime.releaseTexture != nil:
    runtime.releaseTexture(runtime.targetTexture)
    runtime.targetTexture = nil
  if runtime.meshPipeline != nil and runtime.releasePipeline != nil:
    runtime.releasePipeline(runtime.meshPipeline)
    runtime.meshPipeline = nil
  if runtime.meshShader != nil and runtime.releaseShader != nil:
    runtime.releaseShader(runtime.meshShader)
    runtime.meshShader = nil
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

proc openNativeWgpu*(libraryPath: string): NativeWgpuRuntime =
  ## Load wgpu-native, select its first adapter, and create a real device/queue.
  let library = loadLib(libraryPath)
  if library == nil:
    raise newException(LibraryError, "cannot load wgpu-native: " & libraryPath)
  result = NativeWgpuRuntime(library: library)
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

proc takeUncapturedError*(runtime: NativeWgpuRuntime): uint32 =
  if runtime.isNil or runtime.events == nil: result = 0'u32
  else: result = runtime.events.errorType.exchange(0'u32, moAcquireRelease)

proc meshUploadCount*(runtime: NativeWgpuRuntime): uint64 =
  ## Return vertex/index upload pairs issued through the queue.
  if runtime.isNil: 0'u64 else: runtime.meshUploadCount

proc renderPixels(runtime: NativeWgpuRuntime; width, height: uint32;
                  red, green, blue, alpha: float64;
                  meshVertices: openArray[float32];
                  meshIndices: openArray[uint32];
                  readback: bool; uploadToken: uint64): seq[byte] =
  ## Render, read back, and remove WebGPU's per-row copy padding.
  if runtime.isNil or runtime.device == nil or runtime.queue == nil:
    raise newException(LibraryError, "wgpu-native runtime is not ready")
  if width == 0 or height == 0:
    raise newException(LibraryError, "WGPU target dimensions must be positive")
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
    submit = loadSymbol[SubmitProc](runtime.library, "wgpuQueueSubmit")
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
  let emptyLabel = WgpuStringView(data: "".cstring, length: 0)
  runtime.releaseTexture = releaseTexture
  runtime.releaseView = releaseView
  runtime.releaseBuffer = releaseBuffer
  if runtime.targetTexture == nil or runtime.targetWidth != width or
      runtime.targetHeight != height:
    if runtime.targetView != nil:
      releaseView(runtime.targetView)
      runtime.targetView = nil
    if runtime.targetTexture != nil:
      releaseTexture(runtime.targetTexture)
      runtime.targetTexture = nil
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
  let encoder = createEncoder(runtime.device, nil)
  if encoder == nil:
    raise newException(LibraryError, "wgpu-native did not create an encoder")
  defer: releaseEncoder(encoder)
  var attachment = WgpuRenderPassColorAttachment(
    view: runtime.targetView,
    depthSlice: high(uint32),
    loadOp: LoadOpClear,
    storeOp: StoreOpStore,
    clearValue: WgpuColor(r: red, g: green, b: blue, a: alpha))
  var passDescriptor = WgpuRenderPassDescriptor(
    label: emptyLabel,
    colorAttachmentCount: 1,
    colorAttachments: addr attachment)
  let renderPass = beginPass(encoder, addr passDescriptor)
  if renderPass == nil:
    raise newException(LibraryError, "wgpu-native did not create a render pass")
  if meshIndices.len > 0:
    if meshVertices.len == 0 or meshVertices.len mod 6 != 0:
      raise newException(LibraryError, "invalid WGPU mesh vertex layout")
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
      vertexSize = uint64(meshVertices.len * sizeof(float32))
      indexSize = uint64(meshIndices.len * sizeof(uint32))
    if runtime.vertexCapacity < vertexSize:
      if runtime.vertexBuffer != nil:
        releaseBuffer(runtime.vertexBuffer)
        runtime.vertexBuffer = nil
      runtime.uploadedToken = 0
      runtime.vertexCapacity = grownCapacity(runtime.vertexCapacity, vertexSize)
      var descriptor = WgpuBufferDescriptor(label: emptyLabel,
        usage: BufferUsageCopyDst or BufferUsageVertex,
        size: runtime.vertexCapacity)
      runtime.vertexBuffer = createBuffer(runtime.device, addr descriptor)
      if runtime.vertexBuffer == nil:
        runtime.vertexCapacity = 0
        raise newException(LibraryError,
          "wgpu-native did not create a vertex buffer")
    if runtime.indexCapacity < indexSize:
      if runtime.indexBuffer != nil:
        releaseBuffer(runtime.indexBuffer)
        runtime.indexBuffer = nil
      runtime.uploadedToken = 0
      runtime.indexCapacity = grownCapacity(runtime.indexCapacity, indexSize)
      var descriptor = WgpuBufferDescriptor(label: emptyLabel,
        usage: BufferUsageCopyDst or BufferUsageIndex,
        size: runtime.indexCapacity)
      runtime.indexBuffer = createBuffer(runtime.device, addr descriptor)
      if runtime.indexBuffer == nil:
        runtime.indexCapacity = 0
        raise newException(LibraryError,
          "wgpu-native did not create an index buffer")
    if uploadToken == 0 or runtime.uploadedToken != uploadToken:
      writeBuffer(runtime.queue, runtime.vertexBuffer, 0,
        unsafeAddr meshVertices[0], csize_t(vertexSize))
      writeBuffer(runtime.queue, runtime.indexBuffer, 0,
        unsafeAddr meshIndices[0], csize_t(indexSize))
      runtime.uploadedToken = uploadToken
      inc runtime.meshUploadCount
    setPipeline(renderPass, runtime.meshPipeline)
    setVertexBuffer(renderPass, 0, runtime.vertexBuffer, 0, vertexSize)
    setIndexBuffer(renderPass, runtime.indexBuffer, IndexFormatUint32, 0,
      indexSize)
    drawIndexed(renderPass, uint32(meshIndices.len), 1, 0, 0, 0)
  endPass(renderPass)
  releasePass(renderPass)
  var unpaddedRow, paddedRow, bufferSize: uint64
  if readback:
    unpaddedRow = uint64(width) * 4'u64
    paddedRow = (unpaddedRow + 255'u64) and not 255'u64
    if paddedRow > uint64(high(uint32)) or
        paddedRow > uint64(high(int)) div uint64(height):
      raise newException(LibraryError, "WGPU readback size exceeds host limits")
    bufferSize = paddedRow * uint64(height)
    if runtime.readbackCapacity < bufferSize:
      if runtime.readbackBuffer != nil:
        releaseBuffer(runtime.readbackBuffer)
        runtime.readbackBuffer = nil
      runtime.readbackCapacity = grownCapacity(runtime.readbackCapacity,
        bufferSize)
      var descriptor = WgpuBufferDescriptor(label: emptyLabel,
        usage: BufferUsageMapRead or BufferUsageCopyDst,
        size: runtime.readbackCapacity)
      runtime.readbackBuffer = createBuffer(runtime.device, addr descriptor)
      if runtime.readbackBuffer == nil:
        runtime.readbackCapacity = 0
        raise newException(LibraryError,
          "wgpu-native did not create a readback buffer")
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
  submit(runtime.queue, 1, addr submittedCommand)
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
  if runtime.deviceLostReason() != 0'u32:
    raise newException(LibraryError, "wgpu-native device was lost")
  if runtime.takeUncapturedError() != 0'u32:
    raise newException(LibraryError, "wgpu-native reported an uncaptured error")

proc renderClearPixels*(runtime: NativeWgpuRuntime; width, height: uint32;
                        red, green, blue, alpha: float64): seq[byte] =
  runtime.renderPixels(width, height, red, green, blue, alpha, [], [], true, 0)

proc renderMeshPixels*(runtime: NativeWgpuRuntime; width, height: uint32;
                       red, green, blue, alpha: float64;
                       vertices: openArray[float32];
                       indices: openArray[uint32]): seq[byte] =
  runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, true, 0)

proc renderPreparedMeshPixels*(runtime: NativeWgpuRuntime;
                               width, height: uint32;
                               red, green, blue, alpha: float64;
                               vertices: openArray[float32];
                               indices: openArray[uint32];
                               uploadToken: uint64): seq[byte] =
  if uploadToken == 0:
    raise newException(LibraryError, "prepared WGPU upload token is zero")
  runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, true, uploadToken)

proc submitMesh*(runtime: NativeWgpuRuntime; width, height: uint32;
                 red, green, blue, alpha: float64;
                 vertices: openArray[float32]; indices: openArray[uint32]) =
  discard runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, false, 0)

proc submitPreparedMesh*(runtime: NativeWgpuRuntime; width, height: uint32;
                         red, green, blue, alpha: float64;
                         vertices: openArray[float32];
                         indices: openArray[uint32]; uploadToken: uint64) =
  if uploadToken == 0:
    raise newException(LibraryError, "prepared WGPU upload token is zero")
  discard runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices, false, uploadToken)
