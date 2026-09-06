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

proc secondaryAxisSpec(count: int): PlotSpec =
  result = sampleSpec(count)
  result.secondaryY(scale = 1.8, offset = 32.0, label = "fahrenheit")

proc retainedAnnotationSpec(count: int): PlotSpec =
  result = sampleSpec(count)
  let domainMaximum = max(1.0, float64(count - 1) / 25.0)
  result.annotateText(domainMaximum * 0.75, 1.0, "sample")
  result.annotateArrow(domainMaximum * 0.6, 0.5,
    domainMaximum * 0.75, 1.0)

proc groupedBoxPlotSpec(count: int): PlotSpec =
  var
    groups = newSeqOfCap[string](count)
    values = newSeqOfCap[float64](count)
  for index in 0 ..< count:
    groups.add "group-" & $(index mod 8)
    let base = sin(float64(index) * 0.017) + float64(index mod 8) * 0.2
    values.add(if index > 0 and index mod 10_000 == 0: base + 8.0 else: base)
  result = boxPlot(groups, values)

proc heatmapInputs(count: int): tuple[xs, ys: seq[string];
    values: seq[float64]] =
  result.xs = newSeqOfCap[string](count)
  result.ys = newSeqOfCap[string](count)
  result.values = newSeqOfCap[float64](count)
  for index in 0 ..< count:
    result.xs.add "column-" & $(index mod 32)
    result.ys.add "row-" & $(index mod 24)
    let value = sin(float64(index) * 0.013) + float64(index mod 11) * 0.1
    result.values.add(if index > 0 and index mod 10_000 == 0: NaN else: value)

proc categoricalHeatmapSpec(count: int): PlotSpec =
  let inputs = heatmapInputs(count)
  heatmapPlot(inputs.xs, inputs.ys, inputs.values)

proc numericHeatmapSpec(count: int): PlotSpec =
  let
    rowCount = min(100, max(1, count))
    columnCount = max(1, (count + rowCount - 1) div rowCount)
  var
    xBreaks = newSeqOfCap[float64](columnCount + 1)
    yBreaks = newSeqOfCap[float64](rowCount + 1)
    values = newSeqOfCap[float64](rowCount * columnCount)
  for index in 0 .. columnCount: xBreaks.add float64(index)
  for index in 0 .. rowCount: yBreaks.add float64(index)
  for index in 0 ..< rowCount * columnCount:
    values.add sin(float64(index) * 0.013) + float64(index mod 11) * 0.1
  numericHeatmapPlot(xBreaks, yBreaks, values)

proc groupedInputs(count: int): tuple[groups: seq[string];
    values: seq[float64]] =
  result.groups = newSeqOfCap[string](count)
  result.values = newSeqOfCap[float64](count)
  for index in 0 ..< count:
    result.groups.add "group-" & $(index mod 32)
    let value = sin(float64(index) * 0.013) + float64(index mod 17) * 0.1
    result.values.add(if index > 0 and index mod 10_000 == 0: NaN else: value)

proc groupedAggregateSpec(count: int): PlotSpec =
  let inputs = groupedInputs(count)
  groupedAggregatePlot(inputs.groups, inputs.values)

proc histogramBreakInputs(count: int): tuple[values, breaks: seq[float64]] =
  result.values = newSeqOfCap[float64](count)
  for index in 0 ..< count:
    result.values.add float64(index mod 1_000) / 10.0
  result.breaks = newSeqOfCap[float64](65)
  for index in 0 .. 64:
    result.breaks.add float64(index) * 100.0 / 64.0

proc explicitHistogramSpec(count: int): PlotSpec =
  let inputs = histogramBreakInputs(count)
  histogramBreaksPlot(inputs.values, inputs.breaks)

proc numericHistogramDensitySpec(count: int): PlotSpec =
  let inputs = histogramBreakInputs(count)
  histogramPlot(inputs.values, inputs.breaks, density = true)

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
  # Checked before anything is allocated: zero iterations leaves the summary
  # with no samples to describe, and a negative warmup count silently removes
  # measurements while the report still states the iterations asked for.
  if iterations <= 0: quit("iterations must be positive", 2)
  if pointCount <= 0: quit("point count must be positive", 2)
  if warmups < 0: quit("warmups cannot be negative", 2)
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
  let referenceY = referenceSpec.data.numeric("y")
  let referenceJson = referenceSpec.toJson
  let heatmapReference = heatmapInputs(pointCount)
  let groupedReference = groupedInputs(pointCount)
  let histogramBreakReference = histogramBreakInputs(pointCount)

  var scaleTimes, rowFilterTimes, descriptiveSummaryTimes, compileTimes,
      styledCompileTimes,
      continuousColorCompileTimes, referenceCompileTimes, svgTimes,
      uncertaintyCompileTimes, themedCompileTimes, secondaryCompileTimes,
      retainedAnnotationCompileTimes, groupedBoxPlotCompileTimes,
      aggregate2DTimes, categoricalHeatmapCompileTimes, aggregateGroupTimes,
      groupedAggregateCompileTimes, numericHeatmapCompileTimes,
      explicitHistogramTimes, explicitHistogramCompileTimes,
      numericHistogramDensityCompileTimes,
      jsonEncodeTimes,
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

    started = getMonoTime()
    let descriptive = summarize(referenceY)
    let descriptiveSummaryMs = elapsedMs(started)

    started = getMonoTime()
    let aggregated = aggregate2D(heatmapReference.xs, heatmapReference.ys,
      heatmapReference.values)
    let aggregate2DMs = elapsedMs(started)

    started = getMonoTime()
    let groupAggregates = aggregateGroups(groupedReference.groups,
      groupedReference.values)
    let aggregateGroupMs = elapsedMs(started)

    started = getMonoTime()
    let explicitBins = histogramBreaks(histogramBreakReference.values,
      histogramBreakReference.breaks)
    let explicitHistogramMs = elapsedMs(started)

    var sceneResult, secondaryResult, retainedAnnotationResult:
      tuple[ms: float64; nodes: int]
    if (iteration and 1) == 0:
      sceneResult = measureScene(sampleSpec(pointCount).compileScene(size))
      secondaryResult = measureScene(
        secondaryAxisSpec(pointCount).compileScene(size))
      retainedAnnotationResult = measureScene(
        retainedAnnotationSpec(pointCount).compileScene(size))
    else:
      retainedAnnotationResult = measureScene(
        retainedAnnotationSpec(pointCount).compileScene(size))
      secondaryResult = measureScene(
        secondaryAxisSpec(pointCount).compileScene(size))
      sceneResult = measureScene(sampleSpec(pointCount).compileScene(size))
    let styledResult = measureScene(styledSpec(pointCount).compileScene(size))
    let continuousColorResult = measureScene(
      continuousColorSpec(pointCount).compileScene(size))
    let referenceResult = measureScene(
      annotatedSpec(pointCount).compileScene(size))
    let uncertaintyResult = measureScene(
      uncertaintySpec(pointCount).compileScene(size))
    let themedResult = measureScene(themedSpec(pointCount).compileScene(size))
    let groupedBoxPlotResult = measureScene(
      groupedBoxPlotSpec(pointCount).compileScene(size))
    let categoricalHeatmapResult = measureScene(
      categoricalHeatmapSpec(pointCount).compileScene(size))
    let numericHeatmapResult = measureScene(
      numericHeatmapSpec(pointCount).compileScene(size))
    let groupedAggregateResult = measureScene(
      groupedAggregateSpec(pointCount).compileScene(size))
    let explicitHistogramResult = measureScene(
      explicitHistogramSpec(pointCount).compileScene(size))
    let numericHistogramDensityResult = measureScene(
      numericHistogramDensitySpec(pointCount).compileScene(size))
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
      themedResult.nodes + secondaryResult.nodes + gridResult.nodes +
      retainedAnnotationResult.nodes +
      groupedBoxPlotResult.nodes +
      categoricalHeatmapResult.nodes + groupedAggregateResult.nodes +
      numericHeatmapResult.nodes +
      aggregated.len + groupAggregates.len +
      explicitHistogramResult.nodes + explicitBins.len +
      numericHistogramDensityResult.nodes +
      sharedGridResult.nodes + facetResult.nodes + categoricalGridResult.nodes +
      categoricalSharedGridResult.nodes + facetMatrixResult.nodes +
      compactMatrixFacetResult.nodes +
      encodedSpec.len + decodedSpec.data.rowCount + preparedSvgResult.bytes +
      preparedPngResult.bytes + preparedWidth + int(trained.domainMax) +
      descriptive.count + descriptive.outliers.len

    if iteration >= warmups:
      scaleTimes.push scaleMs
      rowFilterTimes.push rowFilterMs
      descriptiveSummaryTimes.push descriptiveSummaryMs
      compileTimes.push sceneResult.ms
      styledCompileTimes.push styledResult.ms
      continuousColorCompileTimes.push continuousColorResult.ms
      referenceCompileTimes.push referenceResult.ms
      uncertaintyCompileTimes.push uncertaintyResult.ms
      themedCompileTimes.push themedResult.ms
      secondaryCompileTimes.push secondaryResult.ms
      retainedAnnotationCompileTimes.push retainedAnnotationResult.ms
      groupedBoxPlotCompileTimes.push groupedBoxPlotResult.ms
      aggregate2DTimes.push aggregate2DMs
      categoricalHeatmapCompileTimes.push categoricalHeatmapResult.ms
      numericHeatmapCompileTimes.push numericHeatmapResult.ms
      aggregateGroupTimes.push aggregateGroupMs
      groupedAggregateCompileTimes.push groupedAggregateResult.ms
      explicitHistogramTimes.push explicitHistogramMs
      explicitHistogramCompileTimes.push explicitHistogramResult.ms
      numericHistogramDensityCompileTimes.push numericHistogramDensityResult.ms
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
      "descriptive_summary": summary(descriptiveSummaryTimes),
      "construct_compile": summary(compileTimes),
      "styled_construct_compile": summary(styledCompileTimes),
      "continuous_color_construct_compile": summary(
        continuousColorCompileTimes),
      "reference_construct_compile": summary(referenceCompileTimes),
      "uncertainty_construct_compile": summary(uncertaintyCompileTimes),
      "themed_construct_compile": summary(themedCompileTimes),
      "secondary_axis_construct_compile": summary(secondaryCompileTimes),
      "retained_annotation_construct_compile": summary(
        retainedAnnotationCompileTimes),
      "grouped_box_plot_construct_compile": summary(
        groupedBoxPlotCompileTimes),
      "aggregate_2d": summary(aggregate2DTimes),
      "categorical_heatmap_construct_compile": summary(
        categoricalHeatmapCompileTimes),
      "numeric_heatmap_construct_compile": summary(numericHeatmapCompileTimes),
      "aggregate_groups": summary(aggregateGroupTimes),
      "grouped_aggregate_construct_compile": summary(
        groupedAggregateCompileTimes),
      "explicit_histogram_breaks": summary(explicitHistogramTimes),
      "explicit_histogram_construct_compile": summary(
        explicitHistogramCompileTimes),
      "numeric_histogram_density_construct_compile": summary(
        numericHistogramDensityCompileTimes),
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
