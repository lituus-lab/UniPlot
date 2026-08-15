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
  for field in ["adapter", "backend", "points", "canvas"]:
    if baseline[field] != report[field]:
      quit("WGPU baseline does not match current " & field, 1)
  for phase in ["preparation", "submit", "publication_frame"]:
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
    backend = openWgpuBackend(libraryPath)
  defer: backend.close()
  let capabilities = wgpuCapabilities(backend)
  var preparationTimes, submitTimes, frameTimes: RunningStat
  var prepared: WgpuPreparedScene
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    prepared = scene.prepareWgpuScene(font)
    let preparationMs = elapsedMs(started)
    if iteration >= 3: preparationTimes.push(preparationMs)
  var consumed = 0'u8
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    backend.submitWgpuPrepared(prepared)
    let submitMs = elapsedMs(started)
    if iteration >= 3: submitTimes.push(submitMs)
  # The first publication frame drains the ordered submissions above.
  discard backend.renderWgpuPrepared(prepared)
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    let pixels = backend.renderWgpuPrepared(prepared)
    let frameMs = elapsedMs(started)
    consumed = consumed xor pixels[(iteration * 4) mod pixels.len]
    if iteration >= 3: frameTimes.push(frameMs)
  let report = %*{
    "provider": "UniPlot-WGPU",
    "wgpu_native": WgpuNativeTargetVersion,
    "adapter": capabilities.adapterName,
    "backend": capabilities.backend,
    "iterations": iterations,
    "warmup_iterations": 3,
    "points": pointCount,
    "canvas": "800x500",
    "semantics": {
      "preparation": "shape UniGlyph text and tessellate UniVector paths",
      "submit": "upload retained geometry and enqueue without readback",
      "publication_frame": "upload retained geometry, submit and read back RGBA8"
    },
    "preparation": summary(preparationTimes),
    "submit": summary(submitTimes),
    "publication_frame": summary(frameTimes),
    "guard": consumed
  }
  echo $report
  if paramCount() >= 3:
    writeFile(paramStr(3), pretty(report) & "\n")
  if paramCount() >= 4:
    checkBaseline(report, paramStr(4))

when isMainModule:
  main()
