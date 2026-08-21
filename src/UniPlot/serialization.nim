# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Versioned, deterministic JSON representation of PlotSpec values.
import std/[base64, json, math, strutils, tables]
import UniColor
import UniImage/core as ucore
import UniPlot/[common, data, grammar, scales]

const PlotSpecSchemaVersion* = 1

proc fail(message: string): ref PlotError =
  newException(PlotError, "invalid UniPlot JSON: " & message)

proc field(node: JsonNode; name: string; kind: JsonNodeKind): JsonNode =
  if node.kind != JObject or not node.hasKey(name):
    raise fail("missing field '" & name & "'")
  result = node[name]
  if result.kind != kind:
    raise fail("field '" & name & "' has the wrong type")

proc enumValue[T: enum](node: JsonNode; name: string): T =
  let value = node.field(name, JString).getStr
  try:
    parseEnum[T](value)
  except ValueError:
    raise fail("field '" & name & "' has an unknown value")

proc finiteNumber(node: JsonNode; name: string): float64 =
  let value = node.field(name, JFloat).getFloat
  if not value.isFinite: raise fail("field '" & name & "' must be finite")
  value

proc encodedNumber(value: float64): JsonNode =
  case classify(value)
  of fcNan: %"nan"
  of fcInf: %"inf"
  of fcNegInf: %"-inf"
  else: %value

proc decodedNumber(node: JsonNode): float64 =
  case node.kind
  of JInt, JFloat:
    result = node.getFloat
    if not result.isFinite: raise fail("numeric column contains invalid JSON")
  of JString:
    case node.getStr
    of "nan": result = NaN
    of "inf": result = Inf
    of "-inf": result = NegInf
    else: raise fail("numeric column contains an unknown special value")
  else:
    raise fail("numeric column value has the wrong type")

proc colorNode(value: Color): JsonNode =
  %*{"space": value.spaceTag.id, "components": [value.comp(0), value.comp(1),
    value.comp(2)], "alpha": value.alpha}

proc decodeColor(node: JsonNode): Color =
  let
    spaceId = node.field("space", JInt).getBiggestInt
    components = node.field("components", JArray)
    alpha = float32(node.finiteNumber("alpha"))
  if components.len != 3: raise fail("color must contain three components")
  var values: array[3, float32]
  for index in 0 .. 2:
    if components[index].kind notin {JInt, JFloat}:
      raise fail("color component has the wrong type")
    values[index] = float32(components[index].getFloat)
    if not values[index].isFinite:
      raise fail("color components must be finite")
  if spaceId < int32.low.int64 or spaceId > int32.high.int64:
    raise fail("color space identifier is outside int32")
  let decoded = color(SpaceTag(int32(spaceId)), values[0], values[1],
    values[2], alpha)
  if decoded.isErr: raise fail("color is outside its declared space")
  decoded.get

proc paletteNode(value: Palette): JsonNode =
  if value.tag == palSemantic:
    raise newException(PlotError,
      "PlotSpec schema v1 cannot encode semantic palette role maps")
  var colors = newJArray()
  for entry in value.colors: colors.add entry.colorNode
  %*{"tag": $value.tag, "intent": $value.intent, "seed": value.seed,
    "colors": colors}

proc decodePalette(node: JsonNode): Palette =
  let
    tag = enumValue[PaletteTag](node, "tag")
    intent = enumValue[PaletteIntent](node, "intent")
    seed = node.field("seed", JInt).getBiggestInt.int64
    colorNodes = node.field("colors", JArray)
  if tag == palSemantic:
    raise fail("semantic palettes are not supported by PlotSpec schema v1")
  var colors = newSeqOfCap[Color](colorNodes.len)
  for entry in colorNodes: colors.add entry.decodeColor
  let decoded = palette(tag, colors, intent, seed)
  if decoded.isErr: raise fail("palette is invalid")
  decoded.get

proc insetsNode(value: Insets): JsonNode =
  %*{"left": value.left, "top": value.top, "right": value.right,
    "bottom": value.bottom}

proc decodeInsets(node: JsonNode): Insets =
  Insets(left: float32(node.finiteNumber("left")),
    top: float32(node.finiteNumber("top")),
    right: float32(node.finiteNumber("right")),
    bottom: float32(node.finiteNumber("bottom")))

proc aesNode(value: Aes): JsonNode =
  result = %*{"x": value.x, "y": value.y, "yMin": value.yMin,
    "yMax": value.yMax,
    "label": value.label, "color": value.color, "fill": value.fill,
    "size": value.size, "alpha": value.alpha, "shape": value.shape,
    "lineStyle": value.lineStyle}
  if value.yQ1.len > 0 or value.yQ3.len > 0:
    result["yQ1"] = %value.yQ1
    result["yQ3"] = %value.yQ3
  if value.xMin.len > 0 or value.xMax.len > 0:
    result["xMin"] = %value.xMin
    result["xMax"] = %value.xMax
  if value.image.len > 0:
    result["image"] = %value.image
  if value.xOffset.len > 0:
    result["xOffset"] = %value.xOffset

proc decodeAes(node: JsonNode): Aes =
  for name in ["x", "y", "yMin", "yMax", "label", "color", "fill",
      "size", "alpha", "shape", "lineStyle"]:
    discard node.field(name, JString)
  result = Aes(x: node["x"].getStr, y: node["y"].getStr,
    yMin: node["yMin"].getStr, yMax: node["yMax"].getStr,
    label: node["label"].getStr, color: node["color"].getStr,
    fill: node["fill"].getStr, size: node["size"].getStr,
    alpha: node["alpha"].getStr, shape: node["shape"].getStr,
    lineStyle: node["lineStyle"].getStr)
  if node.hasKey("yQ1") or node.hasKey("yQ3"):
    result.yQ1 = node.field("yQ1", JString).getStr
    result.yQ3 = node.field("yQ3", JString).getStr
  if node.hasKey("xMin") or node.hasKey("xMax"):
    result.xMin = node.field("xMin", JString).getStr
    result.xMax = node.field("xMax", JString).getStr
  if node.hasKey("image"):
    result.image = node.field("image", JString).getStr
  if node.hasKey("xOffset"):
    result.xOffset = node.field("xOffset", JString).getStr

proc dataNode(frame: DataFrame): JsonNode =
  var columns = newJArray()
  for name in frame.order:
    let column = frame.columns[name]
    var values = newJArray()
    case column.kind
    of ckNumeric:
      for value in column.numbers: values.add value.encodedNumber
    of ckCategorical:
      for value in column.categories: values.add %value
    columns.add %*{"name": name, "kind": $column.kind, "values": values}
  %*{"columns": columns}

proc decodeData(node: JsonNode): DataFrame =
  result = initDataFrame()
  for columnNode in node.field("columns", JArray):
    let
      name = columnNode.field("name", JString).getStr
      kind = enumValue[ColumnKind](columnNode, "kind")
      values = columnNode.field("values", JArray)
    if name in result.columns:
      raise fail("duplicate column name '" & name & "'")
    case kind
    of ckNumeric:
      var decoded = newSeqOfCap[float64](values.len)
      for value in values: decoded.add value.decodedNumber
      result.addColumn(name, decoded)
    of ckCategorical:
      var decoded = newSeqOfCap[string](values.len)
      for value in values:
        if value.kind != JString:
          raise fail("categorical column value has the wrong type")
        decoded.add value.getStr
      result.addColumn(name, decoded)

proc toJsonNode*(spec: PlotSpec): JsonNode =
  var layers = newJArray()
  for layer in spec.layers:
    let encoded = %*{"mark": $layer.mark, "mapping": layer.mapping.aesNode,
      "color": layer.color.colorNode, "size": layer.size,
      "legendLabel": layer.legendLabel, "shape": $layer.shape,
      "lineStyle": $layer.lineStyle, "missingValues": $layer.missingValues,
      "capWidth": layer.capWidth}
    if layer.mark == mkBoxPlot: encoded["boxWidth"] = %layer.boxWidth
    if layer.mark == mkImage: encoded["imageFilter"] = %($layer.imageFilter)
    layers.add encoded
  var references = newJArray()
  for reference in spec.references:
    references.add %*{"kind": $reference.kind,
      "minimum": reference.minimum, "maximum": reference.maximum,
      "color": reference.color.colorNode, "width": reference.width,
      "label": reference.label}
  var xScale = %*{"kind": $spec.xScaleSpec.kind,
    "reversed": spec.xScaleSpec.reversed}
  if spec.xScaleSpec.kind == skPower:
    xScale["exponent"] = %spec.xScaleSpec.exponent
  if spec.xScaleSpec.labelKind != alkNumeric:
    xScale["labelKind"] = %($spec.xScaleSpec.labelKind)
  if spec.xScaleSpec.domain.configured:
    xScale["domain"] = %*{"minimum": spec.xScaleSpec.domain.minimum,
      "maximum": spec.xScaleSpec.domain.maximum}
  if spec.xScaleSpec.categories.configured:
    xScale["categories"] = %spec.xScaleSpec.categories.values
  var yScale = %*{"kind": $spec.yScaleSpec.kind,
    "reversed": spec.yScaleSpec.reversed}
  if spec.yScaleSpec.kind == skPower:
    yScale["exponent"] = %spec.yScaleSpec.exponent
  if spec.yScaleSpec.labelKind != alkNumeric:
    yScale["labelKind"] = %($spec.yScaleSpec.labelKind)
  if spec.yScaleSpec.domain.configured:
    yScale["domain"] = %*{"minimum": spec.yScaleSpec.domain.minimum,
      "maximum": spec.yScaleSpec.domain.maximum}
  if spec.yScaleSpec.categories.configured:
    yScale["categories"] = %spec.yScaleSpec.categories.values
  if spec.secondaryYSpec.enabled:
    yScale["secondary"] = %*{"scale": spec.secondaryYSpec.scale,
      "offset": spec.secondaryYSpec.offset, "label": spec.secondaryYSpec.label}
  result = %*{
    "schema": "org.lituus-lab.uniplot.plot-spec",
    "version": PlotSpecSchemaVersion,
    "data": spec.data.dataNode,
    "layers": layers,
    "labels": {"title": spec.title, "x": spec.xLabel, "y": spec.yLabel},
    "theme": {"background": spec.theme.background.colorNode,
      "foreground": spec.theme.foreground.colorNode,
      "gridColor": spec.theme.gridColor.colorNode,
      "margins": spec.theme.margins.insetsNode,
      "pointSize": spec.theme.pointSize, "lineWidth": spec.theme.lineWidth},
    "legend": {"visible": spec.legendSpec.visible,
      "title": spec.legendSpec.title, "position": $spec.legendSpec.position},
    "categoricalColors": spec.categoricalColors.paletteNode,
    "continuousColors": spec.continuousColors.paletteNode,
    "mappedSizeRange": {"minimum": spec.mappedSizeRange.minimum,
      "maximum": spec.mappedSizeRange.maximum},
    "mappedAlphaRange": {"minimum": spec.mappedAlphaRange.minimum,
      "maximum": spec.mappedAlphaRange.maximum},
    "xScale": xScale,
    "yScale": yScale,
    "references": references
  }
  if spec.annotations.len > 0:
    var annotations = newJArray()
    for annotation in spec.annotations:
      annotations.add %*{"kind": $annotation.kind, "x": annotation.x,
        "y": annotation.y, "xEnd": annotation.xEnd, "yEnd": annotation.yEnd,
        "text": annotation.text, "color": annotation.color.colorNode,
        "size": annotation.size, "headSize": annotation.headSize}
    result["annotations"] = annotations
  if spec.imageResources.len > 0:
    var resources = newJArray()
    for resource in spec.imageResources:
      resources.add %*{"name": resource.name, "width": resource.image.width,
        "height": resource.image.height,
        "colorspace": $resource.image.colorspace,
        "pixelsBase64": encode(resource.image.data)}
    result["imageResources"] = resources
  if spec.rasters.len > 0:
    var rasters = newJArray()
    for raster in spec.rasters:
      rasters.add %*{"width": raster.image.width,
        "height": raster.image.height, "colorspace": $raster.image.colorspace,
        "pixelsBase64": encode(raster.image.data), "xMin": raster.xMin,
        "xMax": raster.xMax, "yMin": raster.yMin, "yMax": raster.yMax,
        "filter": $raster.filter}
    result["rasters"] = rasters

proc toJson*(spec: PlotSpec; pretty = false): string =
  ## Encode a PlotSpec using the stable schema-v1 field order.
  let node = spec.toJsonNode
  if pretty: node.pretty else: $node

proc decodeRange(node: JsonNode): AestheticRange =
  AestheticRange(minimum: float32(node.finiteNumber("minimum")),
    maximum: float32(node.finiteNumber("maximum")))

proc decodePackedImage(node: JsonNode; subject: string): ucore.Image[uint8] =
  let
    widthValue = node.field("width", JInt).getBiggestInt
    heightValue = node.field("height", JInt).getBiggestInt
    colorspace = enumValue[ucore.Colorspace](node, "colorspace")
  if colorspace notin {ucore.csGray, ucore.csRgb, ucore.csRgba} or
      widthValue <= 0 or heightValue <= 0 or
      widthValue > BiggestInt(high(int)) or
      heightValue > BiggestInt(high(int)):
    raise fail(subject & " dimensions or colorspace are invalid")
  let
    width = int(widthValue)
    height = int(heightValue)
    channels = ucore.ChannelCount[colorspace]
  if width > high(int) div height or
      width * height > high(int) div channels:
    raise fail(subject & " dimensions overflow packed storage")
  let
    expected = width * height * channels
    encodedPixels = node.field("pixelsBase64", JString).getStr
    expectedEncoded = ((uint64(expected) + 2'u64) div 3'u64) * 4'u64
  if uint64(encodedPixels.len) != expectedEncoded:
    raise fail(subject & " base64 length does not match its dimensions")
  let decoded = decode(encodedPixels)
  if decoded.len != expected:
    raise fail(subject & " pixels do not match their dimensions")
  result = ucore.Image[uint8](width: width, height: height,
    channels: channels, colorspace: colorspace,
    data: newSeq[uint8](decoded.len))
  if decoded.len > 0:
    copyMem(addr result.data[0], unsafeAddr decoded[0], decoded.len)

proc fromJsonNode*(root: JsonNode): PlotSpec =
  ## Decode schema v1. compileScene remains the semantic validation boundary.
  if root.field("schema", JString).getStr !=
      "org.lituus-lab.uniplot.plot-spec":
    raise fail("unknown schema identifier")
  if root.field("version", JInt).getInt != PlotSpecSchemaVersion:
    raise fail("unsupported schema version")
  result = plot(root.field("data", JObject).decodeData)
  result.layers.setLen(0)
  for node in root.field("layers", JArray):
    let mark = enumValue[MarkKind](node, "mark")
    result.layers.add Layer(mark: mark,
      mapping: node.field("mapping", JObject).decodeAes,
      color: node.field("color", JObject).decodeColor,
      size: float32(node.finiteNumber("size")),
      legendLabel: node.field("legendLabel", JString).getStr,
      shape: enumValue[MarkerShape](node, "shape"),
      lineStyle: enumValue[LineStyle](node, "lineStyle"),
      missingValues: enumValue[MissingValuePolicy](node, "missingValues"),
      capWidth: float32(node.finiteNumber("capWidth")))
    if mark == mkBoxPlot:
      result.layers[^1].boxWidth = float32(node.finiteNumber("boxWidth"))
    if mark == mkImage:
      result.layers[^1].imageFilter = enumValue[RasterFilter](node,
        "imageFilter")
  let labels = root.field("labels", JObject)
  result.title = labels.field("title", JString).getStr
  result.xLabel = labels.field("x", JString).getStr
  result.yLabel = labels.field("y", JString).getStr
  let theme = root.field("theme", JObject)
  result.theme = grammar.Theme(
    background: theme.field("background", JObject).decodeColor,
    foreground: theme.field("foreground", JObject).decodeColor,
    gridColor: theme.field("gridColor", JObject).decodeColor,
    margins: theme.field("margins", JObject).decodeInsets,
    pointSize: float32(theme.finiteNumber("pointSize")),
    lineWidth: float32(theme.finiteNumber("lineWidth")))
  let legend = root.field("legend", JObject)
  result.legendSpec = LegendSpec(
    visible: legend.field("visible", JBool).getBool,
    title: legend.field("title", JString).getStr,
    position: enumValue[LegendPosition](legend, "position"))
  result.categoricalColors = root.field("categoricalColors",
    JObject).decodePalette
  result.continuousColors = root.field("continuousColors",
    JObject).decodePalette
  result.mappedSizeRange = root.field("mappedSizeRange", JObject).decodeRange
  result.mappedAlphaRange = root.field("mappedAlphaRange", JObject).decodeRange
  let xScale = root.field("xScale", JObject)
  result.xScaleSpec = AxisScaleSpec(kind: enumValue[ScaleKind](xScale, "kind"),
    exponent: 1.0, reversed: xScale.field("reversed", JBool).getBool)
  if result.xScaleSpec.kind == skPower:
    result.xScaleSpec.exponent = xScale.finiteNumber("exponent")
    if result.xScaleSpec.exponent <= 0.0:
      raise fail("x power exponent must be positive")
  if xScale.hasKey("labelKind"):
    result.xScaleSpec.labelKind = enumValue[AxisLabelKind](xScale, "labelKind")
  if xScale.hasKey("domain"):
    let domain = xScale.field("domain", JObject)
    result.xScaleSpec.domain = AxisDomainSpec(configured: true,
      minimum: domain.finiteNumber("minimum"),
      maximum: domain.finiteNumber("maximum"))
  if xScale.hasKey("categories"):
    let categories = xScale.field("categories", JArray)
    result.xScaleSpec.categories = AxisCategoryDomainSpec(configured: true)
    for category in categories:
      if category.kind != JString:
        raise fail("x scale categories must be strings")
      result.xScaleSpec.categories.values.add category.getStr
  let yScale = root.field("yScale", JObject)
  result.yScaleSpec = AxisScaleSpec(kind: enumValue[ScaleKind](yScale, "kind"),
    exponent: 1.0, reversed: yScale.field("reversed", JBool).getBool)
  if result.yScaleSpec.kind == skPower:
    result.yScaleSpec.exponent = yScale.finiteNumber("exponent")
    if result.yScaleSpec.exponent <= 0.0:
      raise fail("y power exponent must be positive")
  if yScale.hasKey("labelKind"):
    result.yScaleSpec.labelKind = enumValue[AxisLabelKind](yScale, "labelKind")
  if yScale.hasKey("domain"):
    let domain = yScale.field("domain", JObject)
    result.yScaleSpec.domain = AxisDomainSpec(configured: true,
      minimum: domain.finiteNumber("minimum"),
      maximum: domain.finiteNumber("maximum"))
  if yScale.hasKey("categories"):
    let categories = yScale.field("categories", JArray)
    result.yScaleSpec.categories = AxisCategoryDomainSpec(configured: true)
    for category in categories:
      if category.kind != JString:
        raise fail("y scale categories must be strings")
      result.yScaleSpec.categories.values.add category.getStr
  if yScale.hasKey("secondary"):
    let secondary = yScale.field("secondary", JObject)
    result.secondaryYSpec = SecondaryAxisSpec(enabled: true,
      scale: secondary.finiteNumber("scale"),
      offset: secondary.finiteNumber("offset"),
      label: secondary.field("label", JString).getStr)
  result.references.setLen(0)
  for node in root.field("references", JArray):
    result.references.add Reference(
      kind: enumValue[ReferenceKind](node, "kind"),
      minimum: node.finiteNumber("minimum"),
      maximum: node.finiteNumber("maximum"),
      color: node.field("color", JObject).decodeColor,
      width: float32(node.finiteNumber("width")),
      label: node.field("label", JString).getStr)
  result.annotations.setLen(0)
  if root.hasKey("annotations"):
    for node in root.field("annotations", JArray):
      result.annotations.add Annotation(
        kind: enumValue[AnnotationKind](node, "kind"),
        x: node.finiteNumber("x"), y: node.finiteNumber("y"),
        xEnd: node.finiteNumber("xEnd"), yEnd: node.finiteNumber("yEnd"),
        text: node.field("text", JString).getStr,
        color: node.field("color", JObject).decodeColor,
        size: float32(node.finiteNumber("size")),
        headSize: float32(node.finiteNumber("headSize")))
  result.rasters.setLen(0)
  result.imageResources.setLen(0)
  if root.hasKey("imageResources"):
    var names = initTable[string, bool]()
    for node in root.field("imageResources", JArray):
      let name = node.field("name", JString).getStr
      if name.len == 0 or name in names:
        raise fail("image resource names must be non-empty and unique")
      names[name] = true
      result.imageResources.add ImageResource(name: name,
        image: node.decodePackedImage("image resource"))
  if root.hasKey("rasters"):
    for node in root.field("rasters", JArray):
      let raster = RasterLayer(image: node.decodePackedImage("raster"),
        xMin: node.finiteNumber("xMin"), xMax: node.finiteNumber("xMax"),
        yMin: node.finiteNumber("yMin"), yMax: node.finiteNumber("yMax"),
        filter: enumValue[RasterFilter](node, "filter"))
      if raster.xMin >= raster.xMax or raster.yMin >= raster.yMax:
        raise fail("raster extents must be increasing")
      result.rasters.add raster

proc fromJson*(payload: string): PlotSpec =
  ## Parse and decode schema-v1 JSON as PlotError on all malformed input.
  try:
    result = parseJson(payload).fromJsonNode
  except PlotError:
    raise
  except CatchableError as error:
    raise fail(error.msg)
