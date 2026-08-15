# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Optional WGPU backend. Importing it does not load wgpu-native; opening a
## backend dynamically loads the caller-selected native library.
import contracts
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
