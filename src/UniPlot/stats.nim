# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/math
import contracts
import UniPlot/common

type HistogramBin* = object
  lower*, upper*: float64
  count*: int

proc histogram*(values: openArray[float64]; binCount = 30): seq[HistogramBin] {.
    contractual.} =
  ensure:
    result.len == 0 or result.len == binCount
  body:
    if binCount <= 0: raise newException(PlotError, "bin count must be positive")
    var finite: seq[float64]
    for value in values:
      if value.isFinite: finite.add value
    if finite.len == 0: return
    var lo = finite[0]
    var hi = finite[0]
    for value in finite:
      lo = min(lo, value); hi = max(hi, value)
    if lo == hi: hi = lo + 1.0
    let step = (hi - lo) / float64(binCount)
    for i in 0 ..< binCount:
      result.add HistogramBin(lower: lo + float64(i) * step,
        upper: lo + float64(i + 1) * step)
    for value in finite:
      let index = min(binCount - 1, int(floor((value - lo) / step)))
      inc result[index].count
