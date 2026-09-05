# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[sequtils, unittest]
import UniPlot

suite "scales":
  test "linear scale maps its domain endpoints":
    let scale = continuousScale(0, 10, 20, 120)
    check scale.map(0) == 20
    check scale.map(10) == 120
    check scale.ticks(3) == @[0.0, 5.0, 10.0]

  test "ticks remain unique at floating-point resolution":
    let
      first = 1_704_067_200.0
      last = first + 2.384185791015625e-7
      scale = continuousScale(first, last, 0, 1)
    check scale.ticks() == @[first, last]
    check scale.axisTicks(alkUtcDateTime) == @[first, last]

  test "linear interpolation remains finite across an extreme domain":
    let scale = continuousScale(-1e308, 1e308, 0, 100)
    check scale.map(-1e308) == 0
    check scale.map(0) == 50
    check scale.map(1e308) == 100
    check scale.ticks(3) == @[-1e308, 0.0, 1e308]

    let extrapolated = continuousScale(1e308, 1.1e308, 0, 1)
    check abs(extrapolated.map(-1e308) - -20.0) < 1e-5

  test "continuous and band ranges may be reversed":
    let continuous = continuousScale(0, 10, 120, 20)
    check continuous.map(0) == 120
    check continuous.map(10) == 20
    let band = trainBand(["a", "b"], 100, 0)
    check band.map("a") > band.map("b")

  test "log scale rejects non-positive domains":
    expect PlotError: discard continuousScale(0, 10, 0, 1, skLog10)

  test "symmetric log scales retain signs, zero and original-unit ticks":
    let scale = continuousScale(-99, 99, 0, 100, skSymLog10)
    check scale.map(-99) == 0
    check abs(scale.map(-9) - 25) < 1e-5
    check scale.map(0) == 50
    check abs(scale.map(9) - 75) < 1e-5
    check scale.map(99) == 100
    let values = scale.ticks(3)
    check values[0] == -99
    check abs(values[1]) < 1e-15
    check values[2] == 99

    let extreme = continuousScale(-1e308, 1e308, 0, 1, skSymLog10)
    check extreme.map(-1e308) == 0
    check extreme.map(0) == 0.5
    check extreme.map(1e308) == 1
    check extreme.ticks(3).allIt(it.isFinite)

  test "signed power scales map negative and positive values monotonically":
    let square = continuousScale(-2, 2, 0, 100, skPower, 2.0)
    check square.map(-2) == 0
    check abs(square.map(-1) - 37.5) < 1e-5
    check square.map(0) == 50
    check abs(square.map(1) - 62.5) < 1e-5
    check square.map(2) == 100
    check square.ticks(3) == @[-2.0, 0.0, 2.0]
    let root = continuousScale(-4, 4, 0, 100, skPower, 0.5)
    check root.map(-4) == 0
    check root.map(0) == 50
    check root.map(4) == 100
    expect PlotError:
      discard continuousScale(-1, 1, 0, 1, skPower, 0.0)

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

  test "UTC ticks are deterministic and calendar aligned":
    let year = continuousScale(1_704_067_200, 1_735_689_600, 0, 100)
    let values = year.axisTicks(alkUtcDateTime)
    check values.len == 13
    check year.axisTickLabel(values[0], alkUtcDateTime) == "2024-01"
    check year.axisTickLabel(values[^1], alkUtcDateTime) == "2025-01"
    let seconds = continuousScale(1_704_067_200, 1_704_067_260, 0, 100)
    check seconds.axisTicks(alkUtcDateTime) == @[
      1_704_067_200.0, 1_704_067_215.0, 1_704_067_230.0,
      1_704_067_245.0, 1_704_067_260.0]
    check seconds.axisTickLabel(1_704_067_200, alkUtcDateTime) ==
      "2024-01-01 00:00:00"

  test "duration labels are signed and reject invalid combinations":
    let duration = continuousScale(-90, 3690, 0, 100)
    check duration.axisTickLabel(-90, alkDuration) == "−1:30"
    check duration.axisTickLabel(3690, alkDuration) == "1:01:30"
    check duration.axisTicks(alkDuration).len >= 2
    expect PlotError:
      discard continuousScale(1, 10, 0, 1, skLog10).axisTicks(alkDuration)
    expect PlotError:
      discard continuousScale(MinimumUtcSecond - 1, 0, 0, 1).axisTicks(
        alkUtcDateTime)
    expect PlotError: discard duration.axisTicks(alkDuration, 1)

  test "temporal boundaries and singleton padding remain valid":
    for value in [MinimumUtcSecond, MaximumUtcSecond]:
      var domain = initContinuousDomain()
      domain.addValues([value])
      let scale = domain.trainAxis(0, 100, alkUtcDateTime)
      check scale.domainMin >= MinimumUtcSecond
      check scale.domainMax <= MaximumUtcSecond
      check scale.axisTicks(alkUtcDateTime).len >= 2
    var durationDomain = initContinuousDomain()
    durationDomain.addValues([MaximumDurationSecond])
    let durationScale = durationDomain.trainAxis(0, 1, alkDuration)
    check durationScale.domainMax == MaximumDurationSecond
    check durationScale.domainMin < durationScale.domainMax

    let reversedDomain = continuousScale(120, -120, 0, 1)
    check reversedDomain.axisTicks(alkDuration).len >= 2
    expect PlotError:
      discard continuousScale(0, MaximumDurationSecond + 1, 0, 1).
        axisTicks(alkDuration)

  test "duration labels preserve tick precision beyond one day":
    let scale = continuousScale(86_400, 86_520, 0, 100)
    let values = scale.axisTicks(alkDuration)
    let labels = values.mapIt(scale.axisTickLabel(it, alkDuration))
    check labels == @["1d 00:00:00", "1d 00:00:30", "1d 00:01:00",
      "1d 00:01:30", "1d 00:02:00"]
    expect PlotError: discard scale.axisTickLabel(NaN, alkDuration)
    expect PlotError: discard scale.axisTickLabel(Inf, alkUtcDateTime)
    expect PlotError:
      discard scale.axisTickLabel(MaximumDurationSecond + 1, alkDuration)

    let fractionalDuration = continuousScale(86_400.1, 86_400.5, 0, 100)
    let durationLabels = fractionalDuration.axisTicks(alkDuration).mapIt(
      fractionalDuration.axisTickLabel(it, alkDuration))
    check durationLabels == @["1d 00:00:00.1", "1d 00:00:00.2",
      "1d 00:00:00.3", "1d 00:00:00.4", "1d 00:00:00.5"]

    let fractionalUtc = continuousScale(
      1_704_067_200.1, 1_704_067_200.5, 0, 100)
    let utcLabels = fractionalUtc.axisTicks(alkUtcDateTime).mapIt(
      fractionalUtc.axisTickLabel(it, alkUtcDateTime))
    check utcLabels == @["2024-01-01 00:00:00.1",
      "2024-01-01 00:00:00.2", "2024-01-01 00:00:00.3",
      "2024-01-01 00:00:00.4", "2024-01-01 00:00:00.5"]
