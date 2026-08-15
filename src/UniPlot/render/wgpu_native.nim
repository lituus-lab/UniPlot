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

  DeviceRequest = object
    status: Atomic[uint32]
    device: pointer

  MapRequest = object
    status: Atomic[uint32]

  NativeWgpuRuntime* = ref object
    library: LibHandle
    instance, adapter, device, queue: pointer
    meshShader, meshPipeline: pointer
    getVersion: GetVersionProc
    hasFeature: HasFeatureProc
    releaseInstance, releaseAdapter, releaseDevice, releaseQueue: ReleaseProc
    releaseShader, releasePipeline: ReleaseProc

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

proc receiveMap(status: uint32; message: WgpuStringView;
                userdata1, userdata2: pointer) {.cdecl.} =
  discard message
  discard userdata2
  cast[ptr MapRequest](userdata1).status.store(status, moRelease)

proc close*(runtime: NativeWgpuRuntime) =
  if runtime.isNil: return
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

proc renderPixels(runtime: NativeWgpuRuntime; width, height: uint32;
                  red, green, blue, alpha: float64;
                  meshVertices: openArray[float32];
                  meshIndices: openArray[uint32]): seq[byte] =
  ## Render, read back, and remove WebGPU's per-row copy padding.
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
    var vertexDescriptor = WgpuBufferDescriptor(label: emptyLabel,
      usage: BufferUsageCopyDst or BufferUsageVertex, size: vertexSize)
    var indexDescriptor = WgpuBufferDescriptor(label: emptyLabel,
      usage: BufferUsageCopyDst or BufferUsageIndex, size: indexSize)
    let vertexBuffer = createBuffer(runtime.device, addr vertexDescriptor)
    if vertexBuffer == nil:
      raise newException(LibraryError, "wgpu-native did not create a vertex buffer")
    defer: releaseBuffer(vertexBuffer)
    let indexBuffer = createBuffer(runtime.device, addr indexDescriptor)
    if indexBuffer == nil:
      raise newException(LibraryError, "wgpu-native did not create an index buffer")
    defer: releaseBuffer(indexBuffer)
    writeBuffer(runtime.queue, vertexBuffer, 0,
      unsafeAddr meshVertices[0], csize_t(vertexSize))
    writeBuffer(runtime.queue, indexBuffer, 0,
      unsafeAddr meshIndices[0], csize_t(indexSize))
    setPipeline(renderPass, runtime.meshPipeline)
    setVertexBuffer(renderPass, 0, vertexBuffer, 0, vertexSize)
    setIndexBuffer(renderPass, indexBuffer, IndexFormatUint32, 0, indexSize)
    drawIndexed(renderPass, uint32(meshIndices.len), 1, 0, 0, 0)
  endPass(renderPass)
  releasePass(renderPass)
  let unpaddedRow = uint64(width) * 4'u64
  let paddedRow = (unpaddedRow + 255'u64) and not 255'u64
  if paddedRow > uint64(high(uint32)) or
      paddedRow > uint64(high(int)) div uint64(height):
    raise newException(LibraryError, "WGPU readback size exceeds host limits")
  let bufferSize = paddedRow * uint64(height)
  var bufferDescriptor = WgpuBufferDescriptor(label: emptyLabel,
    usage: BufferUsageMapRead or BufferUsageCopyDst, size: bufferSize)
  let readback = createBuffer(runtime.device, addr bufferDescriptor)
  if readback == nil:
    raise newException(LibraryError, "wgpu-native did not create a readback buffer")
  defer: releaseBuffer(readback)
  var source = WgpuTexelCopyTextureInfo(texture: texture,
    aspect: TextureAspectAll)
  var destination = WgpuTexelCopyBufferInfo(
    layout: WgpuTexelCopyBufferLayout(bytesPerRow: uint32(paddedRow),
      rowsPerImage: height), buffer: readback)
  var copySize = WgpuExtent3D(width: width, height: height,
    depthOrArrayLayers: 1)
  copyTextureToBuffer(encoder, addr source, addr destination, addr copySize)
  let command = finishEncoder(encoder, nil)
  if command == nil:
    raise newException(LibraryError, "wgpu-native did not create a command buffer")
  defer: releaseCommand(command)
  var submittedCommand = command
  submit(runtime.queue, 1, addr submittedCommand)
  let request = cast[ptr MapRequest](allocShared0(sizeof(MapRequest)))
  if request == nil:
    raise newException(LibraryError, "cannot allocate WGPU map state")
  discard mapBuffer(readback, MapModeRead, 0, csize_t(bufferSize),
    WgpuBufferMapCallbackInfo(mode: CallbackAllowProcessEvents,
      callback: receiveMap, userdata1: request))
  var attempts = 0
  while request.status.load(moAcquire) == 0'u32 and attempts < 10_000:
    processEvents(runtime.instance)
    inc attempts
    sleep(1)
  let mapStatus = request.status.load(moAcquire)
  deallocShared(request)
  if mapStatus == 0'u32:
    raise newException(LibraryError, "wgpu-native buffer mapping timed out")
  if mapStatus != MapSuccess:
    raise newException(LibraryError, "wgpu-native buffer mapping failed")
  let mapped = getMappedRange(readback, 0, csize_t(bufferSize))
  if mapped == nil:
    raise newException(LibraryError, "wgpu-native returned no mapped data")
  defer: unmapBuffer(readback)
  let outputSize = int(unpaddedRow * uint64(height))
  result = newSeq[byte](outputSize)
  let sourceBytes = cast[ptr UncheckedArray[byte]](mapped)
  for row in 0 ..< int(height):
    copyMem(addr result[row * int(unpaddedRow)],
      unsafeAddr sourceBytes[row * int(paddedRow)], int(unpaddedRow))

proc renderClearPixels*(runtime: NativeWgpuRuntime; width, height: uint32;
                        red, green, blue, alpha: float64): seq[byte] =
  runtime.renderPixels(width, height, red, green, blue, alpha, [], [])

proc renderMeshPixels*(runtime: NativeWgpuRuntime; width, height: uint32;
                       red, green, blue, alpha: float64;
                       vertices: openArray[float32];
                       indices: openArray[uint32]): seq[byte] =
  runtime.renderPixels(width, height, red, green, blue, alpha,
    vertices, indices)
