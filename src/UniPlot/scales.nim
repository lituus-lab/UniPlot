# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat, strutils, tables, times]
import UniPlot/common

type
  ScaleKind* = enum
    skLinear
    skLog10

  AxisLabelKind* = enum
    alkNumeric
    alkUtcDateTime
    alkDuration

  ContinuousScale* = object
    kind*: ScaleKind
    domainMin*, domainMax*: float64
    rangeMin*, rangeMax*: float32

  ContinuousDomain* = object
    kind*: ScaleKind
    hasValues: bool
    minimum, maximum: float64

  BandScale* = object
    domain*: seq[string]
    positions*: Table[string, float32]
    rangeMin*, rangeMax*, bandwidth*: float32

  BandDomain* = object
    values: seq[string]
    seen: Table[string, bool]

proc continuousScale*(domainMin, domainMax: float64; rangeMin,
    rangeMax: float32; kind = skLinear): ContinuousScale =
  if not domainMin.isFinite or not domainMax.isFinite or domainMin == domainMax:
    raise newException(PlotError, "scale domain must be finite and non-degenerate")
  if not rangeMin.isFinite or not rangeMax.isFinite:
    raise newException(PlotError, "scale range must be finite")
  if kind == skLog10 and (domainMin <= 0 or domainMax <= 0):
    raise newException(PlotError, "logarithmic domains must be positive")
  ContinuousScale(kind: kind, domainMin: domainMin, domainMax: domainMax,
    rangeMin: rangeMin, rangeMax: rangeMax)

proc initContinuousDomain*(kind = skLinear): ContinuousDomain =
  ContinuousDomain(kind: kind)

proc addValues*(domain: var ContinuousDomain; values: openArray[float64]) =
  for value in values:
    if value.isFinite and (domain.kind != skLog10 or value > 0):
      if not domain.hasValues:
        domain.minimum = value
        domain.maximum = value
        domain.hasValues = true
      else:
        domain.minimum = min(domain.minimum, value)
        domain.maximum = max(domain.maximum, value)

proc merge*(domain: var ContinuousDomain; other: ContinuousDomain) =
  ## Merge an accumulated domain with another domain of the same scale kind.
  if domain.kind != other.kind:
    raise newException(PlotError, "cannot merge different scale kinds")
  if other.hasValues:
    domain.addValues([other.minimum, other.maximum])

proc train*(domain: ContinuousDomain; rangeMin,
    rangeMax: float32): ContinuousScale =
  if not domain.hasValues:
    raise newException(PlotError, "cannot train a scale from empty finite data")
  var lo = domain.minimum
  var hi = domain.maximum
  if lo == hi:
    let pad = if lo == 0: 1.0 else: abs(lo) * 0.05
    lo -= pad
    hi += pad
    if domain.kind == skLog10: lo = max(lo, domain.minimum * 0.5)
  continuousScale(lo, hi, rangeMin, rangeMax, domain.kind)

proc fittedBounds*(domain: ContinuousDomain): tuple[minimum, maximum: float64] =
  ## Return the finite, non-degenerate bounds produced by automatic training.
  let scale = domain.train(0, 1)
  (scale.domainMin, scale.domainMax)

proc train*(domain: ContinuousDomain; rangeMin, rangeMax: float32;
    domainMin, domainMax: float64): ContinuousScale =
  ## Train against an explicit domain that contains every accumulated value.
  if not domain.hasValues:
    raise newException(PlotError, "cannot train a scale from empty finite data")
  if domain.minimum < domainMin or domain.maximum > domainMax:
    raise newException(PlotError,
      "explicit scale domain must contain every rendered value")
  continuousScale(domainMin, domainMax, rangeMin, rangeMax, domain.kind)

proc interpolationRatio(value, first, last: float64): float64 =
  let
    numerator = value - first
    span = last - first
  if numerator.isFinite and span.isFinite:
    result = numerator / span
  else:
    result = (value * 0.5 - first * 0.5) /
      (last * 0.5 - first * 0.5)
  if not result.isFinite:
    raise newException(PlotError, "scale interpolation is not finite")

proc interpolate(first, last, ratio: float64): float64 =
  if ratio == 0: return first
  if ratio == 1: return last
  result = first * (1.0 - ratio) + last * ratio
  if not result.isFinite:
    raise newException(PlotError, "scale interpolation is not finite")

proc map*(scale: ContinuousScale; value: float64): float32 =
  if not value.isFinite or (scale.kind == skLog10 and value <= 0):
    raise newException(PlotError, "value is outside the scale domain")
  let
    a = if scale.kind == skLog10: log10(scale.domainMin) else: scale.domainMin
    b = if scale.kind == skLog10: log10(scale.domainMax) else: scale.domainMax
    v = if scale.kind == skLog10: log10(value) else: value
    t = interpolationRatio(v, a, b)
    mapped = interpolate(float64(scale.rangeMin), float64(scale.rangeMax), t)
  result = float32(mapped)
  if not result.isFinite:
    raise newException(PlotError, "mapped coordinate is not finite")

proc trainContinuous*(values: openArray[float64]; rangeMin, rangeMax: float32;
    kind = skLinear): ContinuousScale =
  var domain = initContinuousDomain(kind)
  domain.addValues(values)
  domain.train(rangeMin, rangeMax)

proc ticks*(scale: ContinuousScale; count = 5): seq[float64] =
  if count < 2: raise newException(PlotError, "tick count must be at least two")
  for i in 0 ..< count:
    let t = float64(i) / float64(count - 1)
    let value = if scale.kind == skLinear:
        interpolate(scale.domainMin, scale.domainMax, t)
      else:
        pow(10.0, log10(scale.domainMin) + t *
          (log10(scale.domainMax) - log10(scale.domainMin)))
    if result.len == 0 or value != result[^1]: result.add value
  if result.len == 1 and scale.domainMax != result[0]:
    result.add scale.domainMax

proc tickLabel*(value: float64): string =
  if abs(value) >= 1e5 or (value != 0 and abs(value) < 1e-3): &"{value:.3e}"
  else: &"{value:.4g}"

const
  MinimumUtcSecond* = -62_135_596_800.0
  MaximumUtcSecond* = 253_402_300_799.0
  MaximumDurationSecond* = 9_000_000_000_000_000.0
  TemporalSecondSteps = [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0,
    120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0, 7200.0, 10800.0,
    21600.0, 43200.0, 86400.0, 172800.0, 604800.0, 1209600.0,
    2419200.0, 7776000.0, 31536000.0, 157680000.0]

proc validateAxisLabels*(scale: ContinuousScale; kind: AxisLabelKind) =
  ## Validate semantic labels independently from the numeric transformation.
  if kind != alkNumeric and scale.kind != skLinear:
    raise newException(PlotError, "temporal labels require a linear scale")
  if kind == alkUtcDateTime and
      (min(scale.domainMin, scale.domainMax) < MinimumUtcSecond or
      max(scale.domainMin, scale.domainMax) > MaximumUtcSecond):
    raise newException(PlotError,
      "UTC axes support years 0001 through 9999")
  if kind == alkDuration and
      max(abs(scale.domainMin), abs(scale.domainMax)) > MaximumDurationSecond:
    raise newException(PlotError, "duration axis magnitude is too large")

proc trainAxis*(domain: ContinuousDomain; rangeMin, rangeMax: float32;
    labels: AxisLabelKind): ContinuousScale =
  ## Train an automatic domain with semantic padding for singleton values.
  if not domain.hasValues:
    raise newException(PlotError, "cannot train a scale from empty finite data")
  if labels != alkNumeric and domain.minimum == domain.maximum:
    let
      padding = if labels == alkUtcDateTime: 30.0
        elif domain.minimum == 0: 1.0
        else: max(1.0, abs(domain.minimum) * 0.05)
      lowerBound = if labels == alkUtcDateTime: MinimumUtcSecond
        else: -MaximumDurationSecond
      upperBound = if labels == alkUtcDateTime: MaximumUtcSecond
        else: MaximumDurationSecond
    var
      lo = max(lowerBound, domain.minimum - padding)
      hi = min(upperBound, domain.maximum + padding)
    if lo == hi:
      let fallback = if labels == alkUtcDateTime: 60.0 else: 1.0
      if lo == lowerBound: hi = min(upperBound, lo + fallback)
      else: lo = max(lowerBound, hi - fallback)
    result = continuousScale(lo, hi, rangeMin, rangeMax, domain.kind)
  else:
    result = domain.train(rangeMin, rangeMax)
  result.validateAxisLabels(labels)

proc alignedTicks(scale: ContinuousScale; step: float64): seq[float64] =
  let
    lo = min(scale.domainMin, scale.domainMax)
    hi = max(scale.domainMin, scale.domainMax)
    first = ceil(lo / step) * step
  var value = first
  while value <= hi and result.len < 10_000:
    result.add value
    value += step
  if result.len < 2:
    result = scale.ticks()

proc calendarTicks(scale: ContinuousScale; yearly: bool): seq[float64] =
  let
    lo = min(scale.domainMin, scale.domainMax)
    hi = max(scale.domainMin, scale.domainMax)
    firstDate = fromUnix(int64(floor(lo))).utc
  var cursor = if yearly:
      dateTime(firstDate.year, mJan, 1, 0, 0, 0, 0, utc())
    else:
      dateTime(firstDate.year, firstDate.month, 1, 0, 0, 0, 0, utc())
  if float64(cursor.toTime.toUnix) < lo:
    cursor = if yearly: cursor + 1.years else: cursor + 1.months
  while float64(cursor.toTime.toUnix) <= hi and result.len < 10_000:
    result.add float64(cursor.toTime.toUnix)
    if cursor.year == 9999 and (yearly or cursor.month == mDec): break
    cursor = if yearly: cursor + 1.years else: cursor + 1.months
  if result.len < 2:
    result = scale.ticks()

proc axisTicks*(scale: ContinuousScale; kind: AxisLabelKind;
    count = 5): seq[float64] =
  ## Produce deterministic numeric, fixed-duration or calendar-aligned ticks.
  scale.validateAxisLabels(kind)
  if count < 2:
    raise newException(PlotError, "tick count must be at least two")
  if kind == alkNumeric:
    return scale.ticks(count)
  let span = abs(scale.domainMax - scale.domainMin)
  if kind == alkUtcDateTime and span > 180.0 * 86400.0:
    return scale.calendarTicks(span > 3.0 * 365.0 * 86400.0)
  let target = span / float64(max(1, count - 1))
  var step = TemporalSecondSteps[^1]
  for candidate in TemporalSecondSteps:
    if candidate >= target:
      step = candidate
      break
  if target > TemporalSecondSteps[^1]:
    return scale.ticks(count)
  scale.alignedTicks(step)

proc fractionalPrecision(span: float64): int =
  if span <= 0 or not span.isFinite: return 0
  max(0, min(15, int(ceil(-log10(span / 4.0))) + 1))

proc decimalField(value, span: float64): string =
  let precision = span.fractionalPrecision
  if precision == 0:
    return $int(round(value))
  result = formatFloat(value, ffDecimal, precision)
  while result.len > 0 and result[^1] == '0': result.setLen(result.len - 1)
  if result.len > 0 and result[^1] == '.': result.setLen(result.len - 1)

proc secondsField(value, span: float64): string =
  result = decimalField(value, span)
  if result.find('.') == 1 or result.len == 1: result = "0" & result

proc fractionalSuffix(value, span: float64): string =
  let fraction = value - floor(value)
  if fraction == 0: return ""
  let field = decimalField(fraction, span)
  let separator = field.find('.')
  if separator >= 0: field[separator .. ^1] else: ""

proc durationTickLabel(value, span: float64): string =
  let
    negative = value < 0
    magnitude = abs(value)
  if magnitude < 60:
    return (if negative: "−" else: "") & decimalField(magnitude, span) & " s"
  let
    whole = int64(floor(magnitude))
    seconds = whole mod 60
    minutes = (whole div 60) mod 60
    hours = (whole div 3600) mod 24
    days = whole div 86400
    prefix = if negative: "−" else: ""
  if days > 0:
    prefix & $days & "d " & align($hours, 2, '0') & ":" &
      align($minutes, 2, '0') & ":" & secondsField(
        float64(seconds) + magnitude - floor(magnitude), span)
  elif whole >= 3600:
    prefix & $hours & ":" & align($minutes, 2, '0') & ":" &
      secondsField(float64(seconds) + magnitude - floor(magnitude), span)
  else:
    prefix & $minutes & ":" & secondsField(
      float64(seconds) + magnitude - floor(magnitude), span)

proc axisTickLabel*(scale: ContinuousScale; value: float64;
    kind: AxisLabelKind): string =
  ## Format one trained-axis tick without locale or local-time-zone state.
  scale.validateAxisLabels(kind)
  if not value.isFinite:
    raise newException(PlotError, "axis tick must be finite")
  case kind
  of alkNumeric:
    tickLabel(value)
  of alkDuration:
    if abs(value) > MaximumDurationSecond:
      raise newException(PlotError, "duration tick magnitude is too large")
    durationTickLabel(value, abs(scale.domainMax - scale.domainMin))
  of alkUtcDateTime:
    if value < MinimumUtcSecond or value > MaximumUtcSecond:
      raise newException(PlotError, "UTC tick is outside years 0001 through 9999")
    let instant = fromUnix(int64(floor(value))).utc
    let span = abs(scale.domainMax - scale.domainMin)
    if span <= 120:
      instant.format("yyyy-MM-dd HH:mm:ss") & value.fractionalSuffix(span)
    elif span <= 2 * 86400: instant.format("MM-dd HH:mm")
    elif span <= 180 * 86400: instant.format("yyyy-MM-dd")
    elif span <= 3 * 365 * 86400: instant.format("yyyy-MM")
    else: instant.format("yyyy")

proc initBandDomain*(): BandDomain =
  result.seen = initTable[string, bool]()

proc addValues*(domain: var BandDomain; values: openArray[string]) =
  for value in values:
    if value notin domain.seen:
      domain.seen[value] = true
      domain.values.add value

proc merge*(domain: var BandDomain; other: BandDomain) =
  ## Merge categories while preserving first appearance across both domains.
  domain.addValues(other.values)

proc train*(domain: BandDomain; rangeMin, rangeMax: float32;
    padding = 0.1'f32): BandScale =
  if not rangeMin.isFinite or not rangeMax.isFinite or rangeMin == rangeMax:
    raise newException(PlotError,
      "band scale range must be finite and non-degenerate")
  if padding < 0 or padding >= 1 or not padding.isFinite:
    raise newException(PlotError, "band padding must be in [0, 1)")
  if domain.values.len == 0:
    raise newException(PlotError, "cannot train a band scale from empty data")
  result.rangeMin = rangeMin
  result.rangeMax = rangeMax
  result.domain = newSeqOfCap[string](domain.values.len)
  for value in domain.values:
    result.domain.add value
  result.positions = initTable[string, float32]()
  let step = (rangeMax - rangeMin) / float32(result.domain.len)
  result.bandwidth = abs(step) * (1 - padding)
  for index, value in result.domain:
    result.positions[value] = rangeMin + (float32(index) + 0.5) * step

proc train*(domain: BandDomain; rangeMin, rangeMax: float32;
    categories: openArray[string]; padding = 0.1'f32): BandScale =
  ## Train in an explicit category order containing every accumulated value.
  if categories.len == 0:
    raise newException(PlotError, "explicit category domain cannot be empty")
  var explicit = initBandDomain()
  for category in categories:
    if category in explicit.seen:
      raise newException(PlotError,
        "explicit category domain cannot contain duplicates")
    explicit.addValues([category])
  for category in domain.values:
    if category notin explicit.seen:
      raise newException(PlotError,
        "explicit category domain must contain every rendered value")
  explicit.train(rangeMin, rangeMax, padding)

proc trainBand*(values: openArray[string]; rangeMin, rangeMax: float32;
    padding = 0.1'f32): BandScale =
  var domain = initBandDomain()
  domain.addValues(values)
  domain.train(rangeMin, rangeMax, padding)

proc map*(scale: BandScale; value: string): float32 =
  if value notin scale.positions:
    raise newException(PlotError, "category is outside the scale domain: " & value)
  scale.positions[value]
