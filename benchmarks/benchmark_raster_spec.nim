# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, monotimes, os, stats, strutils, times]
import UniGlyph
import UniImage/core as uimg
from UniMath import PI, cos, sin
import UniPlot
import UniStatistics as statistics

const Warmups = 3

proc elapsedMs(started: MonoTime): float64 =
  float64((getMonoTime() - started).inNanoseconds) / 1_000_000.0

proc main() =
  let params = commandLineParams()
  if params.len > 1: quit("usage: benchmark_raster_spec [iterations]", 2)
  let iterations = if params.len == 1: parseInt(params[0]) else: 10
  if iterations < 1: quit("iterations must be positive", 2)
  var image = uimg.newImage[uint8](512, 512, uimg.csRgba)
  for pixel in 0 ..< image.width * image.height:
    image.data[pixel * 4] = uint8(pixel and 255)
    image.data[pixel * 4 + 1] = uint8((pixel shr 9) and 255)
    image.data[pixel * 4 + 2] = 180
    image.data[pixel * 4 + 3] = uint8(96 + (pixel and 127))
  let font = loadTtf("tests/DejaVuSans.ttf")
  proc makeSpec(): PlotSpec =
    result = plot(initDataFrame())
    result.raster(image, 0.0, 1.0, 0.0, 1.0, RasterBilinear)
  var resources: array[4, uimg.Image[uint8]]
  for resource in 0 ..< resources.len:
    resources[resource] = uimg.newImage[uint8](16, 16, uimg.csRgba)
    for pixel in 0 ..< 16 * 16:
      resources[resource].data[pixel * 4] = uint8(35 + resource * 50)
      resources[resource].data[pixel * 4 + 1] = uint8(pixel and 255)
      resources[resource].data[pixel * 4 + 2] = uint8(220 - resource * 35)
      resources[resource].data[pixel * 4 + 3] = 220
  proc makeImageMarkSpec(): PlotSpec =
    var frame = initDataFrame()
    var left, right, bottom, top: seq[float64]
    var names: seq[string]
    for row in 0 ..< 64:
      let
        x = float64(row mod 8)
        y = float64(row div 8)
      left.add x
      right.add x + 0.8
      bottom.add y
      top.add y + 0.8
      names.add "resource-" & $(row mod resources.len)
    frame.addColumn("left", left)
    frame.addColumn("right", right)
    frame.addColumn("bottom", bottom)
    frame.addColumn("top", top)
    frame.addColumn("resource", names)
    result = plot(frame)
    for index, resource in resources:
      result.addImageResource("resource-" & $index, resource)
    result.geomImage(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top", image = "resource"), RasterBilinear)
  var temporalX, temporalY: seq[float64]
  for point in 0 ..< 1_000:
    temporalX.add 1_704_067_200.0 + float64(point * 60)
    temporalY.add float64((point * 37) mod 7_200)
  proc makeTemporalSpec(): PlotSpec =
    result = linePlot(temporalX, temporalY, color = "#2457c5")
    result.scaleXUtc()
    result.scaleYDuration()
  var histogramValues = newSeq[float64](100_000)
  for index in 0 ..< histogramValues.len:
    let centered = float64((index * 7919) mod 100_003) / 10_000.0 - 5.0
    histogramValues[index] = centered + 0.35 * sin(float64(index) * 0.013)
  proc makeAutomaticHistogram(): PlotSpec =
    histogramPlot(histogramValues, hrFreedmanDiaconis, density = true,
      color = "#267a5e")
  var smoothX = newSeq[float64](10_000)
  var smoothY = newSeq[float64](10_000)
  for index in 0 ..< smoothX.len:
    smoothX[index] = float64(index) * 0.01
    smoothY[index] = 1.5 + 0.42 * smoothX[index] +
      0.8 * sin(float64(index) * 0.071)
  proc makeSmoothSpec(): PlotSpec =
    linearSmoothPlot(smoothX, smoothY, pointCount = 200,
      confidenceLevel = 0.95)
  var densityValues = newSeq[float64](5_000)
  for index in 0 ..< densityValues.len:
    densityValues[index] = 0.7 * sin(float64(index) * 0.031) +
      float64((index * 37) mod 101) / 40.0 - 1.25
  proc makeDensitySpec(): PlotSpec =
    densityPlot(densityValues, pointCount = 256)
  var
    contourX = newSeq[float64](128)
    contourY = newSeq[float64](128)
    contourValues = newSeq[float64](128 * 128)
  for index in 0 ..< 128:
    contourX[index] = float64(index) / 12.7 - 5.0
    contourY[index] = float64(index) / 12.7 - 5.0
  for row in 0 ..< 128:
    for column in 0 ..< 128:
      contourValues[row * 128 + column] =
        sin(contourX[column]) * cos(contourY[row])
  let contourLevels = [-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8]
  proc makeContourSpec(): PlotSpec =
    contourPlot(contourX, contourY, contourValues, contourLevels)
  var denseValues = newSeq[float64](256 * 256)
  for row in 0 ..< 256:
    for column in 0 ..< 256:
      let
        x = float64(column) / 25.5 - 5.0
        y = float64(row) / 25.5 - 5.0
      denseValues[row * 256 + column] = sin(x) * cos(y)
  proc makeDenseSpec(): PlotSpec =
    rasterHeatmapPlot(256, 256, denseValues, -5.0, 5.0, -5.0, 5.0)
  proc makePowerSpec(): PlotSpec =
    result = linePlot(temporalY, temporalY)
    result.scaleXPower(0.5)
    result.scaleYPower(2.0)
  var polarAngle = newSeq[float64](1_000)
  var polarRadius = newSeq[float64](1_000)
  for index in 0 ..< polarAngle.len:
    polarAngle[index] = 2.0 * PI * float64(index) /
      float64(polarAngle.len - 1)
    polarRadius[index] = 2.0 + 0.75 * sin(6.0 * polarAngle[index])
  proc makePolarSpec(): PlotSpec =
    result = linePlot(polarAngle, polarRadius)
    result.coordPolar()
  for discardIndex in 0 ..< Warmups:
    let warmScene = makeSpec().compileScene(Size(width: 800, height: 600))
    discard warmScene.renderImage(font)
    let warmMarks = makeImageMarkSpec().compileScene(
      Size(width: 800, height: 600))
    discard warmMarks.renderImage(font)
    let warmTemporal = makeTemporalSpec().compileScene(
      Size(width: 800, height: 600))
    discard warmTemporal.renderImage(font)
    discard automaticHistogramBreaks(histogramValues,
      hrFreedmanDiaconis)
    let warmHistogram = makeAutomaticHistogram().compileScene(
      Size(width: 800, height: 600))
    discard warmHistogram.renderImage(font)
    discard statistics.linearRegressionDiagnostics(smoothX, smoothY)
    let warmSmooth = makeSmoothSpec().compileScene(Size(width: 800, height: 600))
    discard warmSmooth.renderImage(font)
    discard statistics.kernelDensity(densityValues, 256)
    let warmDensity = makeDensitySpec().compileScene(Size(width: 800, height: 600))
    discard warmDensity.renderImage(font)
    discard contourSegments(contourX, contourY, contourValues, contourLevels)
    let warmContour = makeContourSpec().compileScene(Size(width: 800, height: 600))
    discard warmContour.renderImage(font)
    let warmDense = makeDenseSpec().compileScene(Size(width: 800, height: 600))
    discard warmDense.renderImage(font)
    let warmPower = makePowerSpec().compileScene(Size(width: 800, height: 600))
    discard warmPower.renderImage(font)
    let warmPolar = makePolarSpec().compileScene(Size(width: 800, height: 600))
    discard warmPolar.renderImage(font)
  var snapshotStats, compileStats, publicationStats: RunningStat
  var markConstructionStats, markCompileStats, markPublicationStats:
    RunningStat
  var temporalConstructionStats, temporalCompileStats,
    temporalPublicationStats: RunningStat
  var histogramSelectionStats, histogramConstructionStats,
    histogramCompileStats, histogramPublicationStats: RunningStat
  var smoothFitStats, smoothConstructionStats, smoothCompileStats,
    smoothPublicationStats: RunningStat
  var densityEstimateStats, densityConstructionStats, densityCompileStats,
    densityPublicationStats: RunningStat
  var contourExtractionStats, contourConstructionStats, contourCompileStats,
    contourPublicationStats: RunningStat
  var denseConstructionStats, denseCompileStats, densePublicationStats:
    RunningStat
  var powerConstructionStats, powerCompileStats, powerPublicationStats:
    RunningStat
  var polarConstructionStats, polarCompileStats, polarPublicationStats:
    RunningStat
  var guard = 0
  for iteration in 0 ..< iterations:
    var started = getMonoTime()
    let spec = makeSpec()
    snapshotStats.push elapsedMs(started)
    started = getMonoTime()
    let scene = spec.compileScene(Size(width: 800, height: 600))
    compileStats.push elapsedMs(started)
    started = getMonoTime()
    let pixels = scene.renderImage(font)
    publicationStats.push elapsedMs(started)
    guard = guard xor int(pixels.data[(iteration * 997) mod pixels.data.len])
    started = getMonoTime()
    let markSpec = makeImageMarkSpec()
    markConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let markScene = markSpec.compileScene(Size(width: 800, height: 600))
    markCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let markPixels = markScene.renderImage(font)
    markPublicationStats.push elapsedMs(started)
    guard = guard xor int(markPixels.data[
      (iteration * 1597) mod markPixels.data.len])
    started = getMonoTime()
    let temporalSpec = makeTemporalSpec()
    temporalConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let temporalScene = temporalSpec.compileScene(Size(width: 800, height: 600))
    temporalCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let temporalPixels = temporalScene.renderImage(font)
    temporalPublicationStats.push elapsedMs(started)
    guard = guard xor int(temporalPixels.data[
      (iteration * 1999) mod temporalPixels.data.len])
    started = getMonoTime()
    let selectedBreaks = automaticHistogramBreaks(histogramValues,
      hrFreedmanDiaconis)
    histogramSelectionStats.push elapsedMs(started)
    guard = guard xor selectedBreaks.len
    started = getMonoTime()
    let histogramSpec = makeAutomaticHistogram()
    histogramConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let histogramScene = histogramSpec.compileScene(
      Size(width: 800, height: 600))
    histogramCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let histogramPixels = histogramScene.renderImage(font)
    histogramPublicationStats.push elapsedMs(started)
    guard = guard xor int(histogramPixels.data[
      (iteration * 2371) mod histogramPixels.data.len])
    started = getMonoTime()
    let fitted = statistics.linearRegressionDiagnostics(smoothX, smoothY)
    smoothFitStats.push elapsedMs(started)
    guard = guard xor int(fitted.model.slope * 1_000_000.0)
    started = getMonoTime()
    let smoothSpec = makeSmoothSpec()
    smoothConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let smoothScene = smoothSpec.compileScene(Size(width: 800, height: 600))
    smoothCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let smoothPixels = smoothScene.renderImage(font)
    smoothPublicationStats.push elapsedMs(started)
    guard = guard xor int(smoothPixels.data[
      (iteration * 3253) mod smoothPixels.data.len])
    started = getMonoTime()
    let densityEstimate = statistics.kernelDensity(densityValues, 256)
    densityEstimateStats.push elapsedMs(started)
    guard = guard xor int(densityEstimate.density[128] * 1_000_000.0)
    started = getMonoTime()
    let densitySpec = makeDensitySpec()
    densityConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let densityScene = densitySpec.compileScene(Size(width: 800, height: 600))
    densityCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let densityPixels = densityScene.renderImage(font)
    densityPublicationStats.push elapsedMs(started)
    guard = guard xor int(densityPixels.data[
      (iteration * 4001) mod densityPixels.data.len])
    started = getMonoTime()
    let contourResult = contourSegments(contourX, contourY, contourValues,
      contourLevels)
    contourExtractionStats.push elapsedMs(started)
    guard = guard xor contourResult.len
    started = getMonoTime()
    let contourSpec = makeContourSpec()
    contourConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let contourScene = contourSpec.compileScene(Size(width: 800, height: 600))
    contourCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let contourPixels = contourScene.renderImage(font)
    contourPublicationStats.push elapsedMs(started)
    guard = guard xor int(contourPixels.data[
      (iteration * 4211) mod contourPixels.data.len])
    started = getMonoTime()
    let denseSpec = makeDenseSpec()
    denseConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let denseScene = denseSpec.compileScene(Size(width: 800, height: 600))
    denseCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let densePixels = denseScene.renderImage(font)
    densePublicationStats.push elapsedMs(started)
    guard = guard xor int(densePixels.data[
      (iteration * 4513) mod densePixels.data.len])
    started = getMonoTime()
    let powerSpec = makePowerSpec()
    powerConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let powerScene = powerSpec.compileScene(Size(width: 800, height: 600))
    powerCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let powerPixels = powerScene.renderImage(font)
    powerPublicationStats.push elapsedMs(started)
    guard = guard xor int(powerPixels.data[
      (iteration * 4789) mod powerPixels.data.len])
    started = getMonoTime()
    let polarSpec = makePolarSpec()
    polarConstructionStats.push elapsedMs(started)
    started = getMonoTime()
    let polarScene = polarSpec.compileScene(Size(width: 800, height: 600))
    polarCompileStats.push elapsedMs(started)
    started = getMonoTime()
    let polarPixels = polarScene.renderImage(font)
    polarPublicationStats.push elapsedMs(started)
    guard = guard xor int(polarPixels.data[
      (iteration * 4999) mod polarPixels.data.len])
  echo $(%*{"provider": "UniPlot-raster-spec", "iterations": iterations,
    "warmup_iterations": Warmups, "source": "512x512 RGBA8",
    "canvas": "800x600", "filter": "bilinear",
    "image_mark_count": 64, "image_resource_count": resources.len,
    "temporal_point_count": temporalX.len,
    "histogram_point_count": histogramValues.len,
    "histogram_rule": "Freedman-Diaconis",
    "smoothing_point_count": smoothX.len,
    "smoothing_grid_count": 200,
    "density_point_count": densityValues.len,
    "density_grid_count": 256,
    "contour_grid": "128x128", "contour_level_count": contourLevels.len,
    "dense_grid": "256x256", "power_point_count": temporalY.len,
    "polar_point_count": polarAngle.len,
    "semantics": "separate PlotSpec construction, statistical selection or fitting, retained-scene compilation and complete CPU publication",
    "construction_snapshot_mean_ms": snapshotStats.mean,
    "compile_mean_ms": compileStats.mean,
    "publication_mean_ms": publicationStats.mean,
    "image_mark_construction_mean_ms": markConstructionStats.mean,
    "image_mark_compile_mean_ms": markCompileStats.mean,
    "image_mark_publication_mean_ms": markPublicationStats.mean,
    "temporal_construction_mean_ms": temporalConstructionStats.mean,
    "temporal_compile_mean_ms": temporalCompileStats.mean,
    "temporal_publication_mean_ms": temporalPublicationStats.mean,
    "histogram_selection_mean_ms": histogramSelectionStats.mean,
    "histogram_construction_mean_ms": histogramConstructionStats.mean,
    "histogram_compile_mean_ms": histogramCompileStats.mean,
    "histogram_publication_mean_ms": histogramPublicationStats.mean,
    "smoothing_fit_mean_ms": smoothFitStats.mean,
    "smoothing_construction_mean_ms": smoothConstructionStats.mean,
    "smoothing_compile_mean_ms": smoothCompileStats.mean,
    "smoothing_publication_mean_ms": smoothPublicationStats.mean,
    "density_estimate_mean_ms": densityEstimateStats.mean,
    "density_construction_mean_ms": densityConstructionStats.mean,
    "density_compile_mean_ms": densityCompileStats.mean,
    "density_publication_mean_ms": densityPublicationStats.mean,
    "contour_extraction_mean_ms": contourExtractionStats.mean,
    "contour_construction_mean_ms": contourConstructionStats.mean,
    "contour_compile_mean_ms": contourCompileStats.mean,
    "contour_publication_mean_ms": contourPublicationStats.mean,
    "dense_construction_mean_ms": denseConstructionStats.mean,
    "dense_compile_mean_ms": denseCompileStats.mean,
    "dense_publication_mean_ms": densePublicationStats.mean,
    "power_construction_mean_ms": powerConstructionStats.mean,
    "power_compile_mean_ms": powerCompileStats.mean,
    "power_publication_mean_ms": powerPublicationStats.mean,
    "polar_construction_mean_ms": polarConstructionStats.mean,
    "polar_compile_mean_ms": polarCompileStats.mean,
    "polar_publication_mean_ms": polarPublicationStats.mean,
    "guard": guard})

main()
