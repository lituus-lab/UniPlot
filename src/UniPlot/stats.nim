# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, tables]
import contracts
import UniAccurate
import UniMath
import UniStatistics as statistics
import UniPlot/common

type HistogramBin* = object
  lower*, upper*: float64
  count*: int

type HistogramRule* = enum
  ## Automatic equal-width histogram bin-selection rules.
  hrAuto
  hrSquareRoot
  hrSturges
  hrRice
  hrScott
  hrFreedmanDiaconis

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

  GroupedValue* = object
    group*: string
    value*: float64
    count*: int

  ContourSegment* = object
    ## One isoline segment in original data coordinates.
    level*, x0*, y0*, x1*, y1*: float64

proc contourRatio(level, first, last: float64): float64 =
  let
    numerator = level - first
    denominator = last - first
  result = if numerator.isFinite and denominator.isFinite:
      numerator / denominator
    else:
      (level * 0.5 - first * 0.5) / (last * 0.5 - first * 0.5)
  if not result.isFinite or result < 0.0 or result > 1.0:
    raise newException(PlotError, "contour interpolation is not finite")

proc contourSegments*(xs, ys, values, levels: openArray[float64]):
    seq[ContourSegment] {.contractual.} =
  ## Extract deterministic marching-squares segments from a row-major grid.
  require:
    xs.len >= 2 and ys.len >= 2
    levels.len > 0
  body:
    if xs.len < 2 or ys.len < 2 or levels.len == 0 or
        xs.len > high(int) div ys.len or values.len != xs.len * ys.len:
      raise newException(PlotError, "invalid contour grid dimensions")
    for coordinates in [@xs, @ys, @levels]:
      for index, value in coordinates:
        if not value.isFinite or
            (index > 0 and value <= coordinates[index - 1]):
          raise newException(PlotError,
            "contour coordinates and levels must be finite and increasing")
    type DataPoint = tuple[x, y: float64]
    proc interpolateEdge(edge: int; level, x0, x1, y0, y1,
        v00, v10, v11, v01: float64): DataPoint =
      var ax, ay, av, bx, by, bv: float64
      case edge
      of 0: (ax, ay, av, bx, by, bv) = (x0, y0, v00, x1, y0, v10)
      of 1: (ax, ay, av, bx, by, bv) = (x1, y0, v10, x1, y1, v11)
      of 2: (ax, ay, av, bx, by, bv) = (x1, y1, v11, x0, y1, v01)
      of 3: (ax, ay, av, bx, by, bv) = (x0, y1, v01, x0, y0, v00)
      else: raise newException(PlotError, "invalid contour edge")
      let ratio = contourRatio(level, av, bv)
      result = (ax * (1.0 - ratio) + bx * ratio,
        ay * (1.0 - ratio) + by * ratio)
      if not result.x.isFinite or not result.y.isFinite:
        raise newException(PlotError, "contour coordinate is not finite")
    proc addPair(output: var seq[ContourSegment]; isoLevel: float64;
        firstEdge, secondEdge: int;
        cellX0, cellX1, cellY0, cellY1,
        cellV00, cellV10, cellV11, cellV01: float64) =
      let
        first = interpolateEdge(firstEdge, isoLevel,
          cellX0, cellX1, cellY0, cellY1,
          cellV00, cellV10, cellV11, cellV01)
        second = interpolateEdge(secondEdge, isoLevel,
          cellX0, cellX1, cellY0, cellY1,
          cellV00, cellV10, cellV11, cellV01)
      output.add ContourSegment(level: isoLevel, x0: first.x, y0: first.y,
        x1: second.x, y1: second.y)
    for level in levels:
      for row in 0 ..< ys.len - 1:
        for column in 0 ..< xs.len - 1:
          let
            v00 = values[row * xs.len + column]
            v10 = values[row * xs.len + column + 1]
            v11 = values[(row + 1) * xs.len + column + 1]
            v01 = values[(row + 1) * xs.len + column]
          if not v00.isFinite or not v10.isFinite or not v11.isFinite or
              not v01.isFinite:
            continue
          let mask = (if v00 >= level: 1 else: 0) or
            (if v10 >= level: 2 else: 0) or
            (if v11 >= level: 4 else: 0) or
            (if v01 >= level: 8 else: 0)
          template pair(a, b: int) =
            addPair(result, level, a, b, xs[column], xs[column + 1],
              ys[row], ys[row + 1], v00, v10, v11, v01)
          case mask
          of 0, 15: discard
          of 1, 14: pair(3, 0)
          of 2, 13: pair(0, 1)
          of 3, 12: pair(3, 1)
          of 4, 11: pair(1, 2)
          of 6, 9: pair(0, 2)
          of 7, 8: pair(3, 2)
          of 5, 10:
            let centre = v00 * 0.25 + v10 * 0.25 + v11 * 0.25 + v01 * 0.25
            let connectHigh = centre >= level
            if (mask == 5 and connectHigh) or (mask == 10 and not connectHigh):
              pair(0, 1)
              pair(2, 3)
            else:
              pair(3, 0)
              pair(1, 2)
          else: raise newException(PlotError, "invalid contour topology")

proc finiteSorted(values: openArray[float64]): seq[float64] =
  result = newSeqOfCap[float64](values.len)
  for value in values:
    if value.isFinite: result.add value
  result.sort()

func quantileSorted(values: openArray[float64]; probability: float64): float64
proc histogramBreaks*(values, breaks: openArray[float64]):
    seq[HistogramBin]

func boundedBinCount(candidate: float64; sampleCount: int): int =
  if not candidate.isFinite or candidate >= float64(sampleCount):
    sampleCount
  else:
    max(1, int(ceil(candidate)))

proc normalizedFinite(values: openArray[float64]):
    tuple[sorted: seq[float64]; magnitude: float64] =
  result.sorted = finiteSorted(values)
  if result.sorted.len == 0: return
  result.magnitude = max(abs(result.sorted[0]), abs(result.sorted[^1]))
  if result.magnitude > 0:
    for value in result.sorted.mitems:
      value /= result.magnitude

proc histogramBinCount*(values: openArray[float64]; rule = hrAuto): int =
  ## Select an equal-width bin count from finite samples. Scale-dependent rules
  ## operate on normalized values, avoiding overflow for extreme finite ranges.
  let normalized = normalizedFinite(values)
  let finite = normalized.sorted
  if finite.len == 0: return 0
  if finite[0] == finite[^1]: return 1
  let
    sampleCount = finite.len
    count = float64(sampleCount)
    cubeRoot = cbrt(count)
    sturges = boundedBinCount(log2(count) + 1.0, sampleCount)
  case rule
  of hrAuto, hrFreedmanDiaconis:
    let
      spread = quantileSorted(finite, 0.75) - quantileSorted(finite, 0.25)
      width = 2.0 * spread / cubeRoot
    if width > 0 and width.isFinite:
      result = boundedBinCount((finite[^1] - finite[0]) / width, sampleCount)
    else:
      result = sturges
  of hrSquareRoot:
    result = boundedBinCount(sqrt(count), sampleCount)
  of hrSturges:
    result = sturges
  of hrRice:
    result = boundedBinCount(2.0 * cubeRoot, sampleCount)
  of hrScott:
    let mean = statistics.mean(finite)
    var squares = newSeqOfCap[float64](sampleCount)
    for value in finite:
      let deviation = value - mean
      squares.add deviation * deviation
    let
      deviation = sqrt(neumaierSum(squares, assumeFinite = true) / count)
      width = 3.5 * deviation / cubeRoot
    if width > 0 and width.isFinite:
      result = boundedBinCount((finite[^1] - finite[0]) / width, sampleCount)
    else:
      result = sturges

proc automaticHistogramBreaks*(values: openArray[float64]; rule = hrAuto):
    seq[float64] =
  ## Return finite, strictly increasing equal-width boundaries. Adjacent
  ## float64 values can make requested interior boundaries unrepresentable;
  ## those duplicates are removed rather than emitting an invalid interval.
  let finite = finiteSorted(values)
  if finite.len == 0: return
  let
    lower = finite[0]
    upper = finite[^1]
  if lower == upper:
    let unitWidth = lower + 1.0
    if unitWidth.isFinite and unitWidth > lower:
      return @[lower, unitWidth]
    let successor = nextUp(lower)
    if successor.isFinite:
      return @[lower, successor]
    let predecessor = nextDown(lower)
    if predecessor.isFinite:
      return @[predecessor, lower]
    raise newException(PlotError,
      "constant histogram value has no finite neighbouring boundary")
  let count = histogramBinCount(finite, rule)
  result = newSeqOfCap[float64](count + 1)
  result.add lower
  for index in 1 ..< count:
    let
      ratio = float64(index) / float64(count)
      boundary = lower * (1.0 - ratio) + upper * ratio
    if boundary.isFinite and boundary > result[^1] and boundary < upper:
      result.add boundary
  result.add upper

proc histogram*(values: openArray[float64]; rule: HistogramRule):
    seq[HistogramBin] =
  ## Histogram using an automatic equal-width selection rule.
  let breaks = automaticHistogramBreaks(values, rule)
  if breaks.len == 0: return
  histogramBreaks(values, breaks)

func quantileSorted(values: openArray[float64]; probability: float64): float64 =
  statistics.quantile(values, probability)

proc aggregateFinite(values: openArray[float64]; kind: AggregationKind):
    tuple[value: float64; count: int] =
  result = (NaN, values.len)
  case kind
  of agCount:
    result.value = float64(values.len)
  of agSum:
    if values.len > 0:
      result.value = neumaierSum(values, assumeFinite = true)
  of agMean:
    if values.len > 0:
      result.value = statistics.mean(values)
  of agMinimum:
    if values.len > 0:
      result.value = values[0]
      for value in values: result.value = min(result.value, value)
  of agMaximum:
    if values.len > 0:
      result.value = values[0]
      for value in values: result.value = max(result.value, value)

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
    result.mean = statistics.mean(finite)
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
          let aggregated = aggregateFinite(finite, kind)
          cell.value = aggregated.value
          cell.count = aggregated.count
        result.add cell

proc aggregateGroups*(groups: openArray[string]; values: openArray[float64];
    kind = agMean): seq[GroupedValue] {.contractual.} =
  ## Aggregate finite values per category in first-seen group order.
  require:
    groups.len == values.len
    groups.len > 0
  ensure:
    result.len > 0
  body:
    if groups.len != values.len or groups.len == 0:
      raise newException(PlotError, "grouped aggregation columns must align")
    var
      order: seq[string]
      samples = initTable[string, seq[float64]]()
    for index, group in groups:
      if group.len == 0:
        raise newException(PlotError,
          "grouped aggregation categories cannot be empty")
      if group notin samples:
        samples[group] = @[]
        order.add group
      if values[index].isFinite:
        samples[group].add values[index]
    result = newSeqOfCap[GroupedValue](order.len)
    for group in order:
      let aggregated = aggregateFinite(samples[group], kind)
      result.add GroupedValue(group: group, value: aggregated.value,
        count: aggregated.count)

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
    # Interpolated between the ends, as `automaticHistogramBreaks` does, rather
    # than stepped from `lo`: `hi - lo` overflows to infinity across an extreme
    # finite range, which made every boundary after the first infinite and the
    # first one NaN. `histogram(@[-1e308, 1e308], 2)` showed it.
    proc boundary(index: int): float64 =
      if index == 0: lo
      elif index == binCount: hi
      else:
        let ratio = float64(index) / float64(binCount)
        lo * (1.0 - ratio) + hi * ratio
    for i in 0 ..< binCount:
      result.add HistogramBin(lower: boundary(i), upper: boundary(i + 1))
    for value in finite:
      # Located by the boundaries themselves, because a width computed from the
      # ends overflows the same way the step did -- but by halving, not by
      # scanning: a linear walk made this O(values * bins), which is billions
      # of comparisons at a hundred thousand of each. The uppers ascend, so the
      # first one above the value is the bin.
      var low = 0
      var high = binCount - 1
      while low < high:
        let middle = (low + high) div 2
        if value < result[middle].upper: high = middle
        else: low = middle + 1
      inc result[low].count

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
