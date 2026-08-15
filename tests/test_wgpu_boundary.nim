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

  test "prepared cache entry and byte bounds are contractual":
    when defined(release):
      expect WgpuError: discard openWgpuBackend("/unused", 0)
      expect WgpuError:
        discard openWgpuBackend("/unused", MaxPreparedCacheEntries + 1)
      expect WgpuError:
        discard openWgpuBackend("/unused", preparedCacheByteBudget =
          MinPreparedCacheByteBudget - 1)
    else:
      expect PreConditionDefect: discard openWgpuBackend("/unused", 0)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", MaxPreparedCacheEntries + 1)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", preparedCacheByteBudget =
          MinPreparedCacheByteBudget - 1)

  test "a configured native runtime submits an offscreen render pass":
    let libraryPath = getEnv("UNIPLOT_WGPU_LIBRARY")
    if libraryPath.len == 0:
      skip()
    else:
      let backend = openWgpuBackend(libraryPath, preparedCacheCapacity = 2)
      check backend.state == wbsReady
      check backend.wgpuDiagnostics.preparedCacheCapacity == 2
      check backend.wgpuDiagnostics.preparedCacheEntries == 0
      check backend.wgpuDiagnostics.preparedCacheByteBudget ==
        DefaultPreparedCacheByteBudget
      let capabilities = wgpuCapabilities(backend)
      check capabilities.available
      check capabilities.storageBuffers
      check capabilities.adapterName.len > 0
      check capabilities.backend.len > 0
      check capabilities.maxTextureDimension2D >= 64
      check capabilities.maxBufferSize > 0
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
      let antialiasedPath = parsePath(
        "M 2.25 2.25 L 7.75 2.25 L 7.75 7.75 L 2.25 7.75 Z")
      let antialiasedMesh = antialiasedPath.preparePath().tessellateFill()
      let antialiasedGpu = backend.readWgpuMeshTarget(
        Size(width: 10, height: 10), parseColor("#ffffff").get,
        antialiasedMesh, parseColor("#ff0000").get)
      var antialiasedScene = initScene(Size(width: 10, height: 10),
        parseColor("#ffffff").get)
      antialiasedScene.addPath(antialiasedPath, parseColor("#ff0000").get)
      let antialiasedCpu = antialiasedScene.renderImage(
        loadTtf("tests/DejaVuSans.ttf")).data
      var differingEdgePixels = 0
      for y in 0 ..< 10:
        for x in 0 ..< 10:
          let offset = (y * 10 + x) * 4
          if antialiasedGpu[offset .. offset + 3] !=
              antialiasedCpu[offset .. offset + 3]:
            inc differingEdgePixels
            check x in {2, 7} or y in {2, 7}
      check differingEdgePixels <= 20
      var scene = initScene(Size(width: 64, height: 32),
        parseColor("#ffffff").get)
      scene.addPath(parsePath("M 2 2 L 20 2 L 20 20 L 2 20 Z"),
        parseColor("#ff0000").get)
      scene.addText("A", Point(x: 24, y: 20), 16,
        parseColor("#000000").get)
      let font = loadTtf("tests/DejaVuSans.ttf")
      let prepared = scene.prepareWgpuScene(font)
      check prepared.size == scene.size
      let uploadsBeforePrepared = backend.wgpuDiagnostics.meshUploads
      backend.submitWgpuPrepared(prepared)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 1
      let oneSceneBytes = backend.wgpuDiagnostics.preparedCacheBytes
      check oneSceneBytes > MinPreparedCacheByteBudget
      check backend.wgpuDiagnostics.preparedCachePeakBytes == oneSceneBytes
      backend.submitWgpuPrepared(prepared)
      let scenePixels = backend.renderWgpuPrepared(prepared)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 1
      check scenePixels.len == 64 * 32 * 4
      check scenePixels[(10 * 64 + 10) * 4 .. (10 * 64 + 10) * 4 + 3] ==
        @[255'u8, 0, 0, 255]
      check scenePixels.anyIt(it != 255'u8)
      discard backend.readWgpuMeshTarget(Size(width: 10, height: 10),
        parseColor("#ffffff").get, mesh, parseColor("#ff0000").get)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 2
      backend.submitWgpuPrepared(prepared)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 2
      var styledFrame = initDataFrame()
      styledFrame.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0])
      styledFrame.addColumn("y", [1.0, 2.0, NaN, 2.0, 1.0])
      var styledSpec = plot(styledFrame)
      styledSpec.geomLine(aes("x", "y"), color = "#3366cc", width = 2,
        lineStyle = DotDashLine)
      styledSpec.geomPoint(aes("x", "y", color = "x"), radius = 3,
        shape = DiamondMarker)
      let styledSize = Size(width: 320, height: 240)
      let styledPrepared = styledSpec.compileScene(styledSize).prepareWgpuScene(
        font)
      let styledPixels = backend.renderWgpuPrepared(styledPrepared)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 3
      check styledPixels.len == styledSize.width * styledSize.height * 4
      check styledPixels.anyIt(it != 255'u8)
      var thirdScene = initScene(Size(width: 16, height: 16),
        parseColor("#ffffff").get)
      thirdScene.addPath(parsePath("M 1 1 L 8 1 L 8 8 Z"),
        parseColor("#00aa00").get)
      let thirdPrepared = thirdScene.prepareWgpuScene(font)
      backend.submitWgpuPrepared(thirdPrepared)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 4
      check backend.wgpuDiagnostics.preparedCacheEntries == 2
      check backend.wgpuDiagnostics.preparedCacheEvictions == 1
      backend.submitWgpuPrepared(prepared)
      check backend.wgpuDiagnostics.meshUploads == uploadsBeforePrepared + 5
      check backend.wgpuDiagnostics.preparedCacheEvictions == 2
      check backend.wgpuDiagnostics.preparedCacheMisses == 4
      check backend.wgpuDiagnostics.preparedCacheHits == 3
      backend.close()
      check backend.state == wbsUnavailable

      let samePrepared = scene.prepareWgpuScene(font)
      let byteLimited = openWgpuBackend(libraryPath,
        preparedCacheCapacity = 2, preparedCacheByteBudget = oneSceneBytes)
      byteLimited.submitWgpuPrepared(prepared)
      byteLimited.submitWgpuPrepared(samePrepared)
      check byteLimited.wgpuDiagnostics.preparedCacheEntries == 1
      check byteLimited.wgpuDiagnostics.preparedCacheEvictions == 1
      check byteLimited.wgpuDiagnostics.preparedCacheBytes <= oneSceneBytes
      byteLimited.close()

      let tooSmall = openWgpuBackend(libraryPath,
        preparedCacheCapacity = 2,
        preparedCacheByteBudget = oneSceneBytes - 1)
      expect WgpuError: tooSmall.submitWgpuPrepared(prepared)
      check tooSmall.wgpuDiagnostics.preparedCacheEntries == 0
      check tooSmall.wgpuDiagnostics.preparedCacheBytes == 0
      tooSmall.close()
