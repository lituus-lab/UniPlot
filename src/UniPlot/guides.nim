# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, tables]
import UniVector
import UniPlot/[common, data, scales, grammar, scene]

proc polygon(points: openArray[Point]): Path =
  result = newPath()
  if points.len == 0: return
  result.moveTo(points[0].x, points[0].y)
  for i in 1 ..< points.len: result.lineTo(points[i].x, points[i].y)
  result.closePath()

proc circle(center: Point; radius: float32): Path =
  result = newPath()
  result.arc(center.x, center.y, radius, 0, (2 * PI).float32)
  result.closePath()

proc segmentPath(a, b: Point; width: float32): Path =
  let dx = b.x - a.x
  let dy = b.y - a.y
  let length = sqrt(dx * dx + dy * dy)
  if length == 0: return circle(a, width * 0.5)
  let nx = -dy / length * width * 0.5
  let ny = dx / length * width * 0.5
  polygon([Point(x: a.x + nx, y: a.y + ny),
    Point(x: b.x + nx, y: b.y + ny), Point(x: b.x - nx, y: b.y - ny),
    Point(x: a.x - nx, y: a.y - ny)])

proc compileScene*(spec: PlotSpec; size = Size(width: 800,
    height: 500)): Scene =
  size.validate()
  if spec.layers.len == 0: raise newException(PlotError, "plot has no layers")
  for margin in [spec.theme.margins.left, spec.theme.margins.top,
      spec.theme.margins.right, spec.theme.margins.bottom]:
    if margin < 0 or not margin.isFinite:
      raise newException(PlotError, "plot margins must be finite and non-negative")
  if spec.theme.pointSize <= 0 or not spec.theme.pointSize.isFinite or
      spec.theme.lineWidth <= 0 or not spec.theme.lineWidth.isFinite:
    raise newException(PlotError,
      "theme point size and line width must be finite and positive")
  result = initScene(size, spec.theme.background)
  var legendLayers: seq[Layer]
  if spec.legendSpec.visible:
    for layer in spec.layers:
      if layer.legendLabel.len > 0: legendLayers.add layer
  var area = Bounds(xMin: spec.theme.margins.left,
    yMin: spec.theme.margins.top, xMax: float32(size.width) -
        spec.theme.margins.right,
    yMax: float32(size.height) - spec.theme.margins.bottom)
  const legendWidth = 150'f32
  if legendLayers.len > 0:
    if spec.legendSpec.position != lpRight:
      raise newException(PlotError, "unsupported legend position")
    area.xMax -= legendWidth
  if area.width <= 0 or area.height <= 0:
    raise newException(PlotError, "plot margins leave no drawing area")
  let legendRows = legendLayers.len + ord(spec.legendSpec.title.len > 0)
  if legendRows > 0 and float32(legendRows * 24) > area.height:
    raise newException(PlotError, "legend does not fit the drawing height")
  for layer in spec.layers:
    if layer.mapping.x notin spec.data.columns or
        layer.mapping.y notin spec.data.columns:
      raise newException(PlotError, "layer mapping references a missing column")
    if spec.data.columns[layer.mapping.y].kind != ckNumeric:
      raise newException(PlotError, "y mappings must reference numeric columns")
    if layer.mark == mkText and (layer.mapping.label.len == 0 or
        layer.mapping.label notin spec.data.columns or
        spec.data.columns[layer.mapping.label].kind != ckCategorical):
      raise newException(PlotError,
        "text label mappings must reference categorical columns")
  let xKind = spec.data.columns[spec.layers[0].mapping.x].kind
  var allX, allY: seq[float64]
  var allCategories: seq[string]
  var includeZero = false
  for layer in spec.layers:
    if spec.data.columns[layer.mapping.x].kind != xKind:
      raise newException(PlotError, "all x mappings must use the same column kind")
    if xKind == ckNumeric: allX.add spec.data.numeric(layer.mapping.x)
    else: allCategories.add spec.data.categorical(layer.mapping.x)
    allY.add spec.data.numeric(layer.mapping.y)
    includeZero = includeZero or layer.mark in {mkBar, mkArea}
  if includeZero: allY.add 0.0
  var xScale: ContinuousScale
  var xBand: BandScale
  if xKind == ckNumeric: xScale = trainContinuous(allX, area.xMin, area.xMax)
  else: xBand = trainBand(allCategories, area.xMin, area.xMax)
  let yScale = trainContinuous(allY, area.yMax, area.yMin)
  var nodeId = 1'u64
  if xKind == ckNumeric:
    for value in xScale.ticks():
      let x = xScale.map(value)
      result.addPath(segmentPath(Point(x: x, y: area.yMin),
        Point(x: x, y: area.yMax), 1), spec.theme.gridColor)
      result.addText(tickLabel(value), Point(x: x, y: area.yMax + 20), 11,
        spec.theme.foreground)
  else:
    for value in xBand.domain:
      result.addText(value, Point(x: xBand.map(value), y: area.yMax + 20), 11,
        spec.theme.foreground)
  for value in yScale.ticks():
    let y = yScale.map(value)
    result.addPath(segmentPath(Point(x: area.xMin, y: y),
      Point(x: area.xMax, y: y), 1), spec.theme.gridColor)
    result.addText(tickLabel(value), Point(x: 5, y: y), 11,
      spec.theme.foreground)
  if spec.title.len > 0:
    result.addText(spec.title, Point(x: area.xMin, y: 25), 18,
      spec.theme.foreground)
  if spec.xLabel.len > 0:
    result.addText(spec.xLabel, Point(x: (area.xMin + area.xMax) * 0.5,
      y: float32(size.height) - 20), 13, spec.theme.foreground)
  if spec.yLabel.len > 0:
    result.addText(spec.yLabel, Point(x: 5, y: area.yMin - 20), 13,
      spec.theme.foreground)
  for layer in spec.layers:
    let
      ys = spec.data.numeric(layer.mapping.y)
      numericXs = if xKind == ckNumeric:
        spec.data.numeric(layer.mapping.x)
      else:
        @[]
      categoricalXs = if xKind == ckCategorical:
        spec.data.categorical(layer.mapping.x)
      else:
        @[]
    let rows = spec.data.finiteRows([layer.mapping.x, layer.mapping.y])
    var points: seq[Point]
    for row in rows:
      let x = if xKind == ckNumeric:
        xScale.map(numericXs[row])
      else:
        xBand.map(categoricalXs[row])
      points.add Point(x: x, y: yScale.map(ys[row]))
    case layer.mark
    of mkPoint:
      let radius = if layer.size > 0: layer.size else: spec.theme.pointSize
      for point in points:
        result.addPath(circle(point, radius), layer.color, nodeId); inc nodeId
    of mkLine:
      let width = if layer.size > 0: layer.size else: spec.theme.lineWidth
      for i in 1 ..< points.len:
        result.addPath(segmentPath(points[i - 1], points[i], width),
            layer.color,
          nodeId); inc nodeId
    of mkBar:
      let barWidth = if xKind == ckCategorical: xBand.bandwidth
        else: max(1'f32, area.width / float32(max(1, points.len)) * 0.8)
      let base = yScale.map(0.0)
      for point in points:
        var path = newPath()
        path.rect(point.x - barWidth * 0.5, min(point.y, base), barWidth,
          abs(base - point.y))
        result.addPath(path, layer.color, nodeId); inc nodeId
    of mkArea:
      if points.len > 0:
        let base = yScale.map(0.0)
        var areaPoints = points
        areaPoints.add Point(x: points[^1].x, y: base)
        areaPoints.add Point(x: points[0].x, y: base)
        result.addPath(polygon(areaPoints), layer.color, nodeId); inc nodeId
    of mkText:
      if layer.mapping.label.len == 0:
        raise newException(PlotError, "text layers require a label mapping")
      let labels = spec.data.categorical(layer.mapping.label)
      for i, row in rows:
        result.addText(labels[row], points[i], if layer.size >
            0: layer.size else: 12,
          layer.color, nodeId); inc nodeId
  if legendLayers.len > 0:
    let legendX = area.xMax + 24
    var legendY = area.yMin + 14
    if spec.legendSpec.title.len > 0:
      result.addText(spec.legendSpec.title, Point(x: legendX, y: legendY), 13,
        spec.theme.foreground)
      legendY += 24
    for layer in legendLayers:
      let center = Point(x: legendX + 10, y: legendY - 4)
      case layer.mark
      of mkLine:
        let width = if layer.size > 0: layer.size else: spec.theme.lineWidth
        result.addPath(segmentPath(Point(x: legendX, y: center.y),
          Point(x: legendX + 20, y: center.y), width), layer.color)
      of mkPoint:
        let radius = if layer.size > 0: layer.size else: spec.theme.pointSize
        result.addPath(circle(center, min(radius, 7'f32)), layer.color)
      of mkBar, mkArea:
        var swatch = newPath()
        swatch.rect(legendX + 2, center.y - 6, 16, 12)
        result.addPath(swatch, layer.color)
      of mkText:
        result.addText("T", Point(x: legendX + 4, y: legendY), 13,
          layer.color)
      result.addText(layer.legendLabel, Point(x: legendX + 30, y: legendY),
        12, spec.theme.foreground)
      legendY += 24
