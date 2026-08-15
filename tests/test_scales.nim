# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPlot

suite "scales":
  test "linear scale maps its domain endpoints":
    let scale = continuousScale(0, 10, 20, 120)
    check scale.map(0) == 20
    check scale.map(10) == 120
    check scale.ticks(3) == @[0.0, 5.0, 10.0]

  test "log scale rejects non-positive domains":
    expect PlotError: discard continuousScale(0, 10, 0, 1, skLog10)

  test "band scale retains first category order":
    let scale = trainBand(["b", "a", "b"], 0, 100)
    check scale.domain == @["b", "a"]
    check scale.map("b") < scale.map("a")

  test "continuous domains train incrementally without retaining samples":
    var domain = initContinuousDomain()
    domain.addValues([4.0, NaN, 2.0])
    domain.addValues([8.0, 1.0])
    let scale = domain.train(0, 100)
    check scale.domainMin == 1.0
    check scale.domainMax == 8.0
    check scale.map(1.0) == 0
    check scale.map(8.0) == 100

    var logDomain = initContinuousDomain(skLog10)
    logDomain.addValues([-1.0, 10.0, 100.0])
    check logDomain.train(0, 1).domainMin == 10.0

  test "invalid domains, ranges, values and tick counts are rejected":
    expect PlotError: discard continuousScale(1, 1, 0, 1)
    expect PlotError: discard continuousScale(NaN, 1, 0, 1)
    expect PlotError: discard continuousScale(0, 1, NaN, 1)
    expect PlotError: discard continuousScale(1, 10, 0, 1, skLog10).map(0)
    expect PlotError: discard continuousScale(0, 1, 0, 1).ticks(1)
    expect PlotError: discard trainContinuous([], 0, 1)
    expect PlotError: discard initContinuousDomain().train(0, 1)
    expect PlotError: discard trainBand([], 0, 1)
    expect PlotError: discard trainBand(["a"], 0, 0)
    expect PlotError: discard trainBand(["a"], 0, 1, 1)
    expect PlotError: discard trainBand(["a"], 0, 1).map("b")
