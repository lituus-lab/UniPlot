# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, monotimes, os, stats, strutils, times]
import UniGlyph
import UniImage/core as uimg
import UniPlot

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
  for discardIndex in 0 ..< Warmups:
    let warmScene = makeSpec().compileScene(Size(width: 800, height: 600))
    discard warmScene.renderImage(font)
    let warmMarks = makeImageMarkSpec().compileScene(
      Size(width: 800, height: 600))
    discard warmMarks.renderImage(font)
  var snapshotStats, compileStats, publicationStats: RunningStat
  var markConstructionStats, markCompileStats, markPublicationStats:
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
  echo $(%*{"provider": "UniPlot-raster-spec", "iterations": iterations,
    "warmup_iterations": Warmups, "source": "512x512 RGBA8",
    "canvas": "800x600", "filter": "bilinear",
    "image_mark_count": 64, "image_resource_count": resources.len,
    "semantics": "PlotSpec construction plus snapshot; compile includes alpha-correct resize; publication includes CPU render",
    "construction_snapshot_mean_ms": snapshotStats.mean,
    "compile_mean_ms": compileStats.mean,
    "publication_mean_ms": publicationStats.mean,
    "image_mark_construction_mean_ms": markConstructionStats.mean,
    "image_mark_compile_mean_ms": markCompileStats.mean,
    "image_mark_publication_mean_ms": markPublicationStats.mean,
    "guard": guard})

main()
