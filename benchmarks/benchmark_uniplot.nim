# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, math, monotimes, os, stats, strutils, times]
import UniGlyph
import UniPlot

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
  result.labels(title = "Rosetta benchmark", x = "x", y = "y")

when isMainModule:
  let iterations = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
  let pointCount = if paramCount() >= 2: parseInt(paramStr(2)) else: 1000
  let fontPath = if paramCount() >= 3: paramStr(3) else: "tests/DejaVuSans.ttf"
  let font = loadTtf(fontPath)
  let size = Size(width: 800, height: 500)
  let reference = sampleSpec(pointCount).compileScene(size)

  var compileTimes, svgTimes, pngTimes: RunningStat
  var consumed = 0
  for iteration in 0 ..< iterations + 3:
    var started = getMonoTime()
    let scene = sampleSpec(pointCount).compileScene(size)
    let compileMs = elapsedMs(started)

    started = getMonoTime()
    let svg = reference.toSvg(font)
    let svgMs = elapsedMs(started)

    started = getMonoTime()
    let png = reference.encodePng(font)
    let pngMs = elapsedMs(started)
    consumed = consumed xor svg.len xor png.len xor scene.nodes.len

    if iteration >= 3:
      compileTimes.push compileMs
      svgTimes.push svgMs
      pngTimes.push pngMs

  echo $(%*{
    "provider": "UniPlot",
    "version": UniPlotVersion,
    "iterations": iterations,
    "points": pointCount,
    "width": size.width,
    "height": size.height,
    "warmup_iterations": 3,
    "stages": {
      "construct_compile": summary(compileTimes),
      "svg_from_compiled_scene": summary(svgTimes),
      "png_from_compiled_scene": summary(pngTimes)
    },
    "guard": consumed
  })
