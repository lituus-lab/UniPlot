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
  for discardIndex in 0 ..< Warmups:
    let warmScene = makeSpec().compileScene(Size(width: 800, height: 600))
    discard warmScene.renderImage(font)
  var snapshotStats, compileStats, publicationStats: RunningStat
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
  echo $(%*{"provider": "UniPlot-raster-spec", "iterations": iterations,
    "warmup_iterations": Warmups, "source": "512x512 RGBA8",
    "canvas": "800x600", "filter": "bilinear",
    "semantics": "PlotSpec construction plus snapshot; compile includes alpha-correct resize; publication includes CPU render",
    "construction_snapshot_mean_ms": snapshotStats.mean,
    "compile_mean_ms": compileStats.mean,
    "publication_mean_ms": publicationStats.mean, "guard": guard})

main()
