# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, unittest]
import contracts
import UniPlot

suite "statistics":
  test "histogram counts every finite sample":
    let bins = histogram([0.0, 0.2, 0.8, 1.0], 2)
    check bins.len == 2
    check bins[0].count + bins[1].count == 4

  test "histogram recipe produces one bar per bin":
    let spec = histogramPlot([0.0, 0.2, 0.8, 1.0], 2)
    check spec.layers.len == 1
    check spec.data.rowCount == 2
    let explicit = histogramBreaksPlot(
      [0.0, 0.5, 1.0, 2.0], [0.0, 1.0, 3.0])
    check explicit.layers.len == 1
    check explicit.data.rowCount == 2
    check explicit.data.numeric("value") == @[2.0, 2.0]

  test "numeric histograms preserve interval width and optional density":
    let counts = histogramPlot(
      [0.0, 0.5, 1.0, 2.0, 3.0], [0.0, 1.0, 3.0])
    check counts.layers[0].mark == mkRect
    check counts.data.numeric("xMin") == @[0.0, 1.0]
    check counts.data.numeric("xMax") == @[1.0, 3.0]
    check counts.data.numeric("yMax") == @[2.0, 3.0]
    discard counts.compileScene()

    let density = histogramPlot(
      [0.0, 0.5, 1.0, 2.0, 3.0], [0.0, 1.0, 3.0], density = true)
    let heights = density.data.numeric("yMax")
    check abs(heights[0] * 1.0 + heights[1] * 2.0 - 1.0) < 1e-12
    check histogramPlot([], [0.0, 1.0], density = true).data.numeric(
      "yMax") == @[0.0]
    expect PlotError:
      discard histogramPlot([0.0], [-1e308, 1e308])

  test "histograms reject invalid bin counts and ignore non-finite input":
    expect PlotError: discard histogram([1.0], 0)
    check histogram([NaN, Inf], 3).len == 0

  test "explicit histogram breaks define half-open bins and a closed end":
    let bins = histogramBreaks(
      [-1.0, 0.0, 0.5, 1.0, 2.0, 3.0, NaN], [0.0, 1.0, 2.0])
    check bins == @[
      HistogramBin(lower: 0.0, upper: 1.0, count: 2),
      HistogramBin(lower: 1.0, upper: 2.0, count: 2)]
    check histogramBreaks([], [0.0, 1.0]).len == 1
    expect PlotError: discard histogramBreaks([1.0], [0.0, 0.0])
    expect PlotError: discard histogramBreaks([1.0], [0.0, Inf])
    when defined(release):
      expect PlotError: discard histogramBreaks([1.0], [0.0])
    else:
      expect PreConditionDefect: discard histogramBreaks([1.0], [0.0])

  test "quantiles use type-seven interpolation and ignore non-finite values":
    let values = [4.0, 1.0, NaN, 3.0, 2.0, Inf]
    check quantile(values, 0.0) == 1.0
    check quantile(values, 0.25) == 1.75
    check quantile(values, 0.5) == 2.5
    check quantile(values, 0.75) == 3.25
    check quantile(values, 1.0) == 4.0
    check quantile([-1e308, 1e308], 0.5) == 0.0
    expect PlotError: discard quantile([NaN, Inf], 0.5)
    when defined(release):
      expect PlotError: discard quantile([1.0], -0.1)
    else:
      expect PreConditionDefect: discard quantile([1.0], -0.1)

  test "descriptive summaries retain Tukey whiskers and outliers":
    let summary = summarize([1.0, 2.0, 2.0, 3.0, 4.0, 100.0, NaN])
    check summary.count == 6
    check summary.minimum == 1.0
    check summary.firstQuartile == 2.0
    check summary.median == 2.5
    check summary.thirdQuartile == 3.75
    check summary.maximum == 100.0
    check summary.lowerWhisker == 1.0
    check summary.upperWhisker == 4.0
    check summary.outliers == @[100.0]
    check abs(summary.mean - 18.666666666666668) < 1e-12
    check summarize([1e308, 1e308]).mean == 1e308
    expect PlotError: discard summarize([NaN])
    when defined(release):
      expect PlotError: discard summarize([1.0], -1.0)
    else:
      expect PreConditionDefect: discard summarize([1.0], -1.0)

  test "box-plot recipe retains summaries and outliers as separate layers":
    let spec = boxPlot(["a", "a", "a", "a", "a", "b", "b"],
      [1.0, 2.0, 3.0, 4.0, 100.0, 8.0, 9.0])
    check spec.layers.len == 2
    check spec.layers[0].mark == mkBoxPlot
    check spec.layers[1].mark == mkPoint
    check spec.data.rowCount == 3
    check spec.data.categorical("category") == @["a", "a", "b"]
    check spec.data.numeric("outlier")[1] == 100.0
    discard spec.compileScene()
    when defined(release):
      expect PlotError: discard boxPlot(["a"], [1.0, 2.0])
    else:
      expect PreConditionDefect: discard boxPlot(["a"], [1.0, 2.0])
    expect PlotError: discard boxPlot(["empty"], [NaN])

  test "2D aggregation preserves a complete first-seen category matrix":
    let cells = aggregate2D(
      ["left", "right", "left", "left"],
      ["north", "north", "south", "north"],
      [1.0, 4.0, NaN, 3.0])
    check cells.len == 4
    check cells[0] == AggregatedCell(x: "left", y: "north", value: 2.0,
      count: 2)
    check cells[1] == AggregatedCell(x: "right", y: "north", value: 4.0,
      count: 1)
    check cells[2].x == "left" and cells[2].y == "south"
    check classify(cells[2].value) == fcNan and cells[2].count == 0
    check cells[3].x == "right" and cells[3].y == "south"
    check classify(cells[3].value) == fcNan and cells[3].count == 0
    let counts = aggregate2D(["x", "x"], ["y", "y"], [NaN, 2.0], agCount)
    check counts[0].value == 1.0
    check aggregate2D(["x", "x"], ["y", "y"], [1e308, 1e308],
      agMean)[0].value == 1e308
    when defined(release):
      expect PlotError: discard aggregate2D(["x"], ["y", "z"], [1.0])
    else:
      expect PreConditionDefect:
        discard aggregate2D(["x"], ["y", "z"], [1.0])

  test "grouped aggregation preserves first-seen categories and finite counts":
    let grouped = aggregateGroups(
      ["beta", "alpha", "beta", "empty"], [1.0, 4.0, 3.0, NaN])
    check grouped[0 .. 1] == @[
      GroupedValue(group: "beta", value: 2.0, count: 2),
      GroupedValue(group: "alpha", value: 4.0, count: 1)]
    check grouped[2].group == "empty" and grouped[2].count == 0
    check classify(grouped[2].value) == fcNan
    check aggregateGroups(["x", "x"], [1e308, 1e308], agMean)[0].value ==
      1e308
    check aggregateGroups(["x", "x"], [NaN, 2.0], agCount)[0].value == 1.0
    let missingCount = aggregateGroups(["x"], [NaN], agCount)[0]
    check missingCount.value == 0.0 and missingCount.count == 0
    check aggregateGroups(["x", "x"], [3.0, 2.0], agSum)[0].value == 5.0
    check aggregateGroups(["x", "x"], [3.0, 2.0], agMinimum)[0].value == 2.0
    check aggregateGroups(["x", "x"], [3.0, 2.0], agMaximum)[0].value == 3.0
    expect PlotError: discard aggregateGroups([""], [1.0])
    when defined(release):
      expect PlotError: discard aggregateGroups(["x"], [1.0, 2.0])
    else:
      expect PreConditionDefect:
        discard aggregateGroups(["x"], [1.0, 2.0])

    let spec = groupedAggregatePlot(
      ["beta", "alpha", "beta"], [1.0, 4.0, 3.0], agSum)
    check spec.layers.len == 1
    check spec.data.categorical("category") == @["beta", "alpha"]
    check spec.data.numeric("value") == @[4.0, 4.0]
