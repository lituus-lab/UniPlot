# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, monotimes, os, stats, strutils, times]
import UniColor
import UniGlyph
import UniImage/core as uimg
import UniPlot
import UniPlot/render/wgpu

proc elapsedMs(started: MonoTime): float64 =
  inNanoseconds(getMonoTime() - started).float64 / 1_000_000.0

proc summary(samples: RunningStat): JsonNode =
  %*{"mean_ms": samples.mean, "stdev_ms": samples.standardDeviationS,
    "min_ms": samples.min, "max_ms": samples.max}

proc main() =
  let iterations = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
  if iterations <= 0: quit("iterations must be positive", 1)
  let libraryPath = getEnv("UNIPLOT_WGPU_LIBRARY")
  if libraryPath.len == 0:
    quit("UNIPLOT_WGPU_LIBRARY is not configured", 1)
  var image = uimg.newImage[uint8](512, 512, uimg.csRgba)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let offset = (y * image.width + x) * 4
      image.data[offset] = byte(x and 255)
      image.data[offset + 1] = byte(y and 255)
      image.data[offset + 2] = byte((x xor y) and 255)
      image.data[offset + 3] = 255
  var scene = initScene(Size(width: 800, height: 600),
    parseColor("#ffffff").get)
  scene.addImage(image, 144, 44)
  let
    font = loadTtf("tests/DejaVuSans.ttf")
    prepared = scene.prepareWgpuScene(font)
    backend = openWgpuBackend(libraryPath)
  defer: backend.close()
  var submitTimes, readbackTimes: RunningStat
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    backend.submitWgpuPrepared(prepared)
    let duration = elapsedMs(started)
    if iteration >= 3: submitTimes.push(duration)
  backend.waitWgpuIdle()
  var guard = 0'u8
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    let pixels = backend.renderWgpuPrepared(prepared)
    let duration = elapsedMs(started)
    guard = guard xor pixels[(iteration * 4) mod pixels.len]
    if iteration >= 3: readbackTimes.push(duration)
  let diagnostics = backend.wgpuDiagnostics
  const
    ExpectedTextureBytes = 512'u64 * 512'u64 * 4'u64
    ExpectedPreparedBytes = ExpectedTextureBytes + 256'u64
    ExpectedTargetBytes = 800'u64 * 600'u64 * 8'u64
    ExpectedReadbackCapacity = 4_194_304'u64
    ExpectedManagedBytes = ExpectedPreparedBytes + ExpectedTargetBytes +
      ExpectedReadbackCapacity
  if diagnostics.textureUploads != 1 or
      diagnostics.textureUploadBytes != ExpectedTextureBytes:
    quit("resident texture upload accounting is inconsistent", 1)
  if diagnostics.preparedCacheBytes != ExpectedPreparedBytes or
      diagnostics.managedGpuBytes != ExpectedManagedBytes or
      diagnostics.managedGpuPeakBytes != ExpectedManagedBytes or
      diagnostics.managedGpuPeakBytes > diagnostics.managedGpuByteBudget:
    quit("resident texture budget accounting is inconsistent", 1)
  let capabilities = wgpuCapabilities(backend)
  let report = %*{
    "provider": "UniPlot-WGPU-raster",
    "wgpu_native": WgpuNativeTargetVersion,
    "adapter": capabilities.adapterName,
    "backend": capabilities.backend,
    "iterations": iterations,
    "warmup_iterations": 3,
    "canvas": "800x600",
    "image": "512x512 RGBA8",
    "semantics": {
      "submit": "enqueue one resident RGBA8 texture without readback",
      "publication_frame": "render through an RGBA16F premultiplied target and publish straight RGBA8"
    },
    "submit": summary(submitTimes),
    "publication_frame": summary(readbackTimes),
    "texture_uploads": diagnostics.textureUploads,
    "texture_upload_bytes": diagnostics.textureUploadBytes,
    "prepared_cache_bytes": diagnostics.preparedCacheBytes,
    "managed_gpu_bytes": diagnostics.managedGpuBytes,
    "managed_gpu_peak_bytes": diagnostics.managedGpuPeakBytes,
    "managed_gpu_byte_budget": diagnostics.managedGpuByteBudget,
    "guard": guard
  }
  echo $report
  if paramCount() >= 2:
    writeFile(paramStr(2), pretty(report) & "\n")

when isMainModule:
  main()
