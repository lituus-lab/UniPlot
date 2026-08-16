# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, sequtils, unittest]
import contracts
import UniColor
import UniGlyph
import UniImage/core as uimg
import UniPlot
import UniVector
import UniCrypto/hash/blake3/blake3 as ublake3
import UniPlot/render/wgpu

suite "WGPU boundary":
  test "scene resources are prepared without loading a GPU runtime":
    let background = parseColor("#ffffff").get
    let scene = initScene(Size(width: 100, height: 80), background)
    let frame = prepareWgpuFrame(scene)
    check frame.size.width == 100
    check not wgpuCapabilities().available
    check WgpuNativeTargetVersion == "29.0.1.1"

  test "scene identity covers render semantics and exact font content":
    let font = loadTtf("tests/DejaVuSans.ttf")
    var scene = initScene(Size(width: 100, height: 80),
      parseColor("#ffffff").get)
    scene.addPath(parsePath("M 1 1 L 20 1 L 20 20 Z"),
      parseColor("#3366cc").get, id = 7)
    scene.addText("axis", Point(x: 24, y: 30), 14,
      parseColor("#111111").get, id = 8)
    let original = scene.wgpuSceneIdentity(font)
    check ublake3.toHex(original) ==
      "e3ef1283a0151aabb4ad58de36cfa400632cf64f85debde665aea7ee11641d57"
    check scene.wgpuSceneIdentity(font) == original

    var metadataOnly = scene
    metadataOnly.nodes = scene.nodes.mapIt(it)
    metadataOnly.nodes[0].id = 99
    metadataOnly.nodes[0].path.at = vec2(999'f32, 999'f32)
    check metadataOnly.wgpuSceneIdentity(font) == original

    var changed = scene
    changed.nodes = scene.nodes.mapIt(it)
    changed.nodes[1].text = "axes"
    check changed.wgpuSceneIdentity(font) != original
    changed = scene
    changed.nodes = scene.nodes.mapIt(it)
    changed.nodes[0].path = scene.nodes[0].path.copy
    var command = changed.nodes[0].path.commands[1]
    command.p = vec2(21'f32, command.p.y)
    changed.nodes[0].path.commands[1] = command
    check changed.wgpuSceneIdentity(font) != original

    let raw = readFile("tests/DejaVuSans.ttf")
    var changedBytes = newSeq[byte](raw.len)
    copyMem(changedBytes[0].addr, raw[0].unsafeAddr, raw.len)
    changedBytes[^1] = changedBytes[^1] xor 1'u8
    let changedFont = loadTtfFromBytes(changedBytes)
    check scene.wgpuSceneIdentity(changedFont) != original

    var pathOnly = initScene(scene.size, scene.background)
    pathOnly.addPath(scene.nodes[0].path, scene.nodes[0].color)
    check pathOnly.wgpuSceneIdentity(font) ==
      pathOnly.wgpuSceneIdentity(changedFont)

  test "scene identity validates its public inputs":
    let scene = initScene(Size(width: 10, height: 10),
      parseColor("#ffffff").get)
    when defined(release):
      expect WgpuError:
        discard scene.wgpuSceneIdentity(Font(nil))
    else:
      expect PreConditionDefect:
        discard scene.wgpuSceneIdentity(Font(nil))

  test "image resources and exact pixels participate in scene identity":
    let font = loadTtf("tests/DejaVuSans.ttf")
    var image = uimg.newImage[uint8](1, 1, uimg.csRgba)
    image.data = @[1'u8, 2, 3, 4]
    var scene = initScene(Size(width: 10, height: 10),
      parseColor("#ffffff").get)
    scene.addImage(image, -2, 3, 127, id = 9)
    let original = scene.wgpuSceneIdentity(font)
    let frame = prepareWgpuFrame(scene)
    check frame.resources == @[WgpuResource(id: 9, kind: wrImageTexture)]
    scene.nodes[0].image.data[2] = 8
    check scene.wgpuSceneIdentity(font) != original
    var offscreen = initScene(Size(width: 10, height: 10),
      parseColor("#ffffff").get)
    offscreen.addImage(image, high(int), high(int))
    check offscreen.prepareWgpuScene(font).size == offscreen.size

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
      expect WgpuError:
        discard openWgpuBackend("/unused", uploadChunkBytes = 6)
      expect WgpuError:
        discard openWgpuBackend("/unused", managedGpuByteBudget =
          DefaultPreparedCacheByteBudget - 1)
      expect WgpuError:
        discard openWgpuBackend("/unused", streamingRingCapacity = 0)
      expect WgpuError:
        discard openWgpuBackend("/unused", sceneCacheCapacity = 0)
      expect WgpuError:
        discard openWgpuBackend("/unused", sceneCacheByteBudget =
          MinSceneCacheByteBudget - 1)
    else:
      expect PreConditionDefect: discard openWgpuBackend("/unused", 0)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", MaxPreparedCacheEntries + 1)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", preparedCacheByteBudget =
          MinPreparedCacheByteBudget - 1)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", uploadChunkBytes = 6)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", managedGpuByteBudget =
          DefaultPreparedCacheByteBudget - 1)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", streamingRingCapacity = 0)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", sceneCacheCapacity = 0)
      expect PreConditionDefect:
        discard openWgpuBackend("/unused", sceneCacheByteBudget =
          MinSceneCacheByteBudget - 1)

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
      check backend.wgpuDiagnostics.uploadChunkBytes == DefaultUploadChunkBytes
      check backend.wgpuDiagnostics.managedGpuByteBudget ==
        DefaultManagedGpuByteBudget
      check backend.wgpuDiagnostics.streamingRingCapacity ==
        DefaultStreamingRingEntries
      check backend.wgpuDiagnostics.sceneCacheCapacity ==
        DefaultSceneCacheEntries
      check backend.wgpuDiagnostics.sceneCacheByteBudget ==
        DefaultSceneCacheByteBudget
      check backend.wgpuDiagnostics.sceneCacheEntries == 0
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
      var raster = uimg.newImage[uint8](2, 1, uimg.csRgba)
      raster.data = @[255'u8, 0, 0, 255, 0, 255, 0, 255]
      var rasterScene = initScene(Size(width: 4, height: 3),
        parseColor("#ffffff").get)
      rasterScene.addImage(raster, -1, 1)
      var coveringPath = newPath()
      coveringPath.rect(0, 1, 1, 1)
      rasterScene.addPath(coveringPath, parseColor("#0000ff").get)
      var top = uimg.newImage[uint8](1, 1, uimg.csRgb)
      top.data = @[255'u8, 255, 0]
      rasterScene.addImage(top, 0, 1)
      let rasterBackend = openWgpuBackend(libraryPath)
      let
        rasterCpu = rasterScene.renderImage(
          loadTtf("tests/DejaVuSans.ttf")).data
        rasterGpu = rasterBackend.renderWgpuScene(rasterScene,
          loadTtf("tests/DejaVuSans.ttf"))
        covered = (1 * 4) * 4
      check rasterGpu == rasterCpu
      check rasterGpu[covered .. covered + 3] == @[255'u8, 255, 0, 255]
      check rasterBackend.wgpuDiagnostics.textureUploads == 2
      check rasterBackend.wgpuDiagnostics.textureUploadBytes == 8
      var first = uimg.newImage[uint8](1, 1, uimg.csRgba)
      first.data = @[255'u8, 0, 0, 128]
      var second = uimg.newImage[uint8](1, 1, uimg.csRgba)
      second.data = @[0'u8, 0, 255, 128]
      var alphaScene = initScene(Size(width: 1, height: 1),
        parseColor("#00000000").get)
      alphaScene.addImage(first, 0, 0)
      alphaScene.addImage(second, 0, 0)
      let
        alphaCpu = alphaScene.renderImage(
          loadTtf("tests/DejaVuSans.ttf")).data
        alphaGpu = rasterBackend.renderWgpuScene(alphaScene,
          loadTtf("tests/DejaVuSans.ttf"))
      check alphaGpu == alphaCpu
      check alphaGpu == @[85'u8, 0, 170, 192]
      rasterBackend.close()
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
      let managed = backend.wgpuDiagnostics
      check managed.managedGpuBytes == managed.preparedCacheBytes +
        managed.streamingBufferBytes + managed.targetTextureBytes +
        managed.readbackBufferBytes
      check managed.managedGpuBytes <= managed.managedGpuByteBudget
      check managed.managedGpuPeakBytes <= managed.managedGpuByteBudget
      backend.close()
      check backend.state == wbsUnavailable

      let automatic = openWgpuBackend(libraryPath,
        sceneCacheCapacity = 2, preparedCacheCapacity = 4)
      automatic.submitWgpuScene(scene, font)
      var automaticDiagnostics = automatic.wgpuDiagnostics
      check automaticDiagnostics.sceneCacheMisses == 1
      check automaticDiagnostics.sceneCacheHits == 0
      check automaticDiagnostics.sceneCacheEntries == 1
      check automaticDiagnostics.sceneCacheBytes > 0
      check automaticDiagnostics.meshUploads == 1
      automatic.submitWgpuScene(scene, font)
      var metadataScene = scene
      metadataScene.nodes = scene.nodes.mapIt(it)
      metadataScene.nodes[0].id = 1234
      automatic.submitWgpuScene(metadataScene, font)
      automaticDiagnostics = automatic.wgpuDiagnostics
      check automaticDiagnostics.sceneCacheHits == 2
      check automaticDiagnostics.meshUploads == 1

      var changedScene = scene
      changedScene.nodes = scene.nodes.mapIt(it)
      changedScene.nodes[1].text = "B"
      automatic.submitWgpuScene(changedScene, font)
      automatic.submitWgpuScene(thirdScene, font)
      automatic.submitWgpuScene(scene, font)
      automaticDiagnostics = automatic.wgpuDiagnostics
      check automaticDiagnostics.sceneCacheMisses == 4
      check automaticDiagnostics.sceneCacheHits == 2
      check automaticDiagnostics.sceneCacheEvictions == 2
      check automaticDiagnostics.sceneCacheEntries == 2
      check automaticDiagnostics.sceneCacheBytes <=
        automaticDiagnostics.sceneCacheByteBudget
      check automaticDiagnostics.meshUploads == 4
      automatic.clearWgpuSceneCache()
      automaticDiagnostics = automatic.wgpuDiagnostics
      check automaticDiagnostics.sceneCacheEntries == 0
      check automaticDiagnostics.sceneCacheBytes == 0
      check automaticDiagnostics.sceneCachePeakBytes > 0
      automatic.close()

      let uncachedLarge = openWgpuBackend(libraryPath,
        sceneCacheByteBudget = MinSceneCacheByteBudget)
      uncachedLarge.submitWgpuScene(scene, font)
      let uncachedDiagnostics = uncachedLarge.wgpuDiagnostics
      check uncachedDiagnostics.sceneCacheMisses == 1
      check uncachedDiagnostics.sceneCacheEntries == 0
      check uncachedDiagnostics.sceneCacheBytes == 0
      uncachedLarge.close()

      let chunked = openWgpuBackend(libraryPath, uploadChunkBytes = 16)
      let chunkedPixels = chunked.readWgpuMeshTarget(
        Size(width: 10, height: 10), parseColor("#ffffff").get, mesh,
        parseColor("#ff0000").get)
      let
        expectedVertexBytes = uint64(mesh.vertices.len * 6 * sizeof(float32))
        expectedIndexBytes = uint64(mesh.indices.len * sizeof(uint32))
        expectedWriteCalls = (expectedVertexBytes + 15'u64) div 16'u64 +
          (expectedIndexBytes + 15'u64) div 16'u64
        chunkedDiagnostics = chunked.wgpuDiagnostics
      check chunkedPixels == meshPixels
      check chunkedDiagnostics.meshUploads == 1
      check chunkedDiagnostics.uploadBytes ==
        expectedVertexBytes + expectedIndexBytes
      check chunkedDiagnostics.uploadWriteCalls == expectedWriteCalls
      check chunkedDiagnostics.largestUploadWrite <= 16
      chunked.close()

      let ring = openWgpuBackend(libraryPath, streamingRingCapacity = 2)
      for _ in 0 ..< 3:
        ring.submitWgpuMeshTarget(Size(width: 10, height: 10),
          parseColor("#ffffff").get, mesh, parseColor("#ff0000").get)
      var ringDiagnostics = ring.wgpuDiagnostics
      check ringDiagnostics.streamingRingEntries == 2
      check ringDiagnostics.streamingRingRotations == 3
      check ringDiagnostics.streamingRingSyncs == 1
      check ringDiagnostics.streamingBufferBytes > 0
      check ringDiagnostics.managedGpuBytes <=
        ringDiagnostics.managedGpuByteBudget
      let ringPixels = ring.readWgpuMeshTarget(Size(width: 10, height: 10),
        parseColor("#ffffff").get, mesh, parseColor("#ff0000").get)
      check ringPixels == meshPixels
      ringDiagnostics = ring.wgpuDiagnostics
      check ringDiagnostics.streamingRingRotations == 4
      check ringDiagnostics.streamingRingSyncs == 2
      ring.close()

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

      let targetBytes = uint64(scene.size.width * scene.size.height * 4)
      let globallyLimited = openWgpuBackend(libraryPath,
        preparedCacheCapacity = 2,
        preparedCacheByteBudget = oneSceneBytes + targetBytes,
        managedGpuByteBudget = oneSceneBytes + targetBytes)
      globallyLimited.submitWgpuPrepared(prepared)
      globallyLimited.submitWgpuPrepared(samePrepared)
      let limitedDiagnostics = globallyLimited.wgpuDiagnostics
      check limitedDiagnostics.preparedCacheEntries == 1
      check limitedDiagnostics.preparedCacheEvictions == 1
      check limitedDiagnostics.managedGpuBytes <=
        limitedDiagnostics.managedGpuByteBudget
      globallyLimited.close()

      let targetLimited = openWgpuBackend(libraryPath,
        preparedCacheByteBudget = MinPreparedCacheByteBudget,
        managedGpuByteBudget = MinManagedGpuByteBudget * 2)
      expect WgpuError:
        discard targetLimited.readWgpuClearTarget(Size(width: 64, height: 64),
          parseColor("#ffffff").get)
      check targetLimited.wgpuDiagnostics.managedGpuBytes == 0
      let recovered = targetLimited.readWgpuClearTarget(
        Size(width: 4, height: 4), parseColor("#204060").get)
      check recovered.len == 4 * 4 * 4
      targetLimited.close()
