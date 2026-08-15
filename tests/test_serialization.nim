# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, tables, unittest]
import UniColor
import UniPlot

proc completeSpec(): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", [1.0, 2.0, 3.0, 4.0])
  frame.addColumn("y", [2.0, 3.0, 4.0, 5.0])
  frame.addColumn("lower", [1.5, 2.5, 3.5, 4.5])
  frame.addColumn("upper", [2.5, 3.5, 4.5, 5.5])
  frame.addColumn("group", ["a", "b", "a", "b"])
  result = plot(frame)
  result.geomArea(aes("x", "y"), color = "#22334455")
  result.geomBar(aes("x", "y"), color = "#446688")
  result.geomRibbon(aes("x", "", yMin = "lower", yMax = "upper"))
  result.geomErrorBar(aes("x", "", yMin = "lower", yMax = "upper"),
    capWidth = 9)
  result.geomLine(aes("x", "y", lineStyle = "group"), legend = "trend")
  result.geomPoint(aes("x", "y", color = "group", shape = "group"),
    legend = "samples")
  result.geomText(aes("x", "y", label = "group"), size = 10)
  result.labels(title = "Round trip", x = "time", y = "value")
  result.legend(title = "Series")
  result.scaleX(skLog10, reversed = true)
  result.referenceY(3.25, label = "target")
  result.applyTheme(darkTheme())

suite "PlotSpec JSON schema":
  test "complete public semantics round trip deterministically":
    let encoded = completeSpec().toJson
    let decoded = fromJson(encoded)
    check decoded.toJson == encoded
    check decoded.compileScene().nodes.len ==
      completeSpec().compileScene().nodes.len
    check parseJson(encoded)["version"].getInt == PlotSpecSchemaVersion

  test "pretty encoding remains semantically identical":
    let spec = completeSpec()
    check fromJson(spec.toJson(pretty = true)).toJson == spec.toJson

  test "non-finite data uses explicit portable tokens":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 1.0, 2.0])
    frame.addColumn("y", [NaN, Inf, NegInf])
    var spec = plot(frame)
    spec.geomPoint(aes("x", "y"))
    let decoded = fromJson(spec.toJson).data.numeric("y")
    check decoded[0].isNaN
    check decoded[1] == Inf
    check decoded[2] == NegInf

  test "malformed and future schemas fail as PlotError":
    expect PlotError: discard fromJson("not json")
    var root = completeSpec().toJsonNode
    root["version"] = %(PlotSpecSchemaVersion + 1)
    expect PlotError: discard root.fromJsonNode
    root = completeSpec().toJsonNode
    root.delete("layers")
    expect PlotError: discard root.fromJsonNode
    root = completeSpec().toJsonNode
    root["layers"][0]["mark"] = %"unknown"
    expect PlotError: discard root.fromJsonNode

  test "decoded public values are revalidated by scene compilation":
    var root = completeSpec().toJsonNode
    root["mappedAlphaRange"]["maximum"] = %2.0
    let decoded = root.fromJsonNode
    expect PlotError: discard decoded.compileScene()

  test "unsupported semantic palette metadata is never silently lost":
    var roles = initTable[string, int]()
    roles["primary"] = 0
    let semantic = palette(palSemantic, [parseColor("#3366cc").get],
      intentUI, 0, roles).get
    var spec = completeSpec()
    spec.categoricalColors = semantic
    expect PlotError: discard spec.toJson
