# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat, tables]
import UniPlot/common

type
  ScaleKind* = enum
    skLinear
    skLog10

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

proc map*(scale: ContinuousScale; value: float64): float32 =
  if not value.isFinite or (scale.kind == skLog10 and value <= 0):
    raise newException(PlotError, "value is outside the scale domain")
  let
    a = if scale.kind == skLog10: log10(scale.domainMin) else: scale.domainMin
    b = if scale.kind == skLog10: log10(scale.domainMax) else: scale.domainMax
    v = if scale.kind == skLog10: log10(value) else: value
    t = (v - a) / (b - a)
  scale.rangeMin + float32(t) * (scale.rangeMax - scale.rangeMin)

proc trainContinuous*(values: openArray[float64]; rangeMin, rangeMax: float32;
    kind = skLinear): ContinuousScale =
  var domain = initContinuousDomain(kind)
  domain.addValues(values)
  domain.train(rangeMin, rangeMax)

proc ticks*(scale: ContinuousScale; count = 5): seq[float64] =
  if count < 2: raise newException(PlotError, "tick count must be at least two")
  for i in 0 ..< count:
    let t = float64(i) / float64(count - 1)
    if scale.kind == skLinear:
      result.add scale.domainMin + t * (scale.domainMax - scale.domainMin)
    else:
      result.add pow(10.0, log10(scale.domainMin) + t *
        (log10(scale.domainMax) - log10(scale.domainMin)))

proc tickLabel*(value: float64): string =
  if abs(value) >= 1e5 or (value != 0 and abs(value) < 1e-3): &"{value:.3e}"
  else: &"{value:.4g}"

proc initBandDomain*(): BandDomain =
  result.seen = initTable[string, bool]()

proc addValues*(domain: var BandDomain; values: openArray[string]) =
  for value in values:
    if value notin domain.seen:
      domain.seen[value] = true
      domain.values.add value

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

proc trainBand*(values: openArray[string]; rangeMin, rangeMax: float32;
    padding = 0.1'f32): BandScale =
  var domain = initBandDomain()
  domain.addValues(values)
  domain.train(rangeMin, rangeMax, padding)

proc map*(scale: BandScale; value: string): float32 =
  if value notin scale.positions:
    raise newException(PlotError, "category is outside the scale domain: " & value)
  scale.positions[value]
