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

proc measureSvg(scene: Scene; font: Font): tuple[ms: float64; bytes: int] =
  let started = getMonoTime()
  let output = scene.toSvg(font)
  (elapsedMs(started), output.len)

proc measureSvg(scene: PreparedScene): tuple[ms: float64; bytes: int] =
  let started = getMonoTime()
  let output = scene.toSvg()
  (elapsedMs(started), output.len)

proc measurePng(scene: Scene; font: Font): tuple[ms: float64; bytes: int] =
  let started = getMonoTime()
  let output = scene.encodePng(font)
  (elapsedMs(started), output.len)

proc measurePng(scene: PreparedScene): tuple[ms: float64; bytes: int] =
  let started = getMonoTime()
  let output = scene.encodePng()
  (elapsedMs(started), output.len)

template measureScene(body: untyped): tuple[ms: float64; nodes: int] =
  block:
    let measuredStarted = getMonoTime()
    let measuredScene = body
    (elapsedMs(measuredStarted), measuredScene.nodes.len)

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

proc facetedSpec(count: int): PlotSpec =
  result = sampleSpec(count)
  var groups = newSeqOfCap[string](count)
  for index in 0 ..< count: groups.add "panel-" & $(index mod 4)
  result.data.addColumn("facet", groups)

proc matrixFacetedSpec(count: int): PlotSpec =
  result = sampleSpec(count)
  var rows, columns, pairs = newSeqOfCap[string](count)
  for index in 0 ..< count:
    case index mod 3
    of 0:
      rows.add "north"; columns.add "left"; pairs.add "north-left"
    of 1:
      rows.add "north"; columns.add "right"; pairs.add "north-right"
    else:
      rows.add "south"; columns.add "right"; pairs.add "south-right"
  result.data.addColumn("facet_row", rows)
  result.data.addColumn("facet_column", columns)
  result.data.addColumn("facet_pair", pairs)

proc categoricalSpec(offset, count: int): PlotSpec =
  var
    categories = newSeqOfCap[string](count)
    values = newSeqOfCap[float64](count)
  for index in 0 ..< count:
    categories.add "category-" & $(offset + index)
    values.add float64((index mod 17) + 1)
  barPlot(categories, values)

when isMainModule:
  let iterations = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
  let pointCount = if paramCount() >= 2: parseInt(paramStr(2)) else: 1000
  let fontPath = if paramCount() >= 3: paramStr(3) else: "tests/DejaVuSans.ttf"
  let warmups = if paramCount() >= 4: parseInt(paramStr(4)) else: 3
  let font = loadTtf(fontPath)
  let size = Size(width: 800, height: 500)
  let referenceSpec = sampleSpec(pointCount)
  let reference = referenceSpec.compileScene(size)
  let referencePrepared = reference.prepareScene(font)
  let panelPointCount = max(1, pointCount div 4)
  let gridSpecs = [sampleSpec(panelPointCount), sampleSpec(panelPointCount),
    sampleSpec(panelPointCount), sampleSpec(panelPointCount)]
  let facetSpec = facetedSpec(pointCount)
  let matrixFacetSpec = matrixFacetedSpec(pointCount)
  let categoryCount = min(100, max(1, pointCount div 4))
  let categoricalGridSpecs = [categoricalSpec(0, categoryCount),
    categoricalSpec(categoryCount div 2, categoryCount)]
  let referenceX = referenceSpec.data.numeric("x")
  let referenceJson = referenceSpec.toJson

  var scaleTimes, rowFilterTimes, compileTimes, styledCompileTimes,
      continuousColorCompileTimes, referenceCompileTimes, svgTimes,
      uncertaintyCompileTimes, themedCompileTimes, jsonEncodeTimes,
      jsonDecodeTimes, gridCompileTimes, sharedGridCompileTimes,
      categoricalGridCompileTimes, categoricalSharedGridCompileTimes,
      facetCompileTimes, compactMatrixFacetCompileTimes,
        facetMatrixCompileTimes,
      prepareSceneTimes, preparedSvgTimes, preparedPngTimes,
      pngTimes: RunningStat
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

    let sceneResult = measureScene(sampleSpec(pointCount).compileScene(size))
    let styledResult = measureScene(styledSpec(pointCount).compileScene(size))
    let continuousColorResult = measureScene(
      continuousColorSpec(pointCount).compileScene(size))
    let referenceResult = measureScene(
      annotatedSpec(pointCount).compileScene(size))
    let uncertaintyResult = measureScene(
      uncertaintySpec(pointCount).compileScene(size))
    let themedResult = measureScene(themedSpec(pointCount).compileScene(size))
    let gridResult = measureScene(compileGrid(gridSpecs, 2, size, gap = 12))
    let sharedGridResult = measureScene(compileGrid(gridSpecs, 2, size,
      gap = 12, sharedX = true, sharedY = true))
    let facetResult = measureScene(compileFacetGrid(facetSpec, "facet", 2,
      size, gap = 12, sharedX = true, sharedY = true))
    let compactMatrixFacetResult = measureScene(compileFacetGrid(
      matrixFacetSpec, "facet_pair", 2, size, gap = 12, sharedX = true,
      sharedY = true))
    let facetMatrixResult = measureScene(compileFacetMatrix(matrixFacetSpec,
      "facet_row", "facet_column", size, gap = 12, sharedX = true,
      sharedY = true))
    let categoricalGridResult = measureScene(compileGrid(
      categoricalGridSpecs, 2, size, gap = 12))
    let categoricalSharedGridResult = measureScene(compileGrid(
      categoricalGridSpecs, 2, size, gap = 12, sharedX = true))

    started = getMonoTime()
    let encodedSpec = referenceSpec.toJson
    let jsonEncodeMs = elapsedMs(started)

    started = getMonoTime()
    let decodedSpec = fromJson(referenceJson)
    let jsonDecodeMs = elapsedMs(started)

    started = getMonoTime()
    let preparedScene = reference.prepareScene(font)
    let prepareSceneMs = elapsedMs(started)
    let preparedWidth = preparedScene.size.width

    var svgResult, preparedSvgResult, pngResult, preparedPngResult:
      tuple[ms: float64; bytes: int]
    if (iteration and 1) == 0:
      svgResult = reference.measureSvg(font)
      preparedSvgResult = referencePrepared.measureSvg()
      pngResult = reference.measurePng(font)
      preparedPngResult = referencePrepared.measurePng()
    else:
      preparedSvgResult = referencePrepared.measureSvg()
      svgResult = reference.measureSvg(font)
      preparedPngResult = referencePrepared.measurePng()
      pngResult = reference.measurePng(font)
    consumed += svgResult.bytes + pngResult.bytes + sceneResult.nodes +
      styledResult.nodes + continuousColorResult.nodes +
      referenceResult.nodes + finiteCount + uncertaintyResult.nodes +
      themedResult.nodes + gridResult.nodes +
      sharedGridResult.nodes + facetResult.nodes + categoricalGridResult.nodes +
      categoricalSharedGridResult.nodes + facetMatrixResult.nodes +
      compactMatrixFacetResult.nodes +
      encodedSpec.len + decodedSpec.data.rowCount + preparedSvgResult.bytes +
      preparedPngResult.bytes + preparedWidth + int(trained.domainMax)

    if iteration >= warmups:
      scaleTimes.push scaleMs
      rowFilterTimes.push rowFilterMs
      compileTimes.push sceneResult.ms
      styledCompileTimes.push styledResult.ms
      continuousColorCompileTimes.push continuousColorResult.ms
      referenceCompileTimes.push referenceResult.ms
      uncertaintyCompileTimes.push uncertaintyResult.ms
      themedCompileTimes.push themedResult.ms
      gridCompileTimes.push gridResult.ms
      sharedGridCompileTimes.push sharedGridResult.ms
      categoricalGridCompileTimes.push categoricalGridResult.ms
      categoricalSharedGridCompileTimes.push categoricalSharedGridResult.ms
      facetCompileTimes.push facetResult.ms
      compactMatrixFacetCompileTimes.push compactMatrixFacetResult.ms
      facetMatrixCompileTimes.push facetMatrixResult.ms
      jsonEncodeTimes.push jsonEncodeMs
      jsonDecodeTimes.push jsonDecodeMs
      prepareSceneTimes.push prepareSceneMs
      svgTimes.push svgResult.ms
      pngTimes.push pngResult.ms
      preparedSvgTimes.push preparedSvgResult.ms
      preparedPngTimes.push preparedPngResult.ms

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
      "grid_construct_compile": summary(gridCompileTimes),
      "shared_grid_construct_compile": summary(sharedGridCompileTimes),
      "categorical_grid_construct_compile": summary(
          categoricalGridCompileTimes),
      "categorical_shared_grid_construct_compile": summary(
        categoricalSharedGridCompileTimes),
      "facet_construct_compile": summary(facetCompileTimes),
      "facet_compact_matrix_workload_compile": summary(
        compactMatrixFacetCompileTimes),
      "facet_matrix_construct_compile": summary(facetMatrixCompileTimes),
      "json_encode": summary(jsonEncodeTimes),
      "json_decode": summary(jsonDecodeTimes),
      "cpu_prepare_scene": summary(prepareSceneTimes),
      "svg_from_compiled_scene": summary(svgTimes),
      "png_from_compiled_scene": summary(pngTimes),
      "svg_from_prepared_scene": summary(preparedSvgTimes),
      "png_from_prepared_scene": summary(preparedPngTimes)
    },
    "guard": consumed
  })
