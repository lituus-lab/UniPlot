# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[unittest, strutils]
import UniGlyph
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

