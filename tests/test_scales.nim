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

  test "continuous and band ranges may be reversed":
    let continuous = continuousScale(0, 10, 120, 20)
    check continuous.map(0) == 120
    check continuous.map(10) == 20
    let band = trainBand(["a", "b"], 100, 0)
    check band.map("a") > band.map("b")

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

  test "explicit domains must contain accumulated values":
    var domain = initContinuousDomain()
    domain.addValues([2.0, 4.0, 6.0])
    let scale = domain.train(0, 100, 0.0, 10.0)
    check scale.domainMin == 0.0
    check scale.domainMax == 10.0
    expect PlotError: discard domain.train(0, 100, 3.0, 10.0)
    expect PlotError: discard domain.train(0, 100, 0.0, 5.0)
    expect PlotError: discard domain.train(0, 100, 10.0, 0.0)
    expect PlotError: discard domain.train(0, 100, NaN, 10.0)

  test "band domains retain unique categories across batches":
    var domain = initBandDomain()
    domain.addValues(["b", "a"])
    domain.addValues(["a", "c"])
    let scale = domain.train(0, 120)
    domain.addValues(["d"])
    check scale.domain == @["b", "a", "c"]
    check scale.map("b") < scale.map("c")

  test "explicit band domains preserve order and contain observed values":
    var domain = initBandDomain()
    domain.addValues(["b", "a"])
    check domain.train(0, 100, ["c", "a", "b"]).domain ==
      @["c", "a", "b"]
    expect PlotError: discard domain.train(0, 100, ["a"])
    expect PlotError: discard domain.train(0, 100, ["a", "a", "b"])
    expect PlotError: discard domain.train(0, 100, newSeq[string]())

  test "invalid domains, ranges, values and tick counts are rejected":
    expect PlotError: discard continuousScale(1, 1, 0, 1)
    expect PlotError: discard continuousScale(NaN, 1, 0, 1)
    expect PlotError: discard continuousScale(0, 1, NaN, 1)
    expect PlotError: discard continuousScale(1, 10, 0, 1, skLog10).map(0)
    expect PlotError: discard continuousScale(0, 1, 0, 1).ticks(1)
    expect PlotError: discard trainContinuous([], 0, 1)
    expect PlotError: discard initContinuousDomain().train(0, 1)
    expect PlotError: discard initBandDomain().train(0, 1)
    expect PlotError: discard trainBand([], 0, 1)
    expect PlotError: discard trainBand(["a"], 0, 0)
    expect PlotError: discard trainBand(["a"], 0, 1, 1)
    expect PlotError: discard trainBand(["a"], 0, 1).map("b")
