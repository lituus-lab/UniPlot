# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Measure one UniPlot memory phase in a fresh process. Peak values are process
## high-water marks; deltas therefore describe growth beyond phase setup, not
## cumulative allocation traffic.
import std/[json, math, os, strutils]
when defined(posix):
  import posix

import UniGlyph
import UniPlot

when not defined(gcOrc):
  {.error: "benchmark_memory requires --mm:orc for comparable heap counters".}

const Canvas = Size(width: 800, height: 500)

proc sampleSpec(count: int): PlotSpec =
  var
    x = newSeq[float64](count)
    y = newSeq[float64](count)
  for index in 0 ..< count:
    x[index] = float64(index) / 25.0
    y[index] = sin(x[index]) + 0.02 * x[index]
  result = linePlot(x, y)
  result.geomPoint(aes("x", "y"), color = "#cc3344", radius = 2)
  result.labels(title = "Memory benchmark", x = "x", y = "y")

proc peakRssBytes(): int64 =
  when defined(posix):
    var usage: Rusage
    if getrusage(RUSAGE_SELF, addr usage) != 0:
      raise newException(OSError, "getrusage failed")
    when defined(linux):
      int64(usage.ru_maxrss) * 1024'i64
    elif defined(macosx):
      int64(usage.ru_maxrss)
    else:
      -1'i64
  else:
    -1'i64

proc memorySnapshot(): tuple[peakHeap, occupiedHeap: int64; peakRss: int64] =
  (int64(getMaxMem()), int64(getOccupiedMem()), peakRssBytes())

proc nonNegativeDelta(after, before: int64): int64 =
  if after < 0 or before < 0: -1'i64 else: max(0'i64, after - before)

proc report(phase: string; points, guard: int;
    before: tuple[peakHeap, occupiedHeap: int64; peakRss: int64]) =
  let after = memorySnapshot()
  echo $(%*{
    "schema": 1,
    "provider": "UniPlot",
    "memory_manager": "orc",
    "phase": phase,
    "points": points,
    "canvas": {"width": Canvas.width, "height": Canvas.height},
    "memory": {
      "process_peak_rss_bytes": after.peakRss,
      "phase_peak_rss_growth_bytes": nonNegativeDelta(after.peakRss,
        before.peakRss),
      "process_peak_heap_bytes": after.peakHeap,
      "phase_peak_heap_growth_bytes": nonNegativeDelta(after.peakHeap,
        before.peakHeap),
      "phase_live_heap_growth_bytes": after.occupiedHeap - before.occupiedHeap
    },
    "guard": guard
  })

when isMainModule:
  if paramCount() != 3:
    quit("usage: benchmark_memory PHASE POINTS FONT", QuitFailure)
  let
    phase = paramStr(1)
    points = parseInt(paramStr(2))
    font = loadTtf(paramStr(3))
  if points <= 0:
    quit("POINTS must be positive", QuitFailure)

  case phase
  of "construct_compile":
    GC_fullCollect()
    let before = memorySnapshot()
    let scene = sampleSpec(points).compileScene(Canvas)
    report(phase, points, scene.nodes.len, before)
  of "cpu_prepare_scene":
    let scene = sampleSpec(points).compileScene(Canvas)
    GC_fullCollect()
    let before = memorySnapshot()
    let prepared = scene.prepareScene(font)
    report(phase, points, prepared.size.width, before)
  of "svg_from_prepared_scene":
    let prepared = sampleSpec(points).compileScene(Canvas).prepareScene(font)
    GC_fullCollect()
    let before = memorySnapshot()
    let output = prepared.toSvg()
    report(phase, points, output.len, before)
  of "png_from_prepared_scene":
    let prepared = sampleSpec(points).compileScene(Canvas).prepareScene(font)
    GC_fullCollect()
    let before = memorySnapshot()
    let output = prepared.encodePng()
    report(phase, points, output.len, before)
  else:
    quit("unknown memory benchmark phase: " & phase, QuitFailure)
