# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Minimal dynamically loaded wgpu-native 29 ABI used by the optional backend.
import std/[atomics, dynlib, os]

type
  WgpuStringView {.bycopy.} = object
    data: cstring
    length: csize_t

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

  WgpuRequestDeviceCallback = proc(status: uint32; device: pointer;
      message: WgpuStringView; userdata1, userdata2: pointer) {.cdecl.}

  WgpuRequestDeviceCallbackInfo {.bycopy.} = object
    nextInChain: pointer
    mode: uint32
    callback: WgpuRequestDeviceCallback
    userdata1, userdata2: pointer

  CreateInstanceProc = proc(descriptor: pointer): pointer {.cdecl.}
  EnumerateAdaptersProc = proc(instance, options: pointer;
      adapters: ptr pointer): csize_t {.cdecl.}
  ProcessEventsProc = proc(instance: pointer) {.cdecl.}
  RequestDeviceProc = proc(adapter, descriptor: pointer;
      callbackInfo: WgpuRequestDeviceCallbackInfo): WgpuFuture {.cdecl.}
  HasFeatureProc = proc(adapter: pointer; feature: uint32): uint32 {.cdecl.}
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

  DeviceRequest = object
    status: Atomic[uint32]
    device: pointer

  NativeWgpuRuntime* = ref object
    library: LibHandle
    instance, adapter, device, queue: pointer
    getVersion: GetVersionProc
    hasFeature: HasFeatureProc
    releaseInstance, releaseAdapter, releaseDevice, releaseQueue: ReleaseProc

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

proc loadSymbol[T](library: LibHandle; name: string): T =
  let address = library.symAddr(name)
  if address == nil:
    raise newException(LibraryError, "wgpu-native symbol missing: " & name)
  cast[T](address)

proc receiveDevice(status: uint32; device: pointer; message: WgpuStringView;
                   userdata1, userdata2: pointer) {.cdecl.} =
  discard message
  discard userdata2
  let request = cast[ptr DeviceRequest](userdata1)
  request.device = device
  request.status.store(status, moRelease)

proc close*(runtime: NativeWgpuRuntime) =
  if runtime.isNil: return
  if runtime.queue != nil and runtime.releaseQueue != nil:
    runtime.releaseQueue(runtime.queue)
    runtime.queue = nil
  if runtime.device != nil and runtime.releaseDevice != nil:
    runtime.releaseDevice(runtime.device)
    runtime.device = nil
  if runtime.adapter != nil and runtime.releaseAdapter != nil:
    runtime.releaseAdapter(runtime.adapter)
    runtime.adapter = nil
  if runtime.instance != nil and runtime.releaseInstance != nil:
    runtime.releaseInstance(runtime.instance)
    runtime.instance = nil
  if runtime.library != nil:
    runtime.library.unloadLib()
    runtime.library = nil

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
    result.getVersion = loadSymbol[GetVersionProc](library, "wgpuGetVersion")
    result.hasFeature = loadSymbol[HasFeatureProc](library,
        "wgpuAdapterHasFeature")
    result.releaseInstance = loadSymbol[ReleaseProc](library,
        "wgpuInstanceRelease")
    result.releaseAdapter = loadSymbol[ReleaseProc](library,
        "wgpuAdapterRelease")
    result.releaseDevice = loadSymbol[ReleaseProc](library,
        "wgpuDeviceRelease")
    result.releaseQueue = loadSymbol[ReleaseProc](library, "wgpuQueueRelease")

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

    let request = cast[ptr DeviceRequest](allocShared0(sizeof(DeviceRequest)))
    if request == nil:
      raise newException(LibraryError, "cannot allocate WGPU request state")
    discard requestDevice(result.adapter, nil,
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

proc submitClear*(runtime: NativeWgpuRuntime; width, height: uint32;
                  red, green, blue, alpha: float64) =
  ## Submit an actual offscreen render pass to the native queue.
  if runtime.isNil or runtime.device == nil or runtime.queue == nil:
    raise newException(LibraryError, "wgpu-native runtime is not ready")
  if width == 0 or height == 0:
    raise newException(LibraryError, "WGPU target dimensions must be positive")
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
  let emptyLabel = WgpuStringView(data: "".cstring, length: 0)
  var textureDescriptor = WgpuTextureDescriptor(
    label: emptyLabel,
    usage: TextureUsageCopySrc or TextureUsageRenderAttachment,
    dimension: TextureDimension2D,
    size: WgpuExtent3D(width: width, height: height,
      depthOrArrayLayers: 1),
    format: TextureFormatRgba8Unorm,
    mipLevelCount: 1,
    sampleCount: 1)
  let texture = createTexture(runtime.device, addr textureDescriptor)
  if texture == nil:
    raise newException(LibraryError, "wgpu-native did not create a texture")
  defer: releaseTexture(texture)
  let view = createView(texture, nil)
  if view == nil:
    raise newException(LibraryError, "wgpu-native did not create a texture view")
  defer: releaseView(view)
  let encoder = createEncoder(runtime.device, nil)
  if encoder == nil:
    raise newException(LibraryError, "wgpu-native did not create an encoder")
  defer: releaseEncoder(encoder)
  var attachment = WgpuRenderPassColorAttachment(
    view: view,
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
  endPass(renderPass)
  releasePass(renderPass)
  let command = finishEncoder(encoder, nil)
  if command == nil:
    raise newException(LibraryError, "wgpu-native did not create a command buffer")
  defer: releaseCommand(command)
  var submittedCommand = command
  submit(runtime.queue, 1, addr submittedCommand)
