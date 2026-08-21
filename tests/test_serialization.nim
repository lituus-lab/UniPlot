# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, sequtils, tables, unittest]
import UniColor
import UniImage/core as uimg
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
  result.xLimits(0.5, 8.0)
  result.yLimits(-1.0, 6.0)
  result.referenceY(3.25, label = "target")
  result.applyTheme(darkTheme())

suite "PlotSpec JSON schema":
  test "polygon marks round trip without changing earlier enum codes":
    var frame = initDataFrame()
    frame.addColumn("x", [0.0, 2.0, 1.0])
    frame.addColumn("y", [0.0, 0.0, 2.0])
    var spec = plot(frame)
    spec.geomPolygon(aes("x", "y"), color = "#22446688")
    let encoded = spec.toJson
    let restored = fromJson(encoded)
    check restored.layers[0].mark == mkPolygon
    check restored.toJson == encoded

    let grouped = violinPlot(["b", "a", "b", "a"],
      [1.0, 3.0, 2.0, 4.0], pointCount = 17)
    let groupedRestored = fromJson(grouped.toJson)
    check groupedRestored.layers[0].mapping.xOffset == "violinOffset"
    check groupedRestored.toJson == grouped.toJson

  test "numeric rectangle bounds round trip as optional mappings":
    var frame = initDataFrame()
    frame.addColumn("left", [0.0])
    frame.addColumn("right", [2.0])
    frame.addColumn("bottom", [1.0])
    frame.addColumn("top", [3.0])
    var spec = plot(frame)
    spec.geomRect(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top"))
    let restored = fromJson(spec.toJson)
    check restored.toJson == spec.toJson
    check restored.layers[0].mark == mkRect
    check restored.layers[0].mapping.xMin == "left"
    check restored.layers[0].mapping.xMax == "right"

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

  test "automatic domains retain the original schema-v1 representation":
    var spec = completeSpec()
    spec.clearXLimits()
    spec.clearYLimits()
    let encoded = spec.toJsonNode
    check not encoded["xScale"].hasKey("domain")
    check not encoded["yScale"].hasKey("domain")
    check fromJsonNode(encoded).toJsonNode == encoded

  test "categorical x domains round trip as an optional schema-v1 field":
    var spec = barPlot(["b", "a"], [2.0, 1.0])
    spec.xCategories(["c", "a", "b"])
    let encoded = spec.toJsonNode
    check encoded["xScale"]["categories"] == %*["c", "a", "b"]
    check fromJsonNode(encoded).toJsonNode == encoded

  test "secondary y transforms round trip as optional scale semantics":
    var spec = completeSpec()
    spec.secondaryY(scale = 1.8, offset = 32.0, label = "fahrenheit")
    let encoded = spec.toJsonNode
    check encoded["yScale"]["secondary"]["scale"].getFloat == 1.8
    check fromJsonNode(encoded).toJsonNode == encoded

  test "symmetric logarithmic transforms round trip additively":
    var spec = completeSpec()
    spec.scaleX(skSymLog10, reversed = true)
    spec.scaleY(skSymLog10)
    let encoded = spec.toJsonNode
    check encoded["xScale"]["kind"].getStr == "skSymLog10"
    check encoded["yScale"]["kind"].getStr == "skSymLog10"
    check fromJsonNode(encoded).toJsonNode == encoded

  test "temporal label kinds round trip as additive scale semantics":
    var spec = completeSpec()
    spec.scaleXUtc(reversed = true)
    spec.scaleYDuration()
    let encoded = spec.toJsonNode
    check encoded["xScale"]["labelKind"].getStr == "alkUtcDateTime"
    check encoded["yScale"]["labelKind"].getStr == "alkDuration"
    let restored = fromJsonNode(encoded)
    check restored.xScaleSpec.labelKind == alkUtcDateTime
    check restored.yScaleSpec.labelKind == alkDuration
    check restored.toJsonNode == encoded

    var numeric = completeSpec()
    numeric.scaleX()
    check not numeric.toJsonNode["xScale"].hasKey("labelKind")
    var invalid = encoded
    invalid["xScale"]["kind"] = %"skLog10"
    expect PlotError: discard fromJsonNode(invalid).compileScene()

  test "annotations round trip without changing unannotated schema-v1":
    var spec = completeSpec()
    check not spec.toJsonNode.hasKey("annotations")
    spec.annotateText(1.0, 2.0, "label", fontSize = 15)
    spec.annotateArrow(1.0, 2.0, 4.0, 5.0, width = 3, headSize = 9)
    let encoded = spec.toJsonNode
    check encoded["annotations"].len == 2
    check fromJsonNode(encoded).toJsonNode == encoded

  test "raster pixels and placement round trip deterministically":
    var spec = completeSpec()
    var image = uimg.newImage[uint8](2, 1, uimg.csRgba)
    image.data = @[255'u8, 0, 0, 255, 0, 0, 255, 64]
    spec.raster(image, 1.0, 3.0, 2.0, 4.0, RasterBox)
    let encoded = spec.toJson
    let restored = fromJson(encoded)
    check restored.toJson == encoded
    check restored.rasters.len == 1
    check restored.rasters[0].image.data == image.data
    check restored.rasters[0].filter == RasterBox

    for invalidPixels in ["AAAA", "!!!!!!!!!!!!"]:
      var hostile = parseJson(encoded)
      hostile["rasters"][0]["pixelsBase64"] = %invalidPixels
      expect PlotError: discard fromJson($hostile)
    var hostile = parseJson(encoded)
    hostile["rasters"][0]["width"] = %high(BiggestInt)
    expect PlotError: discard fromJson($hostile)
    hostile = parseJson(encoded)
    hostile["rasters"][0]["colorspace"] = %"csCmyk"
    expect PlotError: discard fromJson($hostile)

  test "image resources and mapped marks round trip in insertion order":
    var frame = initDataFrame()
    frame.addColumn("left", [0.0])
    frame.addColumn("right", [1.0])
    frame.addColumn("bottom", [0.0])
    frame.addColumn("top", [1.0])
    frame.addColumn("resource", ["badge"])
    var image = uimg.newImage[uint8](1, 1, uimg.csRgba)
    image.data = @[12'u8, 34, 56, 78]
    var spec = plot(frame)
    spec.addImageResource("badge", image)
    spec.geomImage(aes("", "", xMin = "left", xMax = "right",
      yMin = "bottom", yMax = "top", image = "resource"), RasterBox)
    let encoded = spec.toJson
    let restored = fromJson(encoded)
    check restored.toJson == encoded
    check restored.imageResources.len == 1
    check restored.imageResources[0].name == "badge"
    check restored.imageResources[0].image.data == image.data
    check restored.layers[0].mapping.image == "resource"
    check restored.layers[0].imageFilter == RasterBox
    check restored.compileScene().nodes.anyIt(it.kind == snImage)

    var hostile = parseJson(encoded)
    hostile["imageResources"].add hostile["imageResources"][0]
    expect PlotError: discard fromJson($hostile)
    hostile = parseJson(encoded)
    hostile["imageResources"][0]["pixelsBase64"] = %"!!!!!!!!"
    expect PlotError: discard fromJson($hostile)

  test "box-plot mappings round trip as optional schema-v1 fields":
    let spec = boxPlot(["a", "a", "b", "b"], [1.0, 2.0, 3.0, 4.0])
    let encoded = spec.toJsonNode
    check encoded["layers"][0]["mapping"]["yQ1"].getStr == "firstQuartile"
    check abs(encoded["layers"][0]["boxWidth"].getFloat - 0.65) < 1e-6
    check fromJsonNode(encoded).toJsonNode == encoded

  test "categorical y domains and tiles round trip optionally":
    var spec = heatmapPlot(["a", "b"], ["north", "south"], [1.0, 2.0])
    spec.yCategories(["south", "north", "reserved"])
    let encoded = spec.toJsonNode
    check encoded["layers"][0]["mark"].getStr == "mkTile"
    check encoded["yScale"]["categories"].len == 3
    check fromJsonNode(encoded).toJsonNode == encoded

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
    var annotationSpec = completeSpec()
    annotationSpec.annotateText(1.0, 2.0, "valid")
    var annotated = annotationSpec.toJsonNode
    annotated["annotations"][0]["text"] = %""
    annotated["annotations"][0]["size"] = %(-1.0)
    let decodedAnnotation = fromJsonNode(annotated)
    expect PlotError: discard decodedAnnotation.compileScene()

  test "unsupported semantic palette metadata is never silently lost":
    var roles = initTable[string, int]()
    roles["primary"] = 0
    let semantic = palette(palSemantic, [parseColor("#3366cc").get],
      intentUI, 0, roles).get
    var spec = completeSpec()
    spec.categoricalColors = semantic
    expect PlotError: discard spec.toJson
