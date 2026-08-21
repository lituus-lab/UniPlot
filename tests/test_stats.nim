# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, sequtils, unittest]
when not defined(release) and not defined(danger):
  import contracts
from UniMath import nextDown, nextUp
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

  test "automatic histogram rules are deterministic and scale invariant":
    let values = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
    check histogramBinCount(values, hrSquareRoot) == 3
    check histogramBinCount(values, hrSturges) == 4
    check histogramBinCount(values, hrRice) == 4
    check histogramBinCount(values, hrScott) > 0
    check histogramBinCount(values, hrFreedmanDiaconis) > 0
    check histogramBinCount(values, hrAuto) ==
      histogramBinCount(values, hrFreedmanDiaconis)
    check histogramBinCount([NaN, Inf], hrAuto) == 0
    check histogramBinCount([4.0, 4.0, 4.0], hrAuto) == 1
    check histogramBinCount(values, hrScott) == histogramBinCount(
      [0.0, 1e300, 2e300, 3e300, 4e300, 5e300, 6e300, 7e300], hrScott)

  test "automatic histogram boundaries stay finite at float64 extremes":
    let
      extreme = automaticHistogramBreaks([-1e308, 0.0, 1e308], hrSturges)
      adjacentValue = nextUp(1.0)
      adjacent = automaticHistogramBreaks([1.0, adjacentValue], hrRice)
      constant = automaticHistogramBreaks([1e308], hrAuto)
      maximumConstant = automaticHistogramBreaks([nextDown(Inf)], hrAuto)
    check extreme.len >= 2
    for index, boundary in extreme:
      check boundary.isFinite
      if index > 0: check boundary > extreme[index - 1]
    check adjacent == @[1.0, adjacentValue]
    check constant.len == 2
    check constant[0] < constant[1]
    check maximumConstant.len == 2
    check maximumConstant[0] < maximumConstant[1]
    check histogram([-1e308, 0.0, 1e308], hrSturges).mapIt(it.count).sum == 3

  test "automatic histogram recipe preserves counts and density area":
    let
      counts = histogramPlot([0.0, 0.5, 1.0, 2.0], hrSturges)
      density = histogramPlot([0.0, 0.5, 1.0, 2.0], hrSturges,
        density = true)
    check counts.layers.len == 1
    check counts.layers[0].mark == mkRect
    check counts.data.numeric("yMax").sum == 4.0
    var area = 0.0
    for index, height in density.data.numeric("yMax"):
      area += height * (density.data.numeric("xMax")[index] -
        density.data.numeric("xMin")[index])
    check abs(area - 1.0) < 1e-12
    expect PlotError: discard histogramPlot([NaN], hrAuto)
    let singletonDensity = histogramPlot([0.0], hrAuto, density = true)
    check singletonDensity.data.numeric("xMin") == @[0.0]
    check singletonDensity.data.numeric("xMax") == @[1.0]
    check singletonDensity.data.numeric("yMax") == @[1.0]
    expect PlotError:
      discard histogramPlot([0.0], [0.0, nextUp(0.0)], density = true)

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

  test "summaries and grouped means preserve representable extremes":
    let largest = cast[float64](0x7FEF_FFFF_FFFF_FFFF'u64)
    check summarize([largest, largest]).mean == largest
    check aggregateGroups(["a", "a"], [largest, largest], agMean)[0].value ==
      largest

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

  test "numeric heatmaps materialize row-major variable-size cells":
    let heat = numericHeatmapPlot(
      [0.0, 1.0, 3.0], [10.0, 20.0, 40.0],
      [1.0, 2.0, 3.0, NaN])
    check heat.layers[0].mark == mkRect
    check heat.data.numeric("xMin") == @[0.0, 1.0, 0.0, 1.0]
    check heat.data.numeric("xMax") == @[1.0, 3.0, 1.0, 3.0]
    check heat.data.numeric("yMin") == @[10.0, 10.0, 20.0, 20.0]
    check heat.data.numeric("value")[0 .. 2] == @[1.0, 2.0, 3.0]
    discard heat.compileScene()
    when defined(release):
      expect PlotError:
        discard numericHeatmapPlot([0.0], [0.0, 1.0], [])
    else:
      expect PreConditionDefect:
        discard numericHeatmapPlot([0.0], [0.0, 1.0], [])
    expect PlotError:
      discard numericHeatmapPlot([0.0, 1.0], [0.0, 1.0], [1.0, 2.0])
    expect PlotError:
      discard numericHeatmapPlot([-1e308, 1e308], [0.0, 1.0], [1.0])

  test "marching squares extracts plane and saddle contours deterministically":
    let plane = contourSegments([0.0, 1.0], [0.0, 1.0],
      [0.0, 1.0, 1.0, 2.0], [1.0])
    check plane.len == 1
    check plane[0] == ContourSegment(level: 1.0, x0: 0.0, y0: 1.0,
      x1: 1.0, y1: 0.0)

    let saddle = contourSegments([0.0, 1.0], [0.0, 1.0],
      [1.0, -1.0, -1.0, 1.0], [0.0])
    check saddle.len == 2
    check saddle[0] == ContourSegment(level: 0.0, x0: 0.5, y0: 0.0,
      x1: 1.0, y1: 0.5)
    check saddle[1] == ContourSegment(level: 0.0, x0: 0.5, y0: 1.0,
      x1: 0.0, y1: 0.5)

  test "contours skip missing cells and validate grids before indexing":
    check contourSegments([0.0, 1.0], [0.0, 1.0],
      [0.0, NaN, 1.0, 2.0], [1.0]).len == 0
    expect PlotError:
      discard contourSegments([0.0, 0.0], [0.0, 1.0],
        [0.0, 1.0, 1.0, 2.0], [1.0])
    expect PlotError:
      discard contourSegments([0.0, 1.0], [0.0, 1.0], [0.0], [1.0])
    when defined(release) or defined(danger):
      expect PlotError:
        discard contourSegments([0.0], [0.0, 1.0], [0.0], [1.0])
    else:
      expect PreConditionDefect:
        discard contourSegments([0.0], [0.0, 1.0], [0.0], [1.0])

  test "contour recipe retains separated line segments":
    let spec = contourPlot([0.0, 1.0], [0.0, 1.0],
      [0.0, 1.0, 1.0, 2.0], [0.5, 1.5], width = 2)
    check spec.layers.len == 1
    check spec.layers[0].mark == mkLine
    check spec.layers[0].missingValues == BreakOnMissing
    check spec.data.numeric("x").len == 6
    check spec.data.numeric("x")[2].isNaN
    check spec.data.numeric("x")[5].isNaN
    discard spec.compileScene()
    expect PlotError:
      discard contourPlot([0.0, 1.0], [0.0, 1.0],
        [0.0, 1.0, 1.0, 2.0], [3.0])
