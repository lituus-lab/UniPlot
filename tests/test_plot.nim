# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[sequtils, unittest]
when not defined(release) and not defined(danger):
  import contracts
import UniColor
import UniImage/core as uimg
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

  test "raster layers snapshot pixels and compile behind data marks":
    var spec = sample()
    var image = uimg.newImage[uint8](2, 1, uimg.csRgba)
    image.data = @[255'u8, 0, 0, 255, 0, 0, 255, 128]
    spec.raster(image, 0.0, 2.0, 1.0, 3.0, RasterNearest)
    image.data[0] = 0
    check spec.rasters[0].image.data[0] == 255
    let scene = spec.compileScene(Size(width: 320, height: 240))
    var rasterIndex = -1
    var firstDataIndex = -1
    for index, node in scene.nodes:
      if node.kind == snImage: rasterIndex = index
      elif node.id != 0 and firstDataIndex < 0: firstDataIndex = index
    check rasterIndex >= 0
    check firstDataIndex > rasterIndex
    check scene.nodes[rasterIndex].image.data[0] == 255

    var rasterOnly = plot(initDataFrame())
    rasterOnly.raster(image, 0.0, 2.0, 0.0, 1.0, RasterNearest)
    check rasterOnly.compileScene(Size(width: 320, height: 240)).nodes.anyIt(
      it.kind == snImage)

  test "raster contracts reject malformed pixels and extents":
    var spec = sample()
    var malformed = uimg.newImage[uint8](1, 1, uimg.csRgba)
    malformed.data.setLen(3)
    when defined(release) or defined(danger):
      expect PlotError: spec.raster(malformed, 0, 1, 0, 1)
      expect PlotError:
        var valid = uimg.newImage[uint8](1, 1, uimg.csRgba)
        spec.raster(valid, 1, 0, 0, 1)
    else:
      expect PreConditionDefect: spec.raster(malformed, 0, 1, 0, 1)

  test "raster pixels follow reversed axes and reject nonlinear warps":
    var image = uimg.newImage[uint8](2, 2, uimg.csRgba)
    image.data = @[
      255'u8, 0, 0, 255, 0, 255, 0, 255,
      0, 0, 255, 255, 255, 255, 0, 255]
    proc imagePixels(reverseX, reverseY: bool): seq[uint8] =
      var spec = plot(initDataFrame())
      spec.raster(image, 0, 2, 0, 2, RasterNearest)
      spec.scaleX(reversed = reverseX)
      spec.scaleY(reversed = reverseY)
      for node in spec.compileScene(Size(width: 320, height: 240)).nodes:
        if node.kind == snImage: return node.image.data
    check imagePixels(false, false)[0 .. 3] == @[255'u8, 0, 0, 255]
    check imagePixels(true, false)[0 .. 3] == @[0'u8, 255, 0, 255]
    check imagePixels(false, true)[0 .. 3] == @[0'u8, 0, 255, 255]
    var logarithmic = plot(initDataFrame())
    logarithmic.raster(image, 1, 100, 1, 100)
    logarithmic.scaleX(skLog10)
    expect PlotError: discard logarithmic.compileScene()

  test "data-mapped image marks resolve owned resources in row order":
    var frame = initDataFrame()
    frame.addColumn("left", [0.0, 1.0, 99.0])
    frame.addColumn("right", [1.0, 2.0, 100.0])
    frame.addColumn("bottom", [0.0, 0.0, NaN])
    frame.addColumn("top", [1.0, 1.0, 1.0])
    frame.addColumn("resource", ["red", "blue", "red"])
    var red = uimg.newImage[uint8](1, 1, uimg.csRgba)
    red.data = @[255'u8, 0, 0, 255]
    var blue = uimg.newImage[uint8](1, 1, uimg.csRgba)
    blue.data = @[0'u8, 0, 255, 255]
    var spec = plot(frame)
    spec.addImageResource("red", red)
    spec.addImageResource("blue", blue)
    spec.geomImage(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top", image = "resource"), RasterNearest)
    red.data[0] = 0
    let scene = spec.compileScene(Size(width: 320, height: 240))
    let images = scene.nodes.filterIt(it.kind == snImage)
    check images.len == 2
    check images[0].image.data[0 .. 3] == @[255'u8, 0, 0, 255]
    check images[1].image.data[0 .. 3] == @[0'u8, 0, 255, 255]
    spec.xLimits(0, 2)
    spec.yLimits(0, 1)
    check spec.compileScene(Size(width: 320, height: 240)).nodes.countIt(
      it.kind == snImage) == 2

  test "image mark contracts reject invalid registries and references":
    var frame = initDataFrame()
    frame.addColumn("left", [0.0])
    frame.addColumn("right", [1.0])
    frame.addColumn("bottom", [0.0])
    frame.addColumn("top", [1.0])
    frame.addColumn("resource", ["missing"])
    var image = uimg.newImage[uint8](1, 1, uimg.csRgba)
    var spec = plot(frame)
    spec.addImageResource("known", image)
    when defined(release) or defined(danger):
      expect PlotError: spec.addImageResource("", image)
    else:
      expect PreConditionDefect: spec.addImageResource("", image)
    expect PlotError: spec.addImageResource("known", image)
    spec.geomImage(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top", image = "resource"))
    expect PlotError: discard spec.compileScene()
    var validFrame = initDataFrame()
    validFrame.addColumn("left", [1.0])
    validFrame.addColumn("right", [2.0])
    validFrame.addColumn("bottom", [1.0])
    validFrame.addColumn("top", [2.0])
    validFrame.addColumn("resource", ["known"])
    var logarithmic = plot(validFrame)
    logarithmic.addImageResource("known", image)
    logarithmic.geomImage(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top", image = "resource"))
    logarithmic.scaleY(skLog10)
    expect PlotError: discard logarithmic.compileScene()

  test "an empty specification is rejected":
    var frame = initDataFrame()
    frame.addColumn("x", [1.0])
    expect PlotError: discard plot(frame).compileScene()

  test "categorical bars compile with a zero baseline":
    let spec = barPlot(["A", "B", "C"], [2.0, 5.0, 3.0])
    let scene = spec.compileScene()
    check scene.nodes.len > 10

  test "numeric rectangles use explicit ordered data bounds":
    var frame = initDataFrame()
    frame.addColumn("left", [0.0, 2.0, 4.0])
    frame.addColumn("right", [1.0, 3.5, 5.0])
    frame.addColumn("bottom", [0.0, 1.0, NaN])
    frame.addColumn("top", [2.0, 1.0, 6.0])
    frame.addColumn("intensity", [1.0, 2.0, 3.0])
    var spec = plot(frame)
    spec.geomRect(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top", fill = "intensity"))
    let scene = spec.compileScene()
    var rectangles = 0
    var rectangleColors: seq[Color]
    for node in scene.nodes:
      if node.kind == snPath and node.id != 0:
        inc rectangles
        rectangleColors.add node.color
    check rectangles == 2
    check rectangleColors[0] != rectangleColors[1]

    var inverted = frame
    inverted.addColumn("badRight", [-1.0, 3.5, 5.0])
    var invalid = plot(inverted)
    invalid.geomRect(aes("", "", xMin = "left", xMax = "badRight",
      yMin = "bottom", yMax = "top"))
    expect PlotError: discard invalid.compileScene()

    var rejected = plot(frame)
    rejected.geomRect(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top"), missingValues = RejectMissing)
    expect PlotError: discard rejected.compileScene()

  test "numeric axes support logarithmic transforms and reversal":
    var frame = initDataFrame()
    frame.addColumn("x", [1.0, 10.0, 100.0])
    frame.addColumn("y", [1.0, 10.0, 100.0])
    frame.addColumn("label", ["one", "ten", "hundred"])
    var spec = plot(frame)
    spec.geomText(aes("x", "y", label = "label"))
    spec.scaleX(skLog10, reversed = true)
    spec.scaleY(skLog10, reversed = true)
    let scene = spec.compileScene()
    var positions: seq[Point]
    for node in scene.nodes:
      if node.id != 0:
        positions.add node.position
    check positions.len == 3
    check positions[0].x > positions[1].x
    check positions[1].x > positions[2].x
    check positions[0].y < positions[1].y
    check positions[1].y < positions[2].y
    check abs((positions[0].x - positions[1].x) -
      (positions[1].x - positions[2].x)) < 0.01

  test "explicit numeric limits are strict and safe":
    var spec = sample()
    spec.xLimits(-1.0, 4.0)
    spec.yLimits(0.0, 5.0)
    check spec.compileScene().nodes.len > 0
    spec.scaleX(reversed = true)
    check spec.xScaleSpec.domain.configured
    expect PlotError:
      var outside = sample()
      outside.xLimits(0.5, 3.0)
      discard outside.compileScene()
    expect PlotError:
      var categorical = barPlot(["a", "b"], [1.0, 2.0])
      categorical.xLimits(0.0, 2.0)
      discard categorical.compileScene()
    expect PlotError:
      var logarithmic = sample()
      logarithmic.scaleX(skLog10)
      logarithmic.xLimits(-1.0, 4.0)
      discard logarithmic.compileScene()
    spec.clearXLimits()
    spec.clearYLimits()
    check not spec.xScaleSpec.domain.configured
    check not spec.yScaleSpec.domain.configured
    when defined(release):
      expect PlotError: spec.xLimits(1.0, 1.0)
      expect PlotError: spec.yLimits(NaN, 1.0)
    else:
      expect PreConditionDefect: spec.xLimits(1.0, 1.0)
      expect PreConditionDefect: spec.yLimits(NaN, 1.0)

  test "explicit categorical x domains are strict and ordered":
    var spec = barPlot(["b", "a"], [2.0, 1.0])
    spec.xCategories(["c", "a", "b"])
    check spec.compileScene().nodes.len > 0
    spec.xLimits(0.0, 1.0)
    check not spec.xScaleSpec.categories.configured
    spec.xCategories(["a", "b"])
    check not spec.xScaleSpec.domain.configured
    expect PlotError:
      var missing = barPlot(["b", "a"], [2.0, 1.0])
      missing.xCategories(["a"])
      discard missing.compileScene()
    expect PlotError:
      var numeric = sample()
      numeric.xCategories(["a", "b"])
      discard numeric.compileScene()
    expect PlotError: spec.xCategories(["a", "a"])
    spec.clearXCategories()
    check not spec.xScaleSpec.categories.configured

  test "secondary y guides are affine views of primary ticks":
    var spec = sample()
    spec.secondaryY(scale = 10.0, offset = 2.0, label = "converted")
    let scene = spec.compileScene()
    var
      foundLabel = false
      foundTick = false
    for node in scene.nodes:
      if node.kind == snText:
        foundLabel = foundLabel or node.text == "converted"
        foundTick = foundTick or node.text == tickLabel(12)
    check foundLabel
    check foundTick
    var withLegend = sample()
    withLegend.layers[0].legendLabel = "series"
    withLegend.legend()
    withLegend.secondaryY(label = "converted")
    let combined = withLegend.compileScene()
    var secondaryX, legendX = -1'f32
    for node in combined.nodes:
      if node.kind == snText:
        if node.text == "converted": secondaryX = node.position.x
        if node.text == "series": legendX = node.position.x
    check secondaryX >= 0
    check legendX > secondaryX
    expect PlotError:
      var overflow = sample()
      overflow.secondaryY(scale = 1e308)
      discard overflow.compileScene()
    spec.clearSecondaryY()
    check not spec.secondaryYSpec.enabled
    when defined(release):
      expect PlotError: spec.secondaryY(scale = 0.0)
      expect PlotError: spec.secondaryY(offset = Inf)
    else:
      expect PreConditionDefect: spec.secondaryY(scale = 0.0)
      expect PreConditionDefect: spec.secondaryY(offset = Inf)

  test "incompatible transformed coordinates fail explicitly":
    var categorical = barPlot(["a", "b"], [1.0, 2.0])
    categorical.scaleX(skLog10)
    expect PlotError: discard categorical.compileScene()
    var logBars = barPlot(["a", "b"], [1.0, 2.0])
    logBars.scaleY(skLog10)
    expect PlotError: discard logBars.compileScene()

  test "reference lines and bands compile through numeric scales":
    var spec = sample()
    spec.referenceX(1.0, label = "event")
    spec.referenceY(2.0, width = 2)
    spec.referenceXBand(0.25, 0.75)
    spec.referenceYBand(1.5, 2.5, label = "target")
    check spec.references.len == 4
    spec.referenceX(10.0)
    let scene = spec.compileScene()
    var referenceLabels = 0
    for node in scene.nodes:
      if node.kind == snText and node.text in ["event", "target"]:
        inc referenceLabels
    check referenceLabels == 2

  test "plain text and arrows compile through retained annotations":
    var spec = sample()
    spec.annotateText(1.0, 3.5, "peak", color = "#7a3db8", fontSize = 14)
    spec.annotateArrow(0.5, 1.5, 1.0, 3.0, color = "#d65f2d",
      width = 2, headSize = 10)
    let scene = spec.compileScene()
    var foundText = false
    for node in scene.nodes:
      if node.kind == snText and node.text == "peak": foundText = true
    check foundText
    spec.clearAnnotations()
    check spec.annotations.len == 0
    expect PlotError:
      var categorical = barPlot(["a", "b"], [1.0, 2.0])
      categorical.annotateText(0.0, 1.0, "invalid")
      discard categorical.compileScene()
    when defined(release):
      expect PlotError: spec.annotateText(NaN, 1.0, "bad")
      expect PlotError: spec.annotateText(1.0, 1.0, "")
      expect PlotError: spec.annotateArrow(1.0, 1.0, 1.0, 1.0)
    else:
      expect PreConditionDefect: spec.annotateText(NaN, 1.0, "bad")
      expect PreConditionDefect: spec.annotateText(1.0, 1.0, "")
      expect PreConditionDefect: spec.annotateArrow(1.0, 1.0, 1.0, 1.0)

  test "box plots reject unordered precomputed statistics":
    var frame = initDataFrame()
    frame.addColumn("group", ["a"])
    frame.addColumn("median", [2.0])
    frame.addColumn("q1", [3.0])
    frame.addColumn("q3", [4.0])
    frame.addColumn("lower", [1.0])
    frame.addColumn("upper", [5.0])
    var spec = plot(frame)
    spec.geomBoxPlot(aes("group", "median", yMin = "lower", yMax = "upper",
      yQ1 = "q1", yQ3 = "q3"))
    expect PlotError: discard spec.compileScene()

  test "categorical heatmaps preserve both band axes and absent cells":
    var spec = heatmapPlot(
      ["left", "right", "left"], ["north", "north", "south"],
      [1.0, 4.0, NaN])
    check spec.layers.len == 1
    check spec.layers[0].mark == mkTile
    check spec.data.rowCount == 4
    check spec.legendSpec.visible
    check not heatmapPlot(["x"], ["y"], [1.0], legend = "").legendSpec.visible
    spec.yCategories(["south", "north", "reserved"])
    let scene = spec.compileScene()
    var
      foundSouth, foundReserved, foundGuide = false
      paintedTiles = 0
    for node in scene.nodes:
      if node.kind == snText and node.text == "south": foundSouth = true
      if node.kind == snText and node.text == "reserved": foundReserved = true
      if node.kind == snText and node.text == "value": foundGuide = true
      if node.kind == snPath and node.id != 0: inc paintedTiles
    check foundSouth and foundReserved and foundGuide
    check paintedTiles == 2
    spec.clearYCategories()
    check not spec.yScaleSpec.categories.configured
    var numeric = linePlot([0.0, 1.0], [1.0, 2.0])
    numeric.geomTile(aes("x", "y"))
    expect PlotError: discard numeric.compileScene()
    var categoricalFrame = initDataFrame()
    categoricalFrame.addColumn("x", ["a"])
    categoricalFrame.addColumn("y", ["b"])
    var categorical = plot(categoricalFrame)
    categorical.geomPoint(aes("x", "y"))
    expect PlotError: discard categorical.compileScene()

  test "references reject invalid values and categorical x coordinates":
    var spec = sample()
    when defined(release):
      expect PlotError: spec.referenceX(NaN)
      expect PlotError: spec.referenceY(1.0, width = 0)
      expect PlotError: spec.referenceXBand(2.0, 1.0)
      expect PlotError: spec.referenceYBand(1.0, 1.0)
    else:
      expect PreConditionDefect: spec.referenceX(NaN)
      expect PreConditionDefect: spec.referenceY(1.0, width = 0)
      expect PreConditionDefect: spec.referenceXBand(2.0, 1.0)
      expect PreConditionDefect: spec.referenceYBand(1.0, 1.0)
    var categorical = barPlot(["a", "b"], [1.0, 2.0])
    categorical.referenceX(1.0)
    expect PlotError: discard categorical.compileScene()
    var direct = sample()
    direct.references.add Reference(kind: rkYBand, minimum: 2, maximum: 1,
      color: parseColor("#ffffff").get, width: 1)
    expect PlotError: discard direct.compileScene()

  test "error bars and ribbons use explicit uncertainty bounds":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("lower", [0.5, 1.5, 1.0])
    frame.addColumn("upper", [1.5, 3.0, 2.5])
    var spec = plot(frame)
    let uncertainty = aes("x", "", yMin = "lower", yMax = "upper")
    spec.geomRibbon(uncertainty)
    spec.geomErrorBar(uncertainty, capWidth = 10)
    let scene = spec.compileScene()
    var markNodes = 0
    for node in scene.nodes:
      if node.id != 0:
        inc markNodes
    check markNodes == 4

  test "ribbons preserve gaps and reject inverted bounds":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0])
    frame.addColumn("lower", [0.0, 0.5, NaN, 1.0, 1.5])
    frame.addColumn("upper", [1.0, 1.5, NaN, 2.0, 2.5])
    var ribbon = plot(frame)
    ribbon.geomRibbon(aes("x", "", yMin = "lower", yMax = "upper"))
    let scene = ribbon.compileScene()
    var ribbonNodes = 0
    for node in scene.nodes:
      if node.id != 0:
        inc ribbonNodes
    check ribbonNodes == 2

    var invertedFrame = initDataFrame()
    invertedFrame.addColumn("x", [0.0])
    invertedFrame.addColumn("lower", [2.0])
    invertedFrame.addColumn("upper", [1.0])
    var inverted = plot(invertedFrame)
    inverted.geomErrorBar(aes("x", "", yMin = "lower", yMax = "upper"))
    expect PlotError: discard inverted.compileScene()

  test "uncertainty constructors enforce their contracts":
    var spec = sample()
    expect PlotError: spec.geomRibbon(aes("x", ""))
    when defined(release):
      expect PlotError:
        spec.geomErrorBar(aes("x", "", yMin = "y", yMax = "y"),
          capWidth = -1)
    else:
      expect PreConditionDefect:
        spec.geomErrorBar(aes("x", "", yMin = "y", yMax = "y"),
          capWidth = -1)
    var direct = sample()
    direct.geomErrorBar(aes("x", "", yMin = "y", yMax = "y"))
    direct.layers[^1].capWidth = NaN.float32
    expect PlotError: discard direct.compileScene()

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

  test "themes derive reusable validated style values":
    let base = darkTheme()
    let derived = base.deriveTheme(gridColor = "#555b62", lineWidth = 3)
    check derived.background == base.background
    check derived.gridColor != base.gridColor
    check derived.lineWidth == 3
    check base.withMargins(Insets()).margins == Insets()
    var first = sample()
    var second = sample()
    first.applyTheme(derived)
    second.applyTheme(derived)
    check first.compileScene().background == second.compileScene().background
    when defined(release):
      expect PlotError: discard base.deriveTheme(lineWidth = -1)
    else:
      expect PreConditionDefect: discard base.deriveTheme(lineWidth = -1)

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
