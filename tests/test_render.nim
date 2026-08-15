# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[unittest, strutils]
import contracts
import UniGlyph
from UniVector import lineTo
import UniPlot

suite "rendering":
  test "SVG and PNG render from the same scene":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 3.0, 2.0])
    var spec = plot(frame)
    spec.geomLine(aes("x", "y"))
    spec.labels(title = "Plot")
    let scene = spec.compileScene(Size(width: 320, height: 240))
    let font = loadTtf("tests/DejaVuSans.ttf")
    let svg = scene.toSvg(font)
    let png = scene.encodePng(font)
    check svg.startsWith("<svg")
    check "data-uplot-id" in svg
    check png.len > 8
    check png[0 .. 3] == @[137'u8, 80, 78, 71]

  test "scene and render boundaries reject invalid values":
    let white = defaultTheme().background
    when defined(release):
      expect PlotError: discard initScene(Size(width: 0, height: 10), white)
    else:
      expect PreConditionDefect:
        discard initScene(Size(width: 0, height: 10), white)
    var scene = initScene(Size(width: 10, height: 10), white)
    when defined(release):
      expect PlotError:
        scene.addText("x", Point(x: NaN, y: 1), 12, white)
    else:
      expect PreConditionDefect:
        scene.addText("x", Point(x: NaN, y: 1), 12, white)
    expect PlotError: discard scene.toSvg(nil)
    expect PlotError: discard scene.renderImage(nil)

  test "prepared CPU scenes preserve exact SVG and PNG output":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [1.0, 3.0, 2.0])
    var spec = plot(frame)
    spec.geomLine(aes("x", "y"))
    spec.geomPoint(aes("x", "y"), radius = 4)
    spec.labels(title = "Prepared")
    var scene = spec.compileScene(Size(width: 320, height: 240))
    let
      font = loadTtf("tests/DejaVuSans.ttf")
      prepared = scene.prepareScene(font)
    check prepared.size == scene.size
    check prepared.toSvg == scene.toSvg(font)
    check prepared.encodePng == scene.encodePng(font)
    check prepared.toSvg == prepared.toSvg
    check prepared.encodePng == prepared.encodePng
    let stableSvg = prepared.toSvg
    scene.nodes[0].path.lineTo(319, 239)
    check prepared.toSvg == stableSvg
    expect PlotError: discard scene.prepareScene(nil)
    let absent: PreparedScene = nil
    when defined(release):
      expect PlotError: discard absent.size
    else:
      expect PreConditionDefect: discard absent.size
    expect PlotError: discard absent.toSvg
    expect PlotError: discard absent.renderImage
