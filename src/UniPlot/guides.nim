# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, tables]
import UniColor
import UniVector
import UniPlot/[common, data, scales, grammar, scene]

type LegendEntry = object
  mark: MarkKind
  color: Color
  label: string
  category: string
  size: float32
  shape: MarkerShape
  lineStyle: LineStyle

type ContinuousGuide = object
  label: string
  sampler: PreparedPaletteSampler
  scale: ContinuousScale

proc polygon(points: openArray[Point]): Path =
  result = newPath()
  if points.len == 0: return
  result.moveTo(points[0].x, points[0].y)
  for i in 1 ..< points.len: result.lineTo(points[i].x, points[i].y)
  result.closePath()

proc segmentPath(a, b: Point; width: float32): Path =
  let dx = b.x - a.x
  let dy = b.y - a.y
  let length = sqrt(dx * dx + dy * dy)
  if length == 0:
    return markerPath(CircleMarker, vec2(a.x, a.y), width)
  let nx = -dy / length * width * 0.5
  let ny = dx / length * width * 0.5
  polygon([Point(x: a.x + nx, y: a.y + ny),
    Point(x: b.x + nx, y: b.y + ny), Point(x: b.x - nx, y: b.y - ny),
    Point(x: a.x - nx, y: a.y - ny)])

func mappedShape(index: int): MarkerShape =
  if index > MarkerShape.high.ord:
    raise newException(PlotError, "shape mapping exceeds marker capacity")
  MarkerShape(index)

func mappedLineStyle(index: int): LineStyle =
  if index > LineStyle.high.ord:
    raise newException(PlotError, "line-style mapping exceeds style capacity")
  LineStyle(index)

proc lineStrokeStyle(width: float32; lineStyle: LineStyle): StrokeStyle =
  result = defaultStrokeStyle(width)
  case lineStyle
  of SolidLine:
    discard
  of DashedLine:
    result.dash = dashPattern([6'f32 * width, 3'f32 * width])
  of DottedLine:
    result.cap = RoundCap
    result.dash = dashPattern([width, 2'f32 * width])
  of DotDashLine:
    result.cap = RoundCap
    result.dash = dashPattern([width, 2'f32 * width, 6'f32 * width,
      2'f32 * width])
  of LongDashLine:
    result.dash = dashPattern([10'f32 * width, 4'f32 * width])

proc linePath(points: openArray[Point]; width: float32;
              lineStyle: LineStyle): Path =
  result = newPath()
  if points.len < 2: return
  result.moveTo(points[0].x, points[0].y)
  for i in 1 ..< points.len:
    result.lineTo(points[i].x, points[i].y)
  result = result.preparePath().strokeToPath(
    lineStrokeStyle(width, lineStyle))

proc categoricalEntries(spec: PlotSpec; layer: Layer;
                        mapping: string): seq[LegendEntry] =
  if mapping.len == 0: return
  var seen = initTable[string, bool]()
  for category in spec.data.categorical(mapping):
    if category notin seen:
      seen[category] = true
      let index = result.len
      if index >= spec.categoricalColors.len:
        raise newException(PlotError,
          "categorical color mapping exceeds palette capacity")
      let mapped = spec.categoricalColors.colorAt(index)
      if mapped.isErr:
        raise newException(PlotError, "cannot read categorical palette color")
      let label = if layer.legendLabel.len > 0:
        layer.legendLabel & ": " & category
      else:
        category
      result.add LegendEntry(mark: layer.mark, color: mapped.get,
        label: label, category: category, size: layer.size,
        shape: if layer.mapping.shape == mapping:
          mappedShape(index) else: layer.shape,
        lineStyle: if layer.mapping.lineStyle == mapping:
          mappedLineStyle(index) else: layer.lineStyle)

proc shapeEntries(spec: PlotSpec; layer: Layer): seq[LegendEntry] =
  if layer.mapping.shape.len == 0: return
  var seen = initTable[string, bool]()
  for category in spec.data.categorical(layer.mapping.shape):
    if category notin seen:
      seen[category] = true
      let index = result.len
      let label = if layer.legendLabel.len > 0:
        layer.legendLabel & ": " & category
      else:
        category
      result.add LegendEntry(mark: layer.mark, color: layer.color,
        label: label, category: category, size: layer.size,
        shape: mappedShape(index), lineStyle: layer.lineStyle)

proc lineStyleEntries(spec: PlotSpec; layer: Layer): seq[LegendEntry] =
  if layer.mapping.lineStyle.len == 0: return
  var seen = initTable[string, bool]()
  for category in spec.data.categorical(layer.mapping.lineStyle):
    if category notin seen:
      seen[category] = true
      let index = result.len
      let label = if layer.legendLabel.len > 0:
        layer.legendLabel & ": " & category
      else:
        category
      result.add LegendEntry(mark: layer.mark, color: layer.color,
        label: label, category: category, size: layer.size,
        shape: layer.shape, lineStyle: mappedLineStyle(index))

proc withOpacity(value: Color; opacity: float32): Color =
  let adjusted = color(value.spaceTag, value.comp(0), value.comp(1),
    value.comp(2), value.alpha * opacity)
  if adjusted.isErr:
    raise newException(PlotError, "cannot apply mapped alpha to color")
  adjusted.get

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
  var usesContinuousColors = false
  for layer in spec.layers:
    if layer.mapping.x notin spec.data.columns or
        layer.mapping.y notin spec.data.columns:
      raise newException(PlotError, "layer mapping references a missing column")
    if spec.data.columns[layer.mapping.y].kind != ckNumeric:
      raise newException(PlotError, "y mappings must reference numeric columns")
    if layer.mapping.color.len > 0 and
        layer.mapping.color notin spec.data.columns:
      raise newException(PlotError,
        "color mappings must reference an existing column")
    if layer.mapping.fill.len > 0 and
        (layer.mark notin {mkPoint, mkBar} or
        layer.mapping.fill notin spec.data.columns):
      raise newException(PlotError,
        "fill mappings require a point or bar column")
    if layer.mapping.color.len > 0 and layer.mapping.fill.len > 0:
      raise newException(PlotError,
        "a layer cannot map both color and fill")
    let paintMapping = if layer.mapping.fill.len > 0:
      layer.mapping.fill else: layer.mapping.color
    if paintMapping.len > 0 and
        spec.data.columns[paintMapping].kind == ckNumeric:
      usesContinuousColors = true
    if layer.mapping.shape.len > 0 and
        (layer.mark != mkPoint or layer.mapping.shape notin spec.data.columns or
        spec.data.columns[layer.mapping.shape].kind != ckCategorical):
      raise newException(PlotError,
        "shape mappings require a categorical point-layer column")
    if layer.mapping.lineStyle.len > 0 and
        (layer.mark != mkLine or
        layer.mapping.lineStyle notin spec.data.columns or
        spec.data.columns[layer.mapping.lineStyle].kind != ckCategorical):
      raise newException(PlotError,
        "line-style mappings require a categorical line-layer column")
    for mapping in [layer.mapping.size, layer.mapping.alpha]:
      if mapping.len > 0 and (mapping notin spec.data.columns or
          spec.data.columns[mapping].kind != ckNumeric):
        raise newException(PlotError,
          "size and alpha mappings must reference numeric columns")
    if layer.mark == mkArea and (layer.mapping.color.len > 0 or
        layer.mapping.fill.len > 0 or
        layer.mapping.size.len > 0 or layer.mapping.alpha.len > 0 or
        layer.mapping.shape.len > 0 or layer.mapping.lineStyle.len > 0):
      raise newException(PlotError,
        "area layers do not support per-row aesthetic mappings")
    if layer.mark == mkText and (layer.mapping.label.len == 0 or
        layer.mapping.label notin spec.data.columns or
        spec.data.columns[layer.mapping.label].kind != ckCategorical):
      raise newException(PlotError,
        "text label mappings must reference categorical columns")
  var continuousSampler: PreparedPaletteSampler
  if usesContinuousColors:
    let prepared = spec.continuousColors.prepareSampler()
    if prepared.isErr:
      raise newException(PlotError,
        "cannot prepare the continuous color palette")
    continuousSampler = prepared.get
  result = initScene(size, spec.theme.background)
  var legendEntries: seq[LegendEntry]
  var continuousGuides: seq[ContinuousGuide]
  var continuousMappings = initTable[string, bool]()
  if spec.legendSpec.visible:
    for layer in spec.layers:
      let paintMapping = if layer.mapping.fill.len > 0:
        layer.mapping.fill else: layer.mapping.color
      if paintMapping.len > 0:
        case spec.data.columns[paintMapping].kind
        of ckCategorical:
          legendEntries.add spec.categoricalEntries(layer, paintMapping)
        of ckNumeric:
          if paintMapping notin continuousMappings:
            continuousMappings[paintMapping] = true
            let scale = trainContinuous(spec.data.numeric(paintMapping), 0, 1)
            continuousGuides.add ContinuousGuide(
              label: if layer.legendLabel.len > 0:
                layer.legendLabel else: paintMapping,
              sampler: continuousSampler, scale: scale)
      if layer.mapping.shape.len > 0 and
          layer.mapping.shape != paintMapping:
        legendEntries.add spec.shapeEntries(layer)
      if layer.mapping.lineStyle.len > 0 and
          layer.mapping.lineStyle != paintMapping:
        legendEntries.add spec.lineStyleEntries(layer)
      if paintMapping.len == 0 and layer.mapping.shape.len == 0 and
          layer.mapping.lineStyle.len == 0 and layer.legendLabel.len > 0:
        legendEntries.add LegendEntry(mark: layer.mark, color: layer.color,
          label: layer.legendLabel, size: layer.size, shape: layer.shape,
          lineStyle: layer.lineStyle)
  var area = Bounds(xMin: spec.theme.margins.left,
    yMin: spec.theme.margins.top, xMax: float32(size.width) -
        spec.theme.margins.right,
    yMax: float32(size.height) - spec.theme.margins.bottom)
  const legendWidth = 150'f32
  if legendEntries.len > 0 or continuousGuides.len > 0:
    if spec.legendSpec.position != lpRight:
      raise newException(PlotError, "unsupported legend position")
    area.xMax -= legendWidth
  if area.width <= 0 or area.height <= 0:
    raise newException(PlotError, "plot margins leave no drawing area")
  let legendHeight = float32(legendEntries.len * 24 +
    continuousGuides.len * 168 + ord(spec.legendSpec.title.len > 0) * 24)
  if legendHeight > area.height:
    raise newException(PlotError, "legend does not fit the drawing height")
  let xKind = spec.data.columns[spec.layers[0].mapping.x].kind
  var xDomain = initContinuousDomain()
  var xBandDomain = initBandDomain()
  var yDomain = initContinuousDomain()
  var includeZero = false
  for layer in spec.layers:
    if spec.data.columns[layer.mapping.x].kind != xKind:
      raise newException(PlotError, "all x mappings must use the same column kind")
    if xKind == ckNumeric:
      xDomain.addValues(spec.data.numeric(layer.mapping.x))
    else:
      xBandDomain.addValues(spec.data.categorical(layer.mapping.x))
    yDomain.addValues(spec.data.numeric(layer.mapping.y))
    includeZero = includeZero or layer.mark in {mkBar, mkArea}
  if includeZero: yDomain.addValues([0.0])
  var xScale: ContinuousScale
  var xBand: BandScale
  if xKind == ckNumeric: xScale = xDomain.train(area.xMin, area.xMax)
  else: xBand = xBandDomain.train(area.xMin, area.xMax)
  let yScale = yDomain.train(area.yMax, area.yMin)
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
    var finiteColumns = @[layer.mapping.x, layer.mapping.y]
    if layer.mapping.size.len > 0: finiteColumns.add layer.mapping.size
    if layer.mapping.alpha.len > 0: finiteColumns.add layer.mapping.alpha
    let paintMapping = if layer.mapping.fill.len > 0:
      layer.mapping.fill else: layer.mapping.color
    if paintMapping.len > 0 and
        spec.data.columns[paintMapping].kind == ckNumeric:
      finiteColumns.add paintMapping
    let rowFilter = spec.data.initRowFilter(finiteColumns)
    var points: seq[Point]
    var colors: seq[Color]
    var sizes: seq[float32]
    var shapes: seq[MarkerShape]
    var lineStyles: seq[LineStyle]
    var labels: seq[string]
    var breakBefore: seq[bool]
    var categoryColors = initTable[string, Color]()
    let categoricalPaintValues = if paintMapping.len > 0 and
        spec.data.columns[paintMapping].kind == ckCategorical:
      spec.data.categorical(paintMapping) else: @[]
    let numericPaintValues = if paintMapping.len > 0 and
        spec.data.columns[paintMapping].kind == ckNumeric:
      spec.data.numeric(paintMapping) else: @[]
    if categoricalPaintValues.len > 0:
      for entry in spec.categoricalEntries(layer, paintMapping):
        categoryColors[entry.category] = entry.color
    var paintScale: ContinuousScale
    if numericPaintValues.len > 0:
      paintScale = trainContinuous(numericPaintValues, 0, 1)
    let shapeValues = if layer.mapping.shape.len > 0:
      spec.data.categorical(layer.mapping.shape) else: @[]
    let lineStyleValues = if layer.mapping.lineStyle.len > 0:
      spec.data.categorical(layer.mapping.lineStyle) else: @[]
    let alphaValues = if layer.mapping.alpha.len > 0:
      spec.data.numeric(layer.mapping.alpha) else: @[]
    let sizeValues = if layer.mapping.size.len > 0:
      spec.data.numeric(layer.mapping.size) else: @[]
    let labelValues = if layer.mapping.label.len > 0:
      spec.data.categorical(layer.mapping.label) else: @[]
    var shapeMap = initTable[string, MarkerShape]()
    var lineStyleMap = initTable[string, LineStyle]()
    var alphaScale: ContinuousScale
    if alphaValues.len > 0:
      alphaScale = trainContinuous(alphaValues,
        spec.mappedAlphaRange.minimum, spec.mappedAlphaRange.maximum)
    var sizeScale: ContinuousScale
    if sizeValues.len > 0:
      sizeScale = trainContinuous(sizeValues, spec.mappedSizeRange.minimum,
        spec.mappedSizeRange.maximum)
    let fallbackSize = if layer.size > 0: layer.size else:
      case layer.mark
      of mkPoint: spec.theme.pointSize
      of mkLine: spec.theme.lineWidth
      of mkText: 12'f32
      of mkBar, mkArea: 0'f32
    var pendingBreak = false
    for row in 0 ..< spec.data.rowCount:
      if not rowFilter.rowIsFinite(row):
        case layer.missingValues
        of DropMissing:
          discard
        of BreakOnMissing:
          pendingBreak = true
        of RejectMissing:
          raise newException(PlotError,
            "layer contains a non-finite mapped value")
        continue
      let x = if xKind == ckNumeric:
        xScale.map(numericXs[row])
      else:
        xBand.map(categoricalXs[row])
      points.add Point(x: x, y: yScale.map(ys[row]))
      if layer.mark in {mkLine, mkArea}: breakBefore.add pendingBreak
      pendingBreak = false
      var paint = if categoricalPaintValues.len > 0:
        categoryColors[categoricalPaintValues[row]] else: layer.color
      if numericPaintValues.len > 0:
        let sampled = continuousSampler.sample(
          float64(paintScale.map(numericPaintValues[row])))
        if sampled.isErr:
          raise newException(PlotError,
            "cannot sample the continuous color palette")
        paint = sampled.get
      if alphaValues.len > 0:
        paint = paint.withOpacity(alphaScale.map(alphaValues[row]))
      colors.add paint
      if shapeValues.len > 0:
        if shapeValues[row] notin shapeMap:
          shapeMap[shapeValues[row]] = mappedShape(shapeMap.len)
        shapes.add shapeMap[shapeValues[row]]
      else:
        shapes.add layer.shape
      if lineStyleValues.len > 0:
        if lineStyleValues[row] notin lineStyleMap:
          lineStyleMap[lineStyleValues[row]] = mappedLineStyle(lineStyleMap.len)
        lineStyles.add lineStyleMap[lineStyleValues[row]]
      else:
        lineStyles.add layer.lineStyle
      sizes.add(if sizeValues.len > 0:
        sizeScale.map(sizeValues[row]) else: fallbackSize)
      if labelValues.len > 0: labels.add labelValues[row]
    case layer.mark
    of mkPoint:
      for i, point in points:
        result.addPath(markerPath(shapes[i], vec2(point.x, point.y),
          sizes[i] * 2'f32), colors[i], nodeId)
        inc nodeId
    of mkLine:
      let hasRowAesthetics = layer.mapping.color.len > 0 or
        layer.mapping.fill.len > 0 or
        layer.mapping.size.len > 0 or layer.mapping.alpha.len > 0 or
        layer.mapping.lineStyle.len > 0
      if not hasRowAesthetics and points.len > 1:
        var start = 0
        for stop in 1 .. points.len:
          if stop == points.len or breakBefore[stop]:
            if stop - start > 1:
              result.addPath(linePath(points.toOpenArray(start, stop - 1),
                sizes[start], lineStyles[start]), colors[start], nodeId)
              inc nodeId
            start = stop
      else:
        for i in 1 ..< points.len:
          if not breakBefore[i]:
            result.addPath(linePath([points[i - 1], points[i]], sizes[i],
              lineStyles[i]), colors[i], nodeId)
            inc nodeId
    of mkBar:
      let barWidth = if xKind == ckCategorical: xBand.bandwidth
        else: max(1'f32, area.width / float32(max(1, points.len)) * 0.8)
      let base = yScale.map(0.0)
      for i, point in points:
        var path = newPath()
        let width = if layer.mapping.size.len > 0: sizes[i] else: barWidth
        path.rect(point.x - width * 0.5, min(point.y, base), width,
          abs(base - point.y))
        result.addPath(path, colors[i], nodeId); inc nodeId
    of mkArea:
      if points.len > 0:
        let base = yScale.map(0.0)
        var start = 0
        for stop in 1 .. points.len:
          if stop == points.len or breakBefore[stop]:
            var areaPoints = newSeqOfCap[Point](stop - start + 2)
            for index in start ..< stop: areaPoints.add points[index]
            areaPoints.add Point(x: points[stop - 1].x, y: base)
            areaPoints.add Point(x: points[start].x, y: base)
            result.addPath(polygon(areaPoints), layer.color, nodeId)
            inc nodeId
            start = stop
    of mkText:
      if layer.mapping.label.len == 0:
        raise newException(PlotError, "text layers require a label mapping")
      for i, label in labels:
        result.addText(label, points[i], sizes[i],
          colors[i], nodeId); inc nodeId
  if legendEntries.len > 0 or continuousGuides.len > 0:
    let legendX = area.xMax + 24
    var legendY = area.yMin + 14
    if spec.legendSpec.title.len > 0:
      result.addText(spec.legendSpec.title, Point(x: legendX, y: legendY), 13,
        spec.theme.foreground)
      legendY += 24
    for entry in legendEntries:
      let center = Point(x: legendX + 10, y: legendY - 4)
      case entry.mark
      of mkLine:
        let width = if entry.size > 0: entry.size else: spec.theme.lineWidth
        result.addPath(linePath([Point(x: legendX, y: center.y),
          Point(x: legendX + 20, y: center.y)], width, entry.lineStyle),
          entry.color)
      of mkPoint:
        let radius = if entry.size > 0: entry.size else: spec.theme.pointSize
        result.addPath(markerPath(entry.shape, vec2(center.x, center.y),
          min(radius, 7'f32) * 2'f32), entry.color)
      of mkBar, mkArea:
        var swatch = newPath()
        swatch.rect(legendX + 2, center.y - 6, 16, 12)
        result.addPath(swatch, entry.color)
      of mkText:
        result.addText("T", Point(x: legendX + 4, y: legendY), 13,
          entry.color)
      result.addText(entry.label, Point(x: legendX + 30, y: legendY),
        12, spec.theme.foreground)
      legendY += 24
    const
      colorBarSteps = 24
      colorBarHeight = 120'f32
    for guide in continuousGuides:
      result.addText(guide.label, Point(x: legendX, y: legendY), 12,
        spec.theme.foreground)
      legendY += 18
      let barTop = legendY
      let stepHeight = colorBarHeight / float32(colorBarSteps)
      for index in 0 ..< colorBarSteps:
        let t = 1.0 - (float64(index) + 0.5) / float64(colorBarSteps)
        let sampled = guide.sampler.sample(t)
        if sampled.isErr:
          raise newException(PlotError,
            "cannot sample the continuous color guide")
        var swatch = newPath()
        swatch.rect(legendX, barTop + float32(index) * stepHeight,
          18, stepHeight)
        result.addPath(swatch, sampled.get)
      result.addText(tickLabel(guide.scale.domainMax),
        Point(x: legendX + 26, y: barTop + 10), 11, spec.theme.foreground)
      result.addText(tickLabel(guide.scale.domainMin),
        Point(x: legendX + 26, y: barTop + colorBarHeight), 11,
        spec.theme.foreground)
      legendY = barTop + colorBarHeight + 30
