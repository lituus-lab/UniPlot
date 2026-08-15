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
  var frameTimes: RunningStat
  var consumed = 0'u8
  for iteration in 0 ..< iterations + 3:
    let started = getMonoTime()
    let pixels = backend.renderWgpuScene(scene, font)
    let frameMs = elapsedMs(started)
    consumed = consumed xor pixels[(iteration * 4) mod pixels.len]
    if iteration >= 3: frameTimes.push(frameMs)
  echo $(%*{
    "provider": "UniPlot-WGPU",
    "wgpu_native": WgpuNativeTargetVersion,
    "iterations": iterations,
    "warmup_iterations": 3,
    "points": pointCount,
    "canvas": "800x500",
    "semantics": "compile paths, tessellate, upload, submit and read back RGBA8",
    "frame": summary(frameTimes),
    "guard": consumed
  })

when isMainModule:
  main()
