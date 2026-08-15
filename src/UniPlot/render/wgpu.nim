# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Optional WGPU backend contract. This module contains no loader or foreign
## call, so importing it does not require wgpu-native.
import UniPlot/[common, scene]

const WgpuNativeTargetVersion* = "29.0.1.1"

type
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

proc prepareWgpuFrame*(scene: Scene): WgpuFrame =
  ## Extract stable semantic resource identifiers before any device is needed.
  result.size = scene.size
  result.nodeCount = scene.nodes.len
  for node in scene.nodes:
    if node.id != 0:
      let kind = if node.kind == snText: wrGlyphAtlas else: wrPathMesh
      result.resources.add WgpuResource(id: node.id, kind: kind)

proc wgpuCapabilities*(): WgpuCapabilities =
  ## The core reports unavailable until the optional native backend is linked.
  WgpuCapabilities(implementationVersion: WgpuNativeTargetVersion)
