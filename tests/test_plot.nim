# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import contracts
import UniColor
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

  test "point shapes and line styles are explicit layer semantics":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0])
    frame.addColumn("y", [1.0, 2.0])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y", shape = "group"), shape = DiamondMarker)
    spec.geomLine(aes("x", "y", lineStyle = "series"),
      lineStyle = DotDashLine)
    check spec.layers[0].shape == DiamondMarker
    check spec.layers[0].mapping.shape == "group"
    check spec.layers[1].lineStyle == DotDashLine
    check spec.layers[1].mapping.lineStyle == "series"

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

  test "recipes forward legend labels":
    var spec = linePlot([0.0, 1.0], [1.0, 2.0], legend = "Observed")
    spec.legend()
    let scene = spec.compileScene()
    var found = false
    for node in scene.nodes:
      if node.kind == snText and node.text == "Observed": found = true
    check found

  test "categorical color mappings use UniColor and derive legend entries":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 2.0, 3.0])
    frame.addColumn("group", ["A", "B", "A"])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y", color = "group"))
    spec.legend(title = "Group")
    let scene = spec.compileScene()
    var markColors: seq[Color]
    var legendLabels: seq[string]
    for node in scene.nodes:
      if node.id != 0: markColors.add node.color
      if node.kind == snText and node.text in ["Group", "A", "B"]:
        legendLabels.add node.text
    check markColors.len == 3
    check markColors[0] == markColors[2]
    check markColors[0] != markColors[1]
    check legendLabels == @["Group", "A", "B"]

    var area = plot(frame)
    area.geomArea(aes("x", "y", color = "group"))
    expect PlotError: discard area.compileScene()

  test "numeric size and alpha mappings use explicit output ranges":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0])
    frame.addColumn("y", [1.0, 2.0])
    frame.addColumn("label", ["low", "high"])
    frame.addColumn("weight", [0.0, 10.0])
    frame.addColumn("confidence", [0.0, 1.0])
    var spec = plot(frame)
    spec.geomText(aes("x", "y", label = "label", size = "weight",
      alpha = "confidence"))
    spec.sizeRange(10, 20)
    spec.alphaRange(0.25, 1)
    let scene = spec.compileScene()
    var sizes: seq[float32]
    var alphas: seq[float32]
    for node in scene.nodes:
      if node.id != 0 and node.kind == snText:
        sizes.add node.fontSize
        alphas.add node.color.alpha
    check sizes == @[10'f32, 20'f32]
    check alphas == @[0.25'f32, 1'f32]

    when defined(release):
      expect PlotError: spec.sizeRange(0, 1)
      expect PlotError: spec.alphaRange(-0.1, 1)
    else:
      expect PreConditionDefect: spec.sizeRange(0, 1)
      expect PreConditionDefect: spec.alphaRange(-0.1, 1)

  test "shape mappings compile through UniVector marker paths":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 2.0, 3.0])
    frame.addColumn("shape", ["A", "B", "A"])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y", shape = "shape"), radius = 4)
    let scene = spec.compileScene()
    var commandCounts: seq[int]
    for node in scene.nodes:
      if node.id != 0 and node.kind == snPath:
        commandCounts.add node.path.commands.len
    check commandCounts.len == 3
    check commandCounts[0] == commandCounts[2]
    check commandCounts[0] != commandCounts[1]

  test "explicit and mapped line styles use UniVector dashes":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 2.0, 1.0])
    frame.addColumn("style", ["solid", "dash", "dot"])
    var solid = plot(frame)
    solid.geomLine(aes("x", "y"), width = 2)
    var dashed = plot(frame)
    dashed.geomLine(aes("x", "y"), width = 2, lineStyle = DashedLine)
    let solidScene = solid.compileScene()
    let dashedScene = dashed.compileScene()
    let solidCommands = solidScene.nodes[^1].path.commands.len
    let dashedCommands = dashedScene.nodes[^1].path.commands.len
    check dashedCommands > solidCommands

    var mapped = plot(frame)
    mapped.geomLine(aes("x", "y", lineStyle = "style"), width = 2)
    check mapped.compileScene().nodes[^1].id > 0

  test "shape and line-style mappings reject incompatible columns":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0])
    frame.addColumn("y", [1.0, 2.0])
    frame.addColumn("numeric", [1.0, 2.0])
    var badShape = plot(frame)
    badShape.geomPoint(aes("x", "y", shape = "numeric"))
    expect PlotError: discard badShape.compileScene()
    var badStyle = plot(frame)
    badStyle.geomPoint(aes("x", "y", lineStyle = "missing"))
    expect PlotError: discard badStyle.compileScene()
