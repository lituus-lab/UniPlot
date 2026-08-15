# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, math]
import contracts
import UniAccurate
import UniPlot/common

type HistogramBin* = object
  lower*, upper*: float64
  count*: int

type DescriptiveSummary* = object
  count*: int
  minimum*, firstQuartile*, median*, thirdQuartile*, maximum*: float64
  lowerWhisker*, upperWhisker*: float64
  mean*: float64
  outliers*: seq[float64]

proc finiteSorted(values: openArray[float64]): seq[float64] =
  result = newSeqOfCap[float64](values.len)
  for value in values:
    if value.isFinite: result.add value
  result.sort()

func quantileSorted(values: openArray[float64]; probability: float64): float64 =
  if values.len == 1: return values[0]
  let
    position = probability * float64(values.high)
    lower = int(floor(position))
    upper = int(ceil(position))
    fraction = position - float64(lower)
  values[lower] * (1.0 - fraction) + values[upper] * fraction

proc quantile*(values: openArray[float64]; probability: float64): float64 {.
    contractual.} =
  ## Return the linearly interpolated sample quantile (Hyndman-Fan type 7).
  require:
    probability.isFinite and probability >= 0 and probability <= 1
  body:
    if not probability.isFinite or probability < 0 or probability > 1:
      raise newException(PlotError, "quantile probability must be in [0, 1]")
    let finite = finiteSorted(values)
    if finite.len == 0:
      raise newException(PlotError, "quantile requires a finite sample")
    result = quantileSorted(finite, probability)

proc summarize*(values: openArray[float64]; whiskerLength = 1.5):
    DescriptiveSummary {.contractual.} =
  ## Compute quartiles, Tukey whiskers, mean and retained finite outliers.
  require:
    whiskerLength.isFinite and whiskerLength >= 0
  ensure:
    result.count > 0
    result.minimum <= result.firstQuartile
    result.firstQuartile <= result.median
    result.median <= result.thirdQuartile
    result.thirdQuartile <= result.maximum
    result.minimum <= result.lowerWhisker
    result.lowerWhisker <= result.upperWhisker
    result.upperWhisker <= result.maximum
  body:
    if not whiskerLength.isFinite or whiskerLength < 0:
      raise newException(PlotError,
        "summary whisker length must be finite and non-negative")
    let finite = finiteSorted(values)
    if finite.len == 0:
      raise newException(PlotError, "summary requires a finite sample")
    result.count = finite.len
    result.minimum = finite[0]
    result.firstQuartile = quantileSorted(finite, 0.25)
    result.median = quantileSorted(finite, 0.5)
    result.thirdQuartile = quantileSorted(finite, 0.75)
    result.maximum = finite[^1]
    let magnitude = max(abs(result.minimum), abs(result.maximum))
    if magnitude == 0:
      result.mean = 0
    else:
      var normalized = newSeqOfCap[float64](finite.len)
      for value in finite: normalized.add value / magnitude
      result.mean = neumaierSum(normalized, assumeFinite = true) /
        float64(finite.len) * magnitude
    let
      spread = result.thirdQuartile - result.firstQuartile
      lowerFence = result.firstQuartile - whiskerLength * spread
      upperFence = result.thirdQuartile + whiskerLength * spread
    result.lowerWhisker = result.minimum
    for value in finite:
      if value >= lowerFence:
        result.lowerWhisker = value
        break
    result.upperWhisker = result.maximum
    for index in countdown(finite.high, 0):
      if finite[index] <= upperFence:
        result.upperWhisker = finite[index]
        break
    for value in finite:
      if value < result.lowerWhisker or value > result.upperWhisker:
        result.outliers.add value

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
