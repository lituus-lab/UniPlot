# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, math, monotimes, os, stats, strutils, times]
import UniColor
import UniGlyph
import UniPlot
import UniVector
import UniPlot/render/wgpu

proc elapsedMs(started: MonoTime): float64 =
  inNanoseconds(getMonoTime() - started).float64 / 1_000_000.0

proc summary(samples: RunningStat): JsonNode =
  %*{"mean_ms": samples.mean, "stdev_ms": samples.standardDeviationS,
    "min_ms": samples.min, "max_ms": samples.max}

proc checkBaseline(report: JsonNode; path: string) =
  let baseline = parseFile(path)
  for field in ["adapter", "backend", "points", "canvas", "residency"]:
    if baseline[field] != report[field]:
      quit("WGPU baseline does not match current " & field, 1)
  for phase in ["preparation", "scene_identity", "scene_cache_hit",
      "automatic_submit", "upload_submit", "submit",
      "publication_frame", "direct_burst_single", "direct_burst_ring"]:
    let
      expected = baseline[phase]["mean_ms"].getFloat
      maxRatio = baseline[phase]["max_ratio"].getFloat
      observed = report[phase]["mean_ms"].getFloat
    if expected <= 0 or maxRatio < 1.0:
      quit("invalid WGPU baseline threshold for " & phase, 1)
    if observed > expected * maxRatio:
      quit(phase & " regressed: " & $observed & " ms > " &
        $(expected * maxRatio) & " ms", 1)

proc sampleSpec(count: int): PlotSpec =
  var x = newSeq[float64](count)
  var y = newSeq[float64](count)
  for index in 0 ..< count:
    x[index] = float64(index) / 25.0
    y[index] = sin(x[index]) + 0.02 * x[index]
  result = linePlot(x, y)
  result.geomPoint(aes("x", "y"), color = "#cc3344", radius = 2)
  result.labels(title = "WGPU benchmark", x = "x", y = "y")

proc main() =
  let iterations = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
  let pointCount = if paramCount() >= 2: parseInt(paramStr(2)) else: 1000
  if iterations <= 0 or pointCount <= 0:
    quit("iterations and point count must be positive", 1)
  let libraryPath = getEnv("UNIPLOT_WGPU_LIBRARY")
  if libraryPath.len == 0:
    quit("UNIPLOT_WGPU_LIBRARY is not configured", 1)
  let
    font = loadTtf("tests/DejaVuSans.ttf")
    size = Size(width: 800, height: 500)
    scene = sampleSpec(pointCount).compileScene(size)
    backend = openWgpuBackend(libraryPath, preparedCacheCapacity = 2)
  defer: backend.close()
  let capabilities = wgpuCapabilities(backend)
  var preparationTimes, uploadSubmitTimes, submitTimes, frameTimes: RunningStat
  var identityTimes, cacheHitTimes, automaticSubmitTimes: RunningStat
  var directSingleTimes, directRingTimes: RunningStat
  var prepared: WgpuPreparedScene
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    prepared = scene.prepareWgpuScene(font)
    let preparationMs = elapsedMs(started)
    if iteration >= 3: preparationTimes.push(preparationMs)
  let
    alternatePrepared = scene.prepareWgpuScene(font)
    thirdPrepared = scene.prepareWgpuScene(font)
  let uploadsBefore = backend.wgpuDiagnostics.meshUploads
  for iteration in 0 ..< iterations + 3:
    let candidate = case iteration mod 3
      of 0: prepared
      of 1: alternatePrepared
      else: thirdPrepared
    let
      started = getMonoTime()
    backend.submitWgpuPrepared(candidate)
    let uploadSubmitMs = elapsedMs(started)
    if iteration >= 3: uploadSubmitTimes.push(uploadSubmitMs)
  if backend.wgpuDiagnostics.meshUploads != uploadsBefore +
      uint64(iterations + 3):
    quit("three prepared scenes in two cache slots did not upload each time", 1)
  # Make two scenes resident before measuring upload-free alternation.
  backend.submitWgpuPrepared(prepared)
  backend.submitWgpuPrepared(alternatePrepared)
  let uploadsBeforeWarm = backend.wgpuDiagnostics.meshUploads
  var consumed = 0'u8
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    let candidate = if (iteration and 1) == 0: prepared else: alternatePrepared
    backend.submitWgpuPrepared(candidate)
    let submitMs = elapsedMs(started)
    if iteration >= 3: submitTimes.push(submitMs)
  if backend.wgpuDiagnostics.meshUploads != uploadsBeforeWarm:
    quit("resident prepared scenes were uploaded during warm submission", 1)
  # The first publication frame drains the ordered submissions above.
  discard backend.renderWgpuPrepared(prepared)
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    let pixels = backend.renderWgpuPrepared(prepared)
    let frameMs = elapsedMs(started)
    consumed = consumed xor pixels[(iteration * 4) mod pixels.len]
    if iteration >= 3: frameTimes.push(frameMs)
  if backend.wgpuDiagnostics.meshUploads != uploadsBeforeWarm:
    quit("resident prepared scene was uploaded during publication", 1)
  let diagnostics = backend.wgpuDiagnostics
  if diagnostics.largestUploadWrite > diagnostics.uploadChunkBytes:
    quit("a queue write exceeded the configured upload chunk", 1)
  if diagnostics.uploadWriteCalls < diagnostics.meshUploads * 2'u64:
    quit("mesh uploads did not issue both vertex and index writes", 1)
  if diagnostics.managedGpuBytes > diagnostics.managedGpuByteBudget or
      diagnostics.managedGpuPeakBytes > diagnostics.managedGpuByteBudget:
    quit("managed GPU resources exceeded their byte budget", 1)
  if diagnostics.managedGpuBytes != diagnostics.preparedCacheBytes +
      diagnostics.streamingBufferBytes + diagnostics.targetTextureBytes +
      diagnostics.readbackBufferBytes:
    quit("managed GPU resource accounting is inconsistent", 1)
  let automaticBackend = openWgpuBackend(libraryPath)
  defer: automaticBackend.close()
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    discard scene.wgpuSceneIdentity(font)
    let identityMs = elapsedMs(started)
    if iteration >= 3: identityTimes.push(identityMs)
  let cachedPrepared = automaticBackend.prepareWgpuSceneCached(scene, font)
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    let candidate = automaticBackend.prepareWgpuSceneCached(scene, font)
    let cacheHitMs = elapsedMs(started)
    if cast[pointer](candidate) != cast[pointer](cachedPrepared):
      quit("automatic scene cache did not return its retained preparation", 1)
    if iteration >= 3: cacheHitTimes.push(cacheHitMs)
  automaticBackend.submitWgpuScene(scene, font)
  let automaticUploads = automaticBackend.wgpuDiagnostics.meshUploads
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    automaticBackend.submitWgpuScene(scene, font)
    let automaticSubmitMs = elapsedMs(started)
    if iteration >= 3: automaticSubmitTimes.push(automaticSubmitMs)
  let automaticDiagnostics = automaticBackend.wgpuDiagnostics
  if automaticDiagnostics.meshUploads != automaticUploads or
      automaticDiagnostics.sceneCacheMisses != 1 or
      automaticDiagnostics.sceneCacheHits != uint64((iterations + 3) * 2 + 1):
    quit("automatic prepared-scene cache accounting is inconsistent", 1)
  automaticBackend.waitWgpuIdle()
  let
    directMesh = parsePath("M 20 20 L 780 20 L 780 480 L 20 480 Z")
      .preparePath().tessellateFill()
    directSize = Size(width: 800, height: 500)
    directBackground = parseColor("#ffffff").get
    directColor = parseColor("#3366cc").get
    singleBackend = openWgpuBackend(libraryPath, streamingRingCapacity = 1)
    ringBackend = openWgpuBackend(libraryPath, streamingRingCapacity = 3)
  defer:
    singleBackend.close()
    ringBackend.close()
  for iteration in 0 ..< iterations + 3:
    singleBackend.waitWgpuIdle()
    ringBackend.waitWgpuIdle()
    if (iteration and 1) == 0:
      var started = getMonoTime()
      for _ in 0 ..< 3:
        singleBackend.submitWgpuMeshTarget(directSize, directBackground,
          directMesh, directColor)
      let singleMs = elapsedMs(started)
      started = getMonoTime()
      for _ in 0 ..< 3:
        ringBackend.submitWgpuMeshTarget(directSize, directBackground,
          directMesh, directColor)
      let ringMs = elapsedMs(started)
      if iteration >= 3:
        directSingleTimes.push(singleMs)
        directRingTimes.push(ringMs)
    else:
      var started = getMonoTime()
      for _ in 0 ..< 3:
        ringBackend.submitWgpuMeshTarget(directSize, directBackground,
          directMesh, directColor)
      let ringMs = elapsedMs(started)
      started = getMonoTime()
      for _ in 0 ..< 3:
        singleBackend.submitWgpuMeshTarget(directSize, directBackground,
          directMesh, directColor)
      let singleMs = elapsedMs(started)
      if iteration >= 3:
        directSingleTimes.push(singleMs)
        directRingTimes.push(ringMs)
  let
    singleDiagnostics = singleBackend.wgpuDiagnostics
    ringDiagnostics = ringBackend.wgpuDiagnostics
    directBursts = uint64(iterations + 3)
    directSubmissions = directBursts * 3'u64
  if singleDiagnostics.streamingRingRotations != directSubmissions or
      singleDiagnostics.streamingRingSyncs != directBursts * 2'u64:
    quit("single streaming slot did not synchronize twice per burst", 1)
  if ringDiagnostics.streamingRingRotations != directSubmissions or
      ringDiagnostics.streamingRingSyncs != 0:
    quit("three-slot streaming ring lifetime accounting is inconsistent", 1)
  let report = %*{
    "provider": "UniPlot-WGPU",
    "wgpu_native": WgpuNativeTargetVersion,
    "adapter": capabilities.adapterName,
    "backend": capabilities.backend,
    "iterations": iterations,
    "warmup_iterations": 3,
    "points": pointCount,
    "canvas": "800x500",
    "residency": "managed-budget-chunked-lru-ring-3-scene-key-v1",
    "semantics": {
      "preparation": "shape UniGlyph text and tessellate UniVector paths",
      "scene_identity": "hash canonical render semantics and exact font identity",
      "scene_cache_hit": "hash and return one retained host preparation",
      "automatic_submit": "hash, hit both host and GPU caches, then enqueue",
      "upload_submit": "cycle three identities through two slots and enqueue",
      "submit": "alternate two resident identities without upload/readback",
      "publication_frame": "submit resident geometry and read back RGBA8",
      "direct_burst_single": "three direct submissions from idle through one fenced slot",
      "direct_burst_ring": "three direct submissions from idle through three fenced slots",
      "prepared_cache_bytes": "allocated prepared vertex/index capacities only",
      "scene_cache_bytes": "retained host vertex/index logical payload only",
      "upload_writes": "queue writes split at the configured byte bound",
      "managed_gpu_bytes": "tracked buffers plus logical RGBA target bytes"
    },
    "preparation": summary(preparationTimes),
    "scene_identity": summary(identityTimes),
    "scene_cache_hit": summary(cacheHitTimes),
    "automatic_submit": summary(automaticSubmitTimes),
    "upload_submit": summary(uploadSubmitTimes),
    "submit": summary(submitTimes),
    "publication_frame": summary(frameTimes),
    "direct_burst_single": summary(directSingleTimes),
    "direct_burst_ring": summary(directRingTimes),
    "mesh_uploads": diagnostics.meshUploads,
    "upload_write_calls": diagnostics.uploadWriteCalls,
    "upload_bytes": diagnostics.uploadBytes,
    "largest_upload_write": diagnostics.largestUploadWrite,
    "upload_chunk_bytes": diagnostics.uploadChunkBytes,
    "prepared_cache_hits": diagnostics.preparedCacheHits,
    "prepared_cache_misses": diagnostics.preparedCacheMisses,
    "prepared_cache_evictions": diagnostics.preparedCacheEvictions,
    "prepared_cache_bytes": diagnostics.preparedCacheBytes,
    "prepared_cache_peak_bytes":
      diagnostics.preparedCachePeakBytes,
    "prepared_cache_byte_budget":
      diagnostics.preparedCacheByteBudget,
    "managed_gpu_bytes": diagnostics.managedGpuBytes,
    "managed_gpu_peak_bytes": diagnostics.managedGpuPeakBytes,
    "managed_gpu_byte_budget": diagnostics.managedGpuByteBudget,
    "streaming_buffer_bytes": diagnostics.streamingBufferBytes,
    "target_texture_bytes": diagnostics.targetTextureBytes,
    "readback_buffer_bytes": diagnostics.readbackBufferBytes,
    "single_stream_syncs": singleDiagnostics.streamingRingSyncs,
    "ring_stream_syncs": ringDiagnostics.streamingRingSyncs,
    "ring_stream_bytes": ringDiagnostics.streamingBufferBytes,
    "scene_cache_hits": automaticDiagnostics.sceneCacheHits,
    "scene_cache_misses": automaticDiagnostics.sceneCacheMisses,
    "scene_cache_evictions": automaticDiagnostics.sceneCacheEvictions,
    "scene_cache_bytes": automaticDiagnostics.sceneCacheBytes,
    "scene_cache_peak_bytes": automaticDiagnostics.sceneCachePeakBytes,
    "scene_cache_byte_budget": automaticDiagnostics.sceneCacheByteBudget,
    "guard": consumed
  }
  echo $report
  if paramCount() >= 3:
    writeFile(paramStr(3), pretty(report) & "\n")
  if paramCount() >= 4:
    checkBaseline(report, paramStr(4))

when isMainModule:
  main()
