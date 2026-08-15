# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, sequtils, unittest]
import contracts
import UniColor
import UniGlyph
import UniPlot
import UniVector
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

  test "a configured native runtime submits an offscreen render pass":
    let libraryPath = getEnv("UNIPLOT_WGPU_LIBRARY")
    if libraryPath.len == 0:
      skip()
    else:
      let backend = openWgpuBackend(libraryPath)
      check backend.state == wbsReady
      check wgpuCapabilities(backend).available
      check wgpuCapabilities(backend).storageBuffers
      let pixels = backend.readWgpuClearTarget(Size(width: 17, height: 9),
        parseColor("#204060").get)
      check pixels.len == 17 * 9 * 4
      for offset in countup(0, pixels.high, 4):
        check pixels[offset .. offset + 3] == @[32'u8, 64, 96, 255]
      let mesh = parsePath("M 2 2 L 8 2 L 8 8 L 2 8 Z")
        .preparePath().tessellateFill()
      let meshPixels = backend.readWgpuMeshTarget(Size(width: 10, height: 10),
        parseColor("#ffffff").get, mesh, parseColor("#ff0000").get)
      let center = (5 * 10 + 5) * 4
      check meshPixels[center .. center + 3] == @[255'u8, 0, 0, 255]
      check meshPixels[0 .. 3] == @[255'u8, 255, 255, 255]
      var parityScene = initScene(Size(width: 10, height: 10),
        parseColor("#ffffff").get)
      parityScene.addPath(parsePath("M 2 2 L 8 2 L 8 8 L 2 8 Z"),
        parseColor("#ff0000").get)
      let cpuPixels = parityScene.renderImage(
        loadTtf("tests/DejaVuSans.ttf")).data
      var differentChannels = 0
      for index, value in meshPixels:
        if value != cpuPixels[index]: inc differentChannels
      check differentChannels == 0
      var scene = initScene(Size(width: 64, height: 32),
        parseColor("#ffffff").get)
      scene.addPath(parsePath("M 2 2 L 20 2 L 20 20 L 2 20 Z"),
        parseColor("#ff0000").get)
      scene.addText("A", Point(x: 24, y: 20), 16,
        parseColor("#000000").get)
      let font = loadTtf("tests/DejaVuSans.ttf")
      backend.submitWgpuScene(scene, font)
      backend.submitWgpuScene(scene, font)
      let scenePixels = backend.renderWgpuScene(scene, font)
      check scenePixels.len == 64 * 32 * 4
      check scenePixels[(10 * 64 + 10) * 4 .. (10 * 64 + 10) * 4 + 3] ==
        @[255'u8, 0, 0, 255]
      check scenePixels.anyIt(it != 255'u8)
      backend.close()
      check backend.state == wbsUnavailable
