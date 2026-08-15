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

  test "missing-value policies are explicit layer semantics":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0])
    frame.addColumn("y", [1.0, 2.0])
    var spec = plot(frame)
    spec.geomLine(aes("x", "y"))
    spec.geomArea(aes("x", "y"))
    spec.geomPoint(aes("x", "y"), missingValues = RejectMissing)
    check spec.layers[0].missingValues == BreakOnMissing
    check spec.layers[1].missingValues == BreakOnMissing
    check spec.layers[2].missingValues == RejectMissing

  test "missing values break lines and areas without joining gaps":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0])
    frame.addColumn("y", [0.0, 1.0, NaN, 1.0, 0.0])

    var brokenLine = plot(frame)
    brokenLine.geomLine(aes("x", "y"))
    let brokenLineScene = brokenLine.compileScene()
    var brokenLineNodes = 0
    for node in brokenLineScene.nodes:
      if node.id != 0: inc brokenLineNodes
    check brokenLineNodes == 2

    var droppedLine = plot(frame)
    droppedLine.geomLine(aes("x", "y"), missingValues = DropMissing)
    let droppedLineScene = droppedLine.compileScene()
    var droppedLineNodes = 0
    for node in droppedLineScene.nodes:
      if node.id != 0: inc droppedLineNodes
    check droppedLineNodes == 1

    var brokenArea = plot(frame)
    brokenArea.geomArea(aes("x", "y"))
    let brokenAreaScene = brokenArea.compileScene()
    var brokenAreaNodes = 0
    for node in brokenAreaScene.nodes:
      if node.id != 0: inc brokenAreaNodes
    check brokenAreaNodes == 2

  test "missing values can be dropped or rejected explicitly":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, Inf, 2.0])
    var dropped = plot(frame)
    dropped.geomPoint(aes("x", "y"))
    let droppedScene = dropped.compileScene()
    var pointNodes = 0
    for node in droppedScene.nodes:
      if node.id != 0: inc pointNodes
    check pointNodes == 2

    var rejected = plot(frame)
    rejected.geomPoint(aes("x", "y"), missingValues = RejectMissing)
    expect PlotError: discard rejected.compileScene()

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

  test "continuous palettes require ordered UniColor ramps":
    var spec = sample()
    let ramp = viridis(7)
    check ramp.isOk
    spec.continuousPalette(ramp.get)
    check spec.continuousColors.len == 7
    expect PlotError: spec.continuousPalette(okabeIto())

  test "numeric color mappings sample UniColor and derive a color bar":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 2.0, 3.0])
    frame.addColumn("temperature", [0.0, 5.0, 10.0])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y", color = "temperature"), radius = 5)
    spec.legend()
    let scene = spec.compileScene()
    var colors: seq[Color]
    var colorBarLabels = 0
    for node in scene.nodes:
      if node.id != 0: colors.add node.color
      if node.kind == snText and node.text == "temperature":
        inc colorBarLabels
    check colors.len == 3
    check colors[0] != colors[1]
    check colors[1] != colors[2]
    check colors[0] == spec.continuousColors.sample(0.0).get
    check colors[2] == spec.continuousColors.sample(1.0).get
    check colorBarLabels == 1

    spec.geomLine(aes("x", "y", color = "temperature"))
    let combined = spec.compileScene()
    var combinedColorBarLabels = 0
    for node in combined.nodes:
      if node.kind == snText and node.text == "temperature":
        inc combinedColorBarLabels
    check combinedColorBarLabels == 1

  test "numeric fill mappings support bars and missing-value filtering":
    var frame = initDataFrame()
    frame.addColumn("category", ["A", "B", "C"])
    frame.addColumn("value", [1.0, 2.0, 3.0])
    frame.addColumn("weight", [0.0, NaN, 1.0])
    var spec = plot(frame)
    spec.geomBar(aes("category", "value", fill = "weight"))
    let scene = spec.compileScene()
    var colors: seq[Color]
    for node in scene.nodes:
      if node.id != 0: colors.add node.color
    check colors.len == 2
    check colors[0] != colors[1]

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

  test "shape and line-style mappings derive semantic legends":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 2.0, 1.0])
    frame.addColumn("kind", ["A", "B", "A"])
    var shapes = plot(frame)
    shapes.geomPoint(aes("x", "y", shape = "kind"))
    shapes.legend(title = "Shape")
    let shapeScene = shapes.compileScene()
    var shapeLabels: seq[string]
    for node in shapeScene.nodes:
      if node.kind == snText and node.text in ["Shape", "A", "B"]:
        shapeLabels.add node.text
    check shapeLabels == @["Shape", "A", "B"]

    var styles = plot(frame)
    styles.geomLine(aes("x", "y", lineStyle = "kind"))
    styles.legend(title = "Style")
    let styleScene = styles.compileScene()
    var styleLabels: seq[string]
    for node in styleScene.nodes:
      if node.kind == snText and node.text in ["Style", "A", "B"]:
        styleLabels.add node.text
    check styleLabels == @["Style", "A", "B"]

  test "a shared categorical column produces one combined legend":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0])
    frame.addColumn("y", [1.0, 2.0])
    frame.addColumn("kind", ["A", "B"])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y", color = "kind", shape = "kind"))
    spec.legend()
    let scene = spec.compileScene()
    var labels: seq[string]
    for node in scene.nodes:
      if node.kind == snText and node.text in ["A", "B"]:
        labels.add node.text
    check labels == @["A", "B"]

  test "categorical fill mappings color filled marks through UniColor":
    var frame = initDataFrame()
    frame.addColumn("x", ["A", "B", "C"])
    frame.addColumn("y", [1.0, 2.0, 3.0])
    frame.addColumn("group", ["low", "high", "low"])
    var spec = plot(frame)
    spec.geomBar(aes("x", "y", fill = "group"))
    spec.legend(title = "Fill")
    let scene = spec.compileScene()
    var colors: seq[Color]
    var labels: seq[string]
    for node in scene.nodes:
      if node.id != 0: colors.add node.color
      if node.kind == snText and node.text in ["Fill", "low", "high"]:
        labels.add node.text
    check colors.len == 3
    check colors[0] == colors[2]
    check colors[0] != colors[1]
    check labels == @["Fill", "low", "high"]

    var ambiguous = plot(frame)
    ambiguous.geomPoint(aes("x", "y", color = "group", fill = "group"))
    expect PlotError: discard ambiguous.compileScene()
