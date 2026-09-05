# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import contracts
import UniColor
import UniVector
import UniPlot

proc sampleSpec(color: string): PlotSpec =
  result = linePlot([0.0, 1.0, 2.0], [0.0, 1.0, 0.5], color = color)
  result.labels(title = "panel", x = "x", y = "y")

suite "plot composition":
  test "compile plots into a deterministic row-major grid":
    let
      first = sampleSpec("#3366cc")
      second = sampleSpec("#cc6633")
      panelSize = Size(width: 400, height: 300)
      firstScene = first.compileScene(panelSize)
      secondScene = second.compileScene(panelSize)
      grid = compileGrid([first, second], 2,
        Size(width: 816, height: 300), gap = 16)
    check grid.size == Size(width: 816, height: 300)
    check grid.nodes.len == firstScene.nodes.len + secondScene.nodes.len + 2
    check grid.nodes[0].kind == snPath
    check $grid.nodes[0].path == $parsePath("M 0 0 L 400 0 L 400 300 " &
      "L 0 300 Z")
    let secondBackground = firstScene.nodes.len + 1
    check $grid.nodes[secondBackground].path == $parsePath(
      "M 416 0 L 816 0 L 816 300 L 416 300 Z")

    for index, source in firstScene.nodes:
      let composed = grid.nodes[index + 1]
      check composed.kind == source.kind
      case source.kind
      of snPath:
        check $composed.path == $source.path
      of snText:
        check composed.position == source.position
      of snImage:
        check composed.imageX == source.imageX
        check composed.imageY == source.imageY

    var comparedStableId = false
    for index, source in secondScene.nodes:
      let composed = grid.nodes[secondBackground + index + 1]
      check composed.kind == source.kind
      case source.kind
      of snPath:
        check $composed.path == $source.path.translated(416'f32, 0'f32)
      of snText:
        check composed.position == Point(x: source.position.x + 416'f32,
          y: source.position.y)
      of snImage:
        check composed.imageX == source.imageX + 416
        check composed.imageY == source.imageY
      if source.id != 0:
        check composed.id != source.id
        comparedStableId = true
    check comparedStableId
    let repeated = compileGrid([first, second], 2,
      Size(width: 816, height: 300), gap = 16)
    check repeated.nodes.len == grid.nodes.len
    for index in 0 ..< grid.nodes.len:
      check repeated.nodes[index].id == grid.nodes[index].id

  test "preserve each panel background":
    var first = sampleSpec("#3366cc")
    var second = sampleSpec("#cc6633")
    first.applyTheme(first.theme.deriveTheme(background = "#ffffff"))
    second.applyTheme(second.theme.deriveTheme(background = "#17191c"))
    let grid = compileGrid([first, second], 1,
      Size(width: 400, height: 616), gap = 16)
    check grid.nodes[0].color == first.theme.background
    let secondBackground = first.compileScene(Size(width: 400,
      height: 300)).nodes.len + 1
    check grid.nodes[secondBackground].color == second.theme.background

  test "distribute remainder pixels without leaving an unused edge":
    let spec = sampleSpec("#3366cc")
    let grid = compileGrid([spec, spec], 2,
      Size(width: 817, height: 301), gap = 16)
    let secondBackground = spec.compileScene(
      Size(width: 401, height: 301)).nodes.len + 1
    check $grid.nodes[0].path == $parsePath(
      "M 0 0 L 401 0 L 401 301 L 0 301 Z")
    check $grid.nodes[secondBackground].path == $parsePath(
      "M 417 0 L 817 0 L 817 301 L 417 301 Z")

  test "share numeric domains without mutating source specifications":
    var
      first = linePlot([0.0, 1.0], [10.0, 20.0])
      second = linePlot([2.0, 4.0], [-5.0, 5.0])
      expectedFirst = first
      expectedSecond = second
    expectedFirst.xLimits(0.0, 4.0)
    expectedSecond.xLimits(0.0, 4.0)
    expectedFirst.yLimits(-5.0, 20.0)
    expectedSecond.yLimits(-5.0, 20.0)
    let
      shared = compileGrid([first, second], 2,
        Size(width: 816, height: 300), sharedX = true, sharedY = true)
      expected = compileGrid([expectedFirst, expectedSecond], 2,
        Size(width: 816, height: 300))
    check not first.xScaleSpec.domain.configured
    check not second.yScaleSpec.domain.configured
    check shared.nodes.len == expected.nodes.len
    for index in 0 ..< shared.nodes.len:
      check shared.nodes[index].kind == expected.nodes[index].kind
      case shared.nodes[index].kind
      of snPath:
        check $shared.nodes[index].path == $expected.nodes[index].path
      of snText:
        check shared.nodes[index].text == expected.nodes[index].text
        check shared.nodes[index].position == expected.nodes[index].position
      of snImage:
        check shared.nodes[index].image.data == expected.nodes[index].image.data

  test "shared numeric domains reject incompatible axes":
    let
      numeric = sampleSpec("#3366cc")
      categorical = barPlot(["a", "b"], [1.0, 2.0])
    expect PlotError:
      discard compileGrid([numeric, categorical], 2, sharedX = true)
    var logarithmic = sampleSpec("#cc6633")
    logarithmic.scaleY(skLog10)
    expect PlotError:
      discard compileGrid([numeric, logarithmic], 2, sharedY = true)
    var clipped = numeric
    clipped.xLimits(0.5, 2.0)
    expect PlotError:
      discard compileGrid([clipped, numeric], 2, sharedX = true)
    var firstUtc = numeric
    var secondUtc = numeric
    firstUtc.scaleXUtc()
    secondUtc.scaleXUtc()
    check compileGrid([firstUtc, secondUtc], 2, sharedX = true).nodes.len > 0
    secondUtc.scaleXDuration()
    expect PlotError:
      discard compileGrid([firstUtc, secondUtc], 2, sharedX = true)

  test "share categorical x domains in first-seen panel order":
    let
      first = barPlot(["b", "a"], [2.0, 1.0])
      second = barPlot(["c", "b"], [3.0, 2.0])
    var expectedFirst = first
    var expectedSecond = second
    expectedFirst.xCategories(["b", "a", "c"])
    expectedSecond.xCategories(["b", "a", "c"])
    let
      shared = compileGrid([first, second], 2,
        Size(width: 816, height: 300), sharedX = true)
      expected = compileGrid([expectedFirst, expectedSecond], 2,
        Size(width: 816, height: 300))
    check shared.nodes.len == expected.nodes.len
    for index in 0 ..< shared.nodes.len:
      check shared.nodes[index].kind == expected.nodes[index].kind
      case shared.nodes[index].kind
      of snPath: check $shared.nodes[index].path == $expected.nodes[index].path
      of snText:
        check shared.nodes[index].text == expected.nodes[index].text
        check shared.nodes[index].position == expected.nodes[index].position
      of snImage:
        check shared.nodes[index].image.data == expected.nodes[index].image.data

  test "share categorical y domains in first-seen panel order":
    let
      first = heatmapPlot(["x", "x"], ["north", "south"], [1.0, 2.0])
      second = heatmapPlot(["x", "x"], ["east", "north"], [3.0, 4.0])
    var expectedFirst = first
    var expectedSecond = second
    expectedFirst.yCategories(["north", "south", "east"])
    expectedSecond.yCategories(["north", "south", "east"])
    let
      shared = compileGrid([first, second], 2,
        Size(width: 816, height: 300), sharedY = true)
      expected = compileGrid([expectedFirst, expectedSecond], 2,
        Size(width: 816, height: 300))
    check shared.nodes.len == expected.nodes.len
    for index in 0 ..< shared.nodes.len:
      check shared.nodes[index].kind == expected.nodes[index].kind
      case shared.nodes[index].kind
      of snPath: check $shared.nodes[index].path == $expected.nodes[index].path
      of snText:
        check shared.nodes[index].text == expected.nodes[index].text
        check shared.nodes[index].position == expected.nodes[index].position
      of snImage:
        check shared.nodes[index].image.data == expected.nodes[index].image.data

  test "facet specifications retain category order and complete semantics":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0, 3.0])
    frame.addColumn("y", [2.0, 4.0, 3.0, 8.0])
    frame.addColumn("group", ["west", "east", "west", "east"])
    var spec = plot(frame)
    spec.geomLine(aes("x", "y"))
    spec.labels(title = "Measurements", x = "time", y = "value")
    let facets = spec.facetSpecs("group")
    check facets.len == 2
    check facets[0].data.categorical("group") == @["west", "west"]
    check facets[0].data.numeric("x") == @[0.0, 2.0]
    check facets[1].data.categorical("group") == @["east", "east"]
    check facets[0].title == "Measurements — group = west"
    check facets[1].title == "Measurements — group = east"
    check spec.data.rowCount == 4
    check compileFacetGrid(spec, "group", 2, sharedX = true,
      sharedY = true).nodes.len > 0

  test "faceting rejects absent, numeric and empty categories":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0])
    frame.addColumn("y", [1.0, 2.0])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y"))
    expect PlotError: discard spec.facetSpecs("missing")
    expect PlotError: discard spec.facetSpecs("x")
    var empty = initDataFrame()
    empty.addColumn("x", newSeq[float64]())
    empty.addColumn("y", newSeq[float64]())
    empty.addColumn("group", newSeq[string]())
    var emptySpec = plot(empty)
    emptySpec.geomPoint(aes("x", "y"))
    expect PlotError: discard emptySpec.facetSpecs("group")
    when defined(release):
      expect PlotError: discard spec.facetSpecs("")
    else:
      expect PreConditionDefect: discard spec.facetSpecs("")

  test "two-dimensional facets preserve empty Cartesian cells":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 2.0, 3.0])
    frame.addColumn("row", ["north", "north", "south"])
    frame.addColumn("column", ["left", "right", "right"])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y"))
    spec.labels(title = "Matrix")
    let cells = spec.facetCells("row", "column")
    check cells.len == 4
    check cells[0].rowValue == "north"
    check cells[0].columnValue == "left"
    check cells[0].rows == @[0]
    check cells[1].rows == @[1]
    check cells[2].rowValue == "south"
    check cells[2].columnValue == "left"
    check cells[2].rows.len == 0
    check cells[3].rows == @[2]
    let scene = spec.compileFacetMatrix("row", "column",
      Size(width: 816, height: 400), gap = 16, sharedX = true,
      sharedY = true)
    var foundEmptyTitle = false
    for node in scene.nodes:
      if node.kind == snText and node.text ==
          "Matrix — row = south — column = left":
        check node.position == Point(x: 70, y: 233)
        foundEmptyTitle = true
    check foundEmptyTitle

  test "two-dimensional facets reject invalid dimensions":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0])
    frame.addColumn("y", [1.0])
    frame.addColumn("group", ["a"])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y"))
    expect PlotError: discard spec.facetCells("missing", "group")
    expect PlotError: discard spec.facetCells("x", "group")
    when defined(release):
      expect PlotError: discard spec.facetCells("group", "group")
    else:
      expect PreConditionDefect: discard spec.facetCells("group", "group")

  test "reject invalid grid dimensions in every build mode":
    let spec = sampleSpec("#3366cc")
    when not defined(release):
      expect PreConditionDefect:
        discard compileGrid([spec], 0)
      expect PreConditionDefect:
        discard compileGrid([spec], 1, gap = -1)
    else:
      expect PlotError:
        discard compileGrid([spec], 0)
      expect PlotError:
        discard compileGrid([spec], 1, gap = -1)
    expect PlotError:
      discard compileGrid([spec, spec], 2,
        Size(width: 1, height: 100), gap = 1)

  test "independent grids may mix coordinates but shared axes may not":
    let cartesian = sampleSpec("#3366cc")
    var polar = sampleSpec("#d1495b")
    polar.coordPolar()
    check compileGrid([cartesian, polar], 2,
      Size(width: 800, height: 400)).nodes.len > 0
    expect PlotError:
      discard compileGrid([cartesian, polar], 2,
        Size(width: 800, height: 400), sharedX = true)
