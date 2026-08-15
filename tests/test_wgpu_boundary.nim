# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, unittest]
import contracts
import UniColor
import UniPlot
import UniPlot/render/wgpu

suite "WGPU boundary":
  test "scene resources are prepared without loading a GPU runtime":
    let background = parseColor("#ffffff").get
    let scene = initScene(Size(width: 100, height: 80), background)
    let frame = prepareWgpuFrame(scene)
    check frame.size.width == 100
    check not wgpuCapabilities().available
    check WgpuNativeTargetVersion == "29.0.1.1"

  test "an invalid runtime path fails without affecting the core":
    expect WgpuError:
      discard openWgpuBackend("/definitely/missing/libwgpu_native")
    check not wgpuCapabilities().available

  when not defined(release):
    test "an empty runtime path violates the public contract":
      expect PreConditionDefect:
        discard openWgpuBackend("")

  test "a configured native runtime creates a device and queue":
    let libraryPath = getEnv("UNIPLOT_WGPU_LIBRARY")
    if libraryPath.len == 0:
      skip()
    else:
      let backend = openWgpuBackend(libraryPath)
      check backend.state == wbsReady
      check wgpuCapabilities(backend).available
      check wgpuCapabilities(backend).storageBuffers
      backend.close()
      check backend.state == wbsUnavailable
