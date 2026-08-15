# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, math, monotimes, os, stats, strutils, times]
import UniGlyph
import UniPlot
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
  for phase in ["preparation", "upload_submit", "submit",
      "publication_frame"]:
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
  let report = %*{
    "provider": "UniPlot-WGPU",
    "wgpu_native": WgpuNativeTargetVersion,
    "adapter": capabilities.adapterName,
    "backend": capabilities.backend,
    "iterations": iterations,
    "warmup_iterations": 3,
    "points": pointCount,
    "canvas": "800x500",
    "residency": "prepared-lru-byte-budget-chunked-2-v1",
    "semantics": {
      "preparation": "shape UniGlyph text and tessellate UniVector paths",
      "upload_submit": "cycle three identities through two slots and enqueue",
      "submit": "alternate two resident identities without upload/readback",
      "publication_frame": "submit resident geometry and read back RGBA8",
      "prepared_cache_bytes": "allocated prepared vertex/index capacities only",
      "upload_writes": "queue writes split at the configured byte bound"
    },
    "preparation": summary(preparationTimes),
    "upload_submit": summary(uploadSubmitTimes),
    "submit": summary(submitTimes),
    "publication_frame": summary(frameTimes),
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
    "guard": consumed
  }
  echo $report
  if paramCount() >= 3:
    writeFile(paramStr(3), pretty(report) & "\n")
  if paramCount() >= 4:
    checkBaseline(report, paramStr(4))

when isMainModule:
  main()
