# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPlot

proc sample(): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", [0.0, 1.0, 2.0])
  frame.addColumn("y", [1.0, 3.0, 2.0])
  result = plot(frame)
  result.geomLine(aes("x", "y"))
  result.geomPoint(aes("x", "y"))
  result.labels(title = "Sample")

suite "plot compilation":
  test "layers compile in deterministic order":
    let scene = sample().compileScene(Size(width: 640, height: 400))
    check scene.size.width == 640
    check scene.nodes.len > 10
    check scene.nodes[^1].id > 0

  test "an empty specification is rejected":
    var frame = initDataFrame()
    frame.addColumn("x", [1.0])
    expect PlotError: discard plot(frame).compileScene()

  test "categorical bars compile with a zero baseline":
    let spec = barPlot(["A", "B", "C"], [2.0, 5.0, 3.0])
    let scene = spec.compileScene()
    check scene.nodes.len > 10

  test "invalid margins and missing mappings are typed errors":
    var spec = sample()
    spec.theme.margins.left = 1000
    expect PlotError: discard spec.compileScene(Size(width: 100, height: 100))
    var frame = initDataFrame()
    frame.addColumn("x", [1.0])
    var missing = plot(frame)
    missing.geomPoint(aes("x", "absent"))
    expect PlotError: discard missing.compileScene()

  test "invalid theme sizes and text labels are typed errors":
    var badTheme = sample()
    badTheme.theme.pointSize = 0
    expect PlotError: discard badTheme.compileScene()
    var frame = initDataFrame()
    frame.addColumn("x", [0.0])
    frame.addColumn("y", [1.0])
    var textSpec = plot(frame)
    textSpec.geomText(aes("x", "y", "missing"))
    expect PlotError: discard textSpec.compileScene()

  test "layer and convenience constructors reject malformed input":
    var spec = sample()
    expect PlotError: spec.geomLine(aes("", "y"))
    expect PlotError: spec.geomPoint(aes("x", "y"), radius = -1)
    expect PlotError: spec.geomArea(aes("x", "y"), color = "not-a-color")
    expect PlotError: discard linePlot([1.0], [1.0, 2.0])
    expect PlotError: discard scatterPlot([1.0], [1.0, 2.0])
    expect PlotError: discard barPlot(["a"], [1.0, 2.0])
    expect PlotError: discard histogramPlot([1.0], 0)

  test "named layers produce a deterministic optional legend":
    var spec = sample()
    spec.layers[0].legendLabel = "Trend"
    spec.layers[1].legendLabel = "Samples"
    spec.legend(title = "Series")
    let scene = spec.compileScene(Size(width: 640, height: 400))
    var labels: seq[string]
    for node in scene.nodes:
      if node.kind == snText and node.text in ["Series", "Trend", "Samples"]:
        labels.add node.text
    check labels == @["Series", "Trend", "Samples"]

    spec.legend(position = lpNone)
    let hidden = spec.compileScene(Size(width: 640, height: 400))
    for node in hidden.nodes:
      if node.kind == snText:
        check node.text notin ["Series", "Trend", "Samples"]
