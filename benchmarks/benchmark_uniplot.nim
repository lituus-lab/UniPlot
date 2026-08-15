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

proc styledSpec(count: int): PlotSpec =
  var
    x = newSeq[float64](count)
    y = newSeq[float64](count)
    groups = newSeq[string](count)
  for index in 0 ..< count:
    x[index] = float64(index) / 25.0
    y[index] = sin(x[index]) + 0.02 * x[index]
    groups[index] = "g" & $(index mod 4)
  var frame = initDataFrame()
  frame.addColumn("x", x)
  frame.addColumn("y", y)
  frame.addColumn("group", groups)
  result = plot(frame)
  result.geomLine(aes("x", "y"), lineStyle = DotDashLine)
  result.geomPoint(aes("x", "y", shape = "group"), radius = 2)

proc continuousColorSpec(count: int): PlotSpec =
  var
    x = newSeq[float64](count)
    y = newSeq[float64](count)
    intensity = newSeq[float64](count)
  for index in 0 ..< count:
    x[index] = float64(index) / 25.0
    y[index] = sin(x[index]) + 0.02 * x[index]
    intensity[index] = float64(index)
  var frame = initDataFrame()
  frame.addColumn("x", x)
  frame.addColumn("y", y)
  frame.addColumn("intensity", intensity)
  result = plot(frame)
  result.geomPoint(aes("x", "y", color = "intensity"), radius = 2)

proc annotatedSpec(count: int): PlotSpec =
  result = sampleSpec(count)
  let domainMaximum = max(1.0, float64(count - 1) / 25.0)
  result.referenceX(domainMaximum * 0.5, label = "midpoint")
  result.referenceY(0.0, width = 2)
  result.referenceXBand(domainMaximum * 0.2, domainMaximum * 0.3)
  result.referenceYBand(-0.25, 0.25)

proc uncertaintySpec(count: int): PlotSpec =
  var
    x = newSeq[float64](count)
    estimate = newSeq[float64](count)
    lower = newSeq[float64](count)
    upper = newSeq[float64](count)
  for index in 0 ..< count:
    x[index] = float64(index) / 25.0
    estimate[index] = sin(x[index]) + 0.02 * x[index]
    lower[index] = estimate[index] - 0.25
    upper[index] = estimate[index] + 0.25
  var frame = initDataFrame()
  frame.addColumn("x", x)
  frame.addColumn("estimate", estimate)
  frame.addColumn("lower", lower)
  frame.addColumn("upper", upper)
  result = plot(frame)
  let interval = aes("x", "", yMin = "lower", yMax = "upper")
  result.geomRibbon(interval)
  result.geomErrorBar(interval)
  result.geomLine(aes("x", "estimate"))

proc themedSpec(count: int): PlotSpec =
  result = sampleSpec(count)
  result.applyTheme(darkTheme())

when isMainModule:
  let iterations = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
  let pointCount = if paramCount() >= 2: parseInt(paramStr(2)) else: 1000
  let fontPath = if paramCount() >= 3: paramStr(3) else: "tests/DejaVuSans.ttf"
  let warmups = if paramCount() >= 4: parseInt(paramStr(4)) else: 3
  let font = loadTtf(fontPath)
  let size = Size(width: 800, height: 500)
  let referenceSpec = sampleSpec(pointCount)
  let reference = referenceSpec.compileScene(size)
  let referenceX = referenceSpec.data.numeric("x")
  let referenceJson = referenceSpec.toJson

  var scaleTimes, rowFilterTimes, compileTimes, styledCompileTimes,
      continuousColorCompileTimes, referenceCompileTimes, svgTimes,
      uncertaintyCompileTimes, themedCompileTimes, jsonEncodeTimes,
      jsonDecodeTimes, pngTimes: RunningStat
  var consumed = 0
  for iteration in 0 ..< iterations + warmups:
    var started = getMonoTime()
    let trained = trainContinuous(referenceX, 0, 800)
    let scaleMs = elapsedMs(started)

    started = getMonoTime()
    let rowFilter = referenceSpec.data.initRowFilter(["x", "y"])
    var finiteCount = 0
    for row in 0 ..< referenceSpec.data.rowCount:
      if rowFilter.rowIsFinite(row): inc finiteCount
    let rowFilterMs = elapsedMs(started)

    started = getMonoTime()
    let scene = sampleSpec(pointCount).compileScene(size)
    let compileMs = elapsedMs(started)

    started = getMonoTime()
    let styledScene = styledSpec(pointCount).compileScene(size)
    let styledCompileMs = elapsedMs(started)

    started = getMonoTime()
    let continuousColorScene = continuousColorSpec(pointCount).compileScene(
      size)
    let continuousColorCompileMs = elapsedMs(started)

    started = getMonoTime()
    let referenceScene = annotatedSpec(pointCount).compileScene(size)
    let referenceCompileMs = elapsedMs(started)

    started = getMonoTime()
    let uncertaintyScene = uncertaintySpec(pointCount).compileScene(size)
    let uncertaintyCompileMs = elapsedMs(started)

    started = getMonoTime()
    let themedScene = themedSpec(pointCount).compileScene(size)
    let themedCompileMs = elapsedMs(started)

    started = getMonoTime()
    let encodedSpec = referenceSpec.toJson
    let jsonEncodeMs = elapsedMs(started)

    started = getMonoTime()
    let decodedSpec = fromJson(referenceJson)
    let jsonDecodeMs = elapsedMs(started)

    started = getMonoTime()
    let svg = reference.toSvg(font)
    let svgMs = elapsedMs(started)

    started = getMonoTime()
    let png = reference.encodePng(font)
    let pngMs = elapsedMs(started)
    consumed += svg.len + png.len + scene.nodes.len + styledScene.nodes.len +
      continuousColorScene.nodes.len + referenceScene.nodes.len + finiteCount +
      uncertaintyScene.nodes.len + themedScene.nodes.len +
      encodedSpec.len + decodedSpec.data.rowCount + int(trained.domainMax)

    if iteration >= warmups:
      scaleTimes.push scaleMs
      rowFilterTimes.push rowFilterMs
      compileTimes.push compileMs
      styledCompileTimes.push styledCompileMs
      continuousColorCompileTimes.push continuousColorCompileMs
      referenceCompileTimes.push referenceCompileMs
      uncertaintyCompileTimes.push uncertaintyCompileMs
      themedCompileTimes.push themedCompileMs
      jsonEncodeTimes.push jsonEncodeMs
      jsonDecodeTimes.push jsonDecodeMs
      svgTimes.push svgMs
      pngTimes.push pngMs

  echo $(%*{
    "provider": "UniPlot",
    "version": UniPlotVersion,
    "iterations": iterations,
    "points": pointCount,
    "width": size.width,
    "height": size.height,
    "json_bytes": referenceJson.len,
    "warmup_iterations": warmups,
    "stages": {
      "continuous_scale_train": summary(scaleTimes),
      "row_filter_scan": summary(rowFilterTimes),
      "construct_compile": summary(compileTimes),
      "styled_construct_compile": summary(styledCompileTimes),
      "continuous_color_construct_compile": summary(
        continuousColorCompileTimes),
      "reference_construct_compile": summary(referenceCompileTimes),
      "uncertainty_construct_compile": summary(uncertaintyCompileTimes),
      "themed_construct_compile": summary(themedCompileTimes),
      "json_encode": summary(jsonEncodeTimes),
      "json_decode": summary(jsonDecodeTimes),
      "svg_from_compiled_scene": summary(svgTimes),
      "png_from_compiled_scene": summary(pngTimes)
    },
    "guard": consumed
  })
