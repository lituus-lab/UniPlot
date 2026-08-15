# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, math, tables]
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

type
  AggregationKind* = enum
    agCount
    agSum
    agMean
    agMinimum
    agMaximum

  AggregatedCell* = object
    x*, y*: string
    value*: float64
    count*: int

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

func stableMean(values: openArray[float64]; minimum,
    maximum: float64): float64 =
  let magnitude = max(abs(minimum), abs(maximum))
  if magnitude == 0: return 0
  var normalized = newSeqOfCap[float64](values.len)
  for value in values: normalized.add value / magnitude
  neumaierSum(normalized, assumeFinite = true) / float64(values.len) *
    magnitude

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
    result.mean = stableMean(finite, result.minimum, result.maximum)
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

proc aggregate2D*(xs, ys: openArray[string]; values: openArray[float64];
    kind = agMean): seq[AggregatedCell] {.contractual.} =
  ## Aggregate finite values over a complete first-seen x-by-y matrix.
  require:
    xs.len == ys.len and ys.len == values.len
    xs.len > 0
  ensure:
    result.len > 0
  body:
    if xs.len != ys.len or ys.len != values.len or xs.len == 0:
      raise newException(PlotError, "2D aggregation columns must align")
    var
      xOrder, yOrder: seq[string]
      xSeen, ySeen = initTable[string, bool]()
      observed = initTable[(string, string), bool]()
      samples = initTable[(string, string), seq[float64]]()
    for index in 0 ..< xs.len:
      if xs[index].len == 0 or ys[index].len == 0:
        raise newException(PlotError,
          "2D aggregation categories cannot be empty")
      if xs[index] notin xSeen:
        xSeen[xs[index]] = true
        xOrder.add xs[index]
      if ys[index] notin ySeen:
        ySeen[ys[index]] = true
        yOrder.add ys[index]
      let key = (xs[index], ys[index])
      observed[key] = true
      if values[index].isFinite: samples.mgetOrPut(key, @[]).add values[index]
    result = newSeqOfCap[AggregatedCell](xOrder.len * yOrder.len)
    for y in yOrder:
      for x in xOrder:
        let key = (x, y)
        var cell = AggregatedCell(x: x, y: y, value: NaN)
        if key in observed:
          let finite = samples.getOrDefault(key)
          cell.count = finite.len
          case kind
          of agCount:
            cell.value = float64(finite.len)
          of agSum:
            if finite.len > 0: cell.value = neumaierSum(finite)
          of agMean:
            if finite.len > 0:
              var minimum = finite[0]
              var maximum = finite[0]
              for value in finite:
                minimum = min(minimum, value)
                maximum = max(maximum, value)
              cell.value = stableMean(finite, minimum, maximum)
          of agMinimum:
            if finite.len > 0:
              cell.value = finite[0]
              for value in finite: cell.value = min(cell.value, value)
          of agMaximum:
            if finite.len > 0:
              cell.value = finite[0]
              for value in finite: cell.value = max(cell.value, value)
        result.add cell

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

proc histogramBreaks*(values, breaks: openArray[float64]):
    seq[HistogramBin] {.contractual.} =
  ## Count finite in-domain samples using caller-supplied ordered boundaries.
  require:
    breaks.len >= 2
  ensure:
    result.len == breaks.len - 1
  body:
    if breaks.len < 2:
      raise newException(PlotError,
        "explicit histogram breaks require at least two boundaries")
    for index, boundary in breaks:
      if not boundary.isFinite or
          (index > 0 and boundary <= breaks[index - 1]):
        raise newException(PlotError,
          "explicit histogram breaks must be finite and strictly increasing")
    result = newSeq[HistogramBin](breaks.len - 1)
    for index in 0 ..< result.len:
      result[index] = HistogramBin(lower: breaks[index],
        upper: breaks[index + 1])
    for value in values:
      if not value.isFinite or value < breaks[0] or value > breaks[^1]:
        continue
      if value == breaks[^1]:
        inc result[^1].count
        continue
      var
        lower = 0
        upper = breaks.high
      while lower < upper:
        let middle = lower + (upper - lower) div 2
        if value < breaks[middle]:
          upper = middle
        else:
          lower = middle + 1
      inc result[lower - 1].count
