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
