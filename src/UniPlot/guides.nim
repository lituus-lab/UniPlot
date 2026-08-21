# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, tables]
import UniColor
import UniImage/core as ucore
import UniImage/process/resize as uresize
import UniImage/process/rotate as urotate
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

proc polarPoint(area: Bounds; xScale, yScale: ContinuousScale;
    angle, radius: float64): Point =
  let
    mappedAngle = xScale.map(angle)
    mappedRadius = yScale.map(radius)
    theta = 2.0 * PI * float64((mappedAngle - area.xMin) / area.width)
    radialRatio = (area.yMax - mappedRadius) / area.height
    screenRadius = min(area.width, area.height) * 0.5'f32 * radialRatio
    center = Point(x: (area.xMin + area.xMax) * 0.5'f32,
      y: (area.yMin + area.yMax) * 0.5'f32)
  result = Point(x: center.x + screenRadius * float32(sin(theta)),
    y: center.y - screenRadius * float32(cos(theta)))
  if not result.x.isFinite or not result.y.isFinite:
    raise newException(PlotError, "polar projection is not finite")

proc arrowPath(startPoint, endPoint: Point; width,
    requestedHeadSize: float32): Path =
  let
    dx = endPoint.x - startPoint.x
    dy = endPoint.y - startPoint.y
    length = sqrt(dx * dx + dy * dy)
  if length <= 0 or not length.isFinite:
    raise newException(PlotError, "arrow maps to a degenerate screen segment")
  let
    ux = dx / length
    uy = dy / length
    headLength = min(requestedHeadSize, length * 0.8'f32)
    halfHeadWidth = headLength * 0.55'f32
    base = Point(x: endPoint.x - ux * headLength,
      y: endPoint.y - uy * headLength)
    left = Point(x: base.x - uy * halfHeadWidth,
      y: base.y + ux * halfHeadWidth)
    right = Point(x: base.x + uy * halfHeadWidth,
      y: base.y - ux * halfHeadWidth)
  result = segmentPath(startPoint, base, width)
  result.addPath polygon([endPoint, left, right])

proc boxOutlinePath(centerX, boxWidth, lowerY, firstQuartileY, medianY,
    thirdQuartileY, upperY, strokeWidth: float32): Path =
  let
    left = centerX - boxWidth * 0.5
    right = centerX + boxWidth * 0.5
    capLeft = centerX - boxWidth * 0.25
    capRight = centerX + boxWidth * 0.25
  for (first, second) in [
      (Point(x: centerX, y: lowerY), Point(x: centerX, y: firstQuartileY)),
      (Point(x: centerX, y: thirdQuartileY), Point(x: centerX, y: upperY)),
      (Point(x: capLeft, y: lowerY), Point(x: capRight, y: lowerY)),
      (Point(x: capLeft, y: upperY), Point(x: capRight, y: upperY)),
      (Point(x: left, y: firstQuartileY), Point(x: right, y: firstQuartileY)),
      (Point(x: right, y: firstQuartileY), Point(x: right, y: thirdQuartileY)),
      (Point(x: right, y: thirdQuartileY), Point(x: left, y: thirdQuartileY)),
      (Point(x: left, y: thirdQuartileY), Point(x: left, y: firstQuartileY)),
      (Point(x: left, y: medianY), Point(x: right, y: medianY))]:
    result.addPath segmentPath(first, second, strokeWidth)

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

proc ringPath(center: Point; radius, width: float32): Path =
  const steps = 128
  var points = newSeqOfCap[Point](steps + 1)
  for index in 0 .. steps:
    let angle = 2.0 * PI * float64(index) / float64(steps)
    points.add Point(x: center.x + radius * float32(sin(angle)),
      y: center.y - radius * float32(cos(angle)))
  linePath(points, width, SolidLine)

proc errorBarPath(lower, upper: Point; capWidth, width: float32): Path =
  result = newPath()
  result.moveTo(lower.x, lower.y)
  result.lineTo(upper.x, upper.y)
  if capWidth > 0:
    let halfCap = capWidth * 0.5
    result.moveTo(lower.x - halfCap, lower.y)
    result.lineTo(lower.x + halfCap, lower.y)
    result.moveTo(upper.x - halfCap, upper.y)
    result.lineTo(upper.x + halfCap, upper.y)
  result = result.preparePath().strokeToPath(defaultStrokeStyle(width))

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

type AxisDomains* = object
  xKind*, yKind*: ColumnKind
  xContinuous*: ContinuousDomain
  xBand*: BandDomain
  yContinuous*: ContinuousDomain
  yBand*: BandDomain

proc collectAxisDomains*(spec: PlotSpec): AxisDomains =
  ## Accumulate every coordinate that must be representable by plot axes.
  if spec.layers.len == 0 and spec.rasters.len == 0:
    raise newException(PlotError, "plot has no layers")
  let firstX = if spec.layers.len > 0:
    (if spec.layers[0].mark in {mkRect, mkImage}:
      spec.layers[0].mapping.xMin else: spec.layers[0].mapping.x)
    else: ""
  if spec.layers.len > 0 and firstX notin spec.data.columns:
    raise newException(PlotError, "layer mapping references a missing column")
  result.xKind = if spec.layers.len > 0:
    spec.data.columns[firstX].kind else: ckNumeric
  if result.xKind == ckCategorical and (spec.xScaleSpec.kind != skLinear or
      spec.xScaleSpec.labelKind != alkNumeric):
    raise newException(PlotError,
      "categorical x coordinates require numeric labels on a linear scale")
  result.xContinuous = initContinuousDomain(spec.xScaleSpec.kind,
    spec.xScaleSpec.exponent)
  result.xBand = initBandDomain()
  let firstY = if spec.layers.len > 0:
    (if spec.layers[0].mark in {mkRect, mkImage}:
      spec.layers[0].mapping.yMin else: spec.layers[0].mapping.y)
    else: ""
  if spec.layers.len > 0 and
      spec.layers[0].mark in {mkErrorBar, mkRibbon, mkRect, mkImage}:
    result.yKind = ckNumeric
  elif spec.layers.len > 0:
    if firstY notin spec.data.columns:
      raise newException(PlotError, "layer mapping references a missing column")
    result.yKind = spec.data.columns[firstY].kind
  else:
    result.yKind = ckNumeric
  if result.yKind == ckCategorical and (spec.yScaleSpec.kind != skLinear or
      spec.yScaleSpec.labelKind != alkNumeric):
    raise newException(PlotError,
      "categorical y coordinates require numeric labels on a linear scale")
  result.yContinuous = initContinuousDomain(spec.yScaleSpec.kind,
    spec.yScaleSpec.exponent)
  result.yBand = initBandDomain()
  for reference in spec.references:
    if not reference.minimum.isFinite or not reference.maximum.isFinite or
        reference.minimum > reference.maximum or reference.width <= 0 or
        not reference.width.isFinite or
        (reference.kind in {rkXBand, rkYBand} and
        reference.minimum == reference.maximum):
      raise newException(PlotError, "invalid reference annotation")
    case reference.kind
    of rkXLine, rkXBand:
      if result.xKind != ckNumeric:
        raise newException(PlotError,
          "x references require numeric x coordinates")
      if spec.xScaleSpec.kind == skLog10 and reference.minimum <= 0:
        raise newException(PlotError,
          "logarithmic x references must be positive")
      result.xContinuous.addValues([reference.minimum, reference.maximum])
    of rkYLine, rkYBand:
      if result.yKind != ckNumeric:
        raise newException(PlotError,
          "y references require numeric y coordinates")
      if spec.yScaleSpec.kind == skLog10 and reference.minimum <= 0:
        raise newException(PlotError,
          "logarithmic y references must be positive")
      result.yContinuous.addValues([reference.minimum, reference.maximum])
  for annotation in spec.annotations:
    if not annotation.x.isFinite or not annotation.y.isFinite or
        annotation.size <= 0 or not annotation.size.isFinite:
      raise newException(PlotError, "invalid annotation")
    case annotation.kind
    of akText:
      if annotation.text.len == 0:
        raise newException(PlotError, "text annotation cannot be empty")
    of akArrow:
      if not annotation.xEnd.isFinite or not annotation.yEnd.isFinite or
          (annotation.x == annotation.xEnd and annotation.y ==
              annotation.yEnd) or
          annotation.headSize <= 0 or not annotation.headSize.isFinite:
        raise newException(PlotError, "invalid arrow annotation")
    if result.xKind != ckNumeric or result.yKind != ckNumeric:
      raise newException(PlotError,
        "annotations require numeric x and y coordinates")
    result.xContinuous.addValues([annotation.x])
    result.yContinuous.addValues([annotation.y])
    if annotation.kind == akArrow:
      result.xContinuous.addValues([annotation.xEnd])
      result.yContinuous.addValues([annotation.yEnd])
  for raster in spec.rasters:
    if result.xKind != ckNumeric or result.yKind != ckNumeric:
      raise newException(PlotError,
        "raster layers require numeric x and y coordinates")
    if not raster.image.validPackedImage or
        raster.image.colorspace notin {ucore.csGray, ucore.csRgb,
          ucore.csRgba} or
        not raster.xMin.isFinite or not raster.xMax.isFinite or
        raster.xMin >= raster.xMax or not raster.yMin.isFinite or
        not raster.yMax.isFinite or raster.yMin >= raster.yMax:
      raise newException(PlotError, "invalid raster layer")
    if spec.xScaleSpec.kind != skLinear or spec.yScaleSpec.kind != skLinear:
      raise newException(PlotError,
        "raster layers currently require linear x and y scales")
    result.xContinuous.addValues([raster.xMin, raster.xMax])
    result.yContinuous.addValues([raster.yMin, raster.yMax])
  var includeZero = false
  for layer in spec.layers:
    let xMapping = if layer.mark in {mkRect, mkImage}:
      layer.mapping.xMin else: layer.mapping.x
    if xMapping notin spec.data.columns:
      raise newException(PlotError, "layer mapping references a missing column")
    if layer.mark == mkTile and
        (spec.data.columns[layer.mapping.x].kind != ckCategorical or
        layer.mapping.y notin spec.data.columns or
        spec.data.columns[layer.mapping.y].kind != ckCategorical):
      raise newException(PlotError,
        "tile layers require categorical x and y coordinates")
    if layer.mark == mkPolygon and
        spec.data.columns[xMapping].kind != ckNumeric and
        layer.mapping.xOffset.len == 0:
      raise newException(PlotError,
        "categorical polygon coordinates require numeric x offsets")
    if spec.data.columns[xMapping].kind != result.xKind:
      raise newException(PlotError, "all x mappings must use the same column kind")
    if layer.mark in {mkRect, mkImage}:
      for mapping in [layer.mapping.xMin, layer.mapping.xMax]:
        if mapping notin spec.data.columns or
            spec.data.columns[mapping].kind != ckNumeric:
          raise newException(PlotError,
            "bounded x coordinates must reference numeric columns")
        if layer.mark == mkRect:
          result.xContinuous.addValues(spec.data.numeric(mapping))
    elif result.xKind == ckNumeric:
      result.xContinuous.addValues(spec.data.numeric(xMapping))
    else:
      result.xBand.addValues(spec.data.categorical(xMapping))
    if layer.mark notin {mkErrorBar, mkRibbon, mkRect, mkImage} and
        (layer.mapping.y notin spec.data.columns or
        spec.data.columns[layer.mapping.y].kind != result.yKind):
      raise newException(PlotError,
        "all y mappings must use the same column kind")
    if result.yKind == ckCategorical:
      if layer.mark != mkTile or result.xKind != ckCategorical:
        raise newException(PlotError,
          "categorical y coordinates require categorical tile layers")
      result.yBand.addValues(spec.data.categorical(layer.mapping.y))
      continue
    if layer.mark in {mkErrorBar, mkRibbon, mkBoxPlot, mkRect, mkImage}:
      for mapping in [layer.mapping.yMin, layer.mapping.yMax]:
        if mapping notin spec.data.columns or
            spec.data.columns[mapping].kind != ckNumeric:
          raise newException(PlotError,
            "bounded y coordinates must reference numeric columns")
        if layer.mark != mkImage:
          result.yContinuous.addValues(spec.data.numeric(mapping))
      if layer.mark == mkBoxPlot:
        for mapping in [layer.mapping.y, layer.mapping.yQ1, layer.mapping.yQ3]:
          if mapping notin spec.data.columns or
              spec.data.columns[mapping].kind != ckNumeric:
            raise newException(PlotError,
              "box-plot statistics must reference numeric columns")
          result.yContinuous.addValues(spec.data.numeric(mapping))
      if layer.mark == mkImage:
        if spec.xScaleSpec.kind != skLinear or
            spec.yScaleSpec.kind != skLinear:
          raise newException(PlotError,
            "image marks currently require linear x and y scales")
        if layer.mapping.image notin spec.data.columns or
            spec.data.columns[layer.mapping.image].kind != ckCategorical:
          raise newException(PlotError,
            "image mappings must reference categorical columns")
        let
          xMinValues = spec.data.numeric(layer.mapping.xMin)
          xMaxValues = spec.data.numeric(layer.mapping.xMax)
          yMinValues = spec.data.numeric(layer.mapping.yMin)
          yMaxValues = spec.data.numeric(layer.mapping.yMax)
          filter = spec.data.initRowFilter([layer.mapping.xMin,
            layer.mapping.xMax, layer.mapping.yMin, layer.mapping.yMax])
        for row in 0 ..< spec.data.rowCount:
          if filter.rowIsFinite(row):
            result.xContinuous.addValues([xMinValues[row], xMaxValues[row]])
            result.yContinuous.addValues([yMinValues[row], yMaxValues[row]])
          elif layer.missingValues == RejectMissing:
            raise newException(PlotError,
              "image mark contains a non-finite mapped bound")
    else:
      if layer.mapping.y notin spec.data.columns or
          spec.data.columns[layer.mapping.y].kind != ckNumeric:
        raise newException(PlotError, "y mappings must reference numeric columns")
      result.yContinuous.addValues(spec.data.numeric(layer.mapping.y))
    includeZero = includeZero or layer.mark in {mkBar, mkArea}
  if includeZero:
    result.yContinuous.addValues([0.0])
  if includeZero and spec.yScaleSpec.kind == skLog10:
    raise newException(PlotError,
      "bar and area layers require a linear y scale with a zero baseline")
  if spec.coordinates == PolarCoordinates:
    for layer in spec.layers:
      for value in spec.data.numeric(layer.mapping.y):
        if value.isFinite and value < 0.0:
          raise newException(PlotError,
            "polar radii must be non-negative")
    for annotation in spec.annotations:
      if annotation.y < 0.0 or
          (annotation.kind == akArrow and annotation.yEnd < 0.0):
        raise newException(PlotError,
          "polar annotation radii must be non-negative")
    result.yContinuous.addValues([0.0])

proc compileScene*(spec: PlotSpec; size = Size(width: 800,
    height: 500)): Scene =
  size.validate()
  if spec.layers.len == 0 and spec.rasters.len == 0:
    raise newException(PlotError, "plot has no layers")
  for margin in [spec.theme.margins.left, spec.theme.margins.top,
      spec.theme.margins.right, spec.theme.margins.bottom]:
    if margin < 0 or not margin.isFinite:
      raise newException(PlotError, "plot margins must be finite and non-negative")
  if spec.theme.pointSize <= 0 or not spec.theme.pointSize.isFinite or
      spec.theme.lineWidth <= 0 or not spec.theme.lineWidth.isFinite:
    raise newException(PlotError,
      "theme point size and line width must be finite and positive")
  if spec.mappedSizeRange.minimum <= 0 or
      not spec.mappedSizeRange.minimum.isFinite or
      spec.mappedSizeRange.maximum < spec.mappedSizeRange.minimum or
      not spec.mappedSizeRange.maximum.isFinite:
    raise newException(PlotError,
      "size range must be finite, positive and ordered")
  if spec.mappedAlphaRange.minimum < 0 or
      not spec.mappedAlphaRange.minimum.isFinite or
      spec.mappedAlphaRange.maximum < spec.mappedAlphaRange.minimum or
      spec.mappedAlphaRange.maximum > 1 or
      not spec.mappedAlphaRange.maximum.isFinite:
    raise newException(PlotError,
      "alpha range must be finite, ordered and within [0, 1]")
  if spec.coordinates == PolarCoordinates:
    if spec.rasters.len > 0 or spec.references.len > 0 or
        spec.imageResources.len > 0 or spec.secondaryYSpec.enabled:
      raise newException(PlotError,
        "polar coordinates do not support rasters, references, image resources or secondary axes")
    if spec.xScaleSpec.kind != skLinear or
        spec.xScaleSpec.labelKind != alkNumeric or
        spec.yScaleSpec.labelKind != alkNumeric:
      raise newException(PlotError,
        "polar coordinates require a linear numeric angle axis and numeric radial labels")
    if spec.xScaleSpec.domain.configured and
        (spec.xScaleSpec.domain.minimum != 0.0 or
        spec.xScaleSpec.domain.maximum != 2.0 * PI):
      raise newException(PlotError,
        "polar angular limits must remain [0, 2*pi]")
    if spec.yScaleSpec.kind == skLog10:
      raise newException(PlotError,
        "polar radii cannot use a logarithmic scale because radius zero is required")
    if spec.yScaleSpec.domain.configured and
        spec.yScaleSpec.domain.minimum != 0.0:
      raise newException(PlotError,
        "explicit polar radial limits must start at zero")
    for layer in spec.layers:
      if layer.mark notin {mkLine, mkPoint, mkText}:
        raise newException(PlotError,
          "polar coordinates currently support line, point and text marks")
  var usesContinuousColors = false
  var imageResourceIndices = initTable[string, int]()
  for index, resource in spec.imageResources:
    if resource.name.len == 0 or resource.name in imageResourceIndices or
        not resource.image.validPackedImage or
        resource.image.colorspace notin {ucore.csGray, ucore.csRgb,
          ucore.csRgba}:
      raise newException(PlotError, "invalid image resource registry")
    imageResourceIndices[resource.name] = index
  for layer in spec.layers:
    let bounded = layer.mark in {mkErrorBar, mkRibbon, mkBoxPlot, mkRect,
      mkImage}
    if layer.size < 0 or not layer.size.isFinite:
      raise newException(PlotError,
        "mark size must be finite and non-negative")
    if layer.mark == mkErrorBar and
        (layer.capWidth < 0 or not layer.capWidth.isFinite):
      raise newException(PlotError,
        "error-bar cap width must be finite and non-negative")
    if layer.mark == mkBoxPlot and (layer.boxWidth <= 0 or
        layer.boxWidth > 1 or not layer.boxWidth.isFinite or layer.size <= 0):
      raise newException(PlotError, "invalid box-plot dimensions")
    let xMapping = if layer.mark in {mkRect, mkImage}:
      layer.mapping.xMin else: layer.mapping.x
    if xMapping notin spec.data.columns:
      raise newException(PlotError, "layer mapping references a missing column")
    if layer.mark in {mkRect, mkImage}:
      for mapping in [layer.mapping.xMin, layer.mapping.xMax]:
        if mapping notin spec.data.columns or
            spec.data.columns[mapping].kind != ckNumeric:
          raise newException(PlotError,
            "bounded x coordinates must reference numeric columns")
    if bounded:
      for mapping in [layer.mapping.yMin, layer.mapping.yMax]:
        if mapping notin spec.data.columns or
            spec.data.columns[mapping].kind != ckNumeric:
          raise newException(PlotError,
            "bounded y coordinates must reference numeric columns")
      if layer.mark == mkBoxPlot:
        for mapping in [layer.mapping.y, layer.mapping.yQ1, layer.mapping.yQ3]:
          if mapping notin spec.data.columns or
              spec.data.columns[mapping].kind != ckNumeric:
            raise newException(PlotError,
              "box-plot statistics must reference numeric columns")
    elif layer.mapping.y notin spec.data.columns:
      raise newException(PlotError, "layer mapping references a missing column")
    elif layer.mark != mkTile and
        spec.data.columns[layer.mapping.y].kind != ckNumeric:
      raise newException(PlotError, "y mappings must reference numeric columns")
    if layer.mapping.color.len > 0 and
        layer.mapping.color notin spec.data.columns:
      raise newException(PlotError,
        "color mappings must reference an existing column")
    if layer.mapping.fill.len > 0 and
        (layer.mark notin {mkPoint, mkBar, mkTile, mkRect} or
        layer.mapping.fill notin spec.data.columns):
      raise newException(PlotError,
        "fill mappings require a supported filled mark and existing column")
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
    if layer.mapping.xOffset.len > 0 and
        (layer.mark != mkPolygon or
        spec.data.columns[xMapping].kind != ckCategorical or
        layer.mapping.xOffset notin spec.data.columns or
        spec.data.columns[layer.mapping.xOffset].kind != ckNumeric):
      raise newException(PlotError,
        "x offsets require numeric categorical-polygon coordinates")
    if layer.mark in {mkArea, mkRibbon, mkPolygon} and
        (layer.mapping.color.len > 0 or
        layer.mapping.fill.len > 0 or
        layer.mapping.size.len > 0 or layer.mapping.alpha.len > 0 or
        layer.mapping.shape.len > 0 or layer.mapping.lineStyle.len > 0):
      raise newException(PlotError,
        "area, ribbon and polygon layers do not support per-row aesthetic mappings")
    if layer.mark == mkText and (layer.mapping.label.len == 0 or
        layer.mapping.label notin spec.data.columns or
        spec.data.columns[layer.mapping.label].kind != ckCategorical):
      raise newException(PlotError,
        "text label mappings must reference categorical columns")
    if layer.mark == mkImage and
        (layer.mapping.image.len == 0 or
        layer.mapping.image notin spec.data.columns or
        spec.data.columns[layer.mapping.image].kind != ckCategorical):
      raise newException(PlotError,
        "image mappings must reference categorical columns")
    if layer.mark == mkImage and (layer.mapping.color.len > 0 or
        layer.mapping.fill.len > 0 or layer.mapping.size.len > 0 or
        layer.mapping.alpha.len > 0 or layer.mapping.shape.len > 0 or
        layer.mapping.lineStyle.len > 0 or layer.mapping.label.len > 0):
      raise newException(PlotError,
        "image marks only support bounds and image-resource mappings")
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
  const secondaryAxisWidth = 80'f32
  if spec.secondaryYSpec.enabled:
    if not spec.secondaryYSpec.scale.isFinite or
        spec.secondaryYSpec.scale == 0 or
        not spec.secondaryYSpec.offset.isFinite:
      raise newException(PlotError,
        "secondary y transform must be finite with a non-zero scale")
    area.xMax -= secondaryAxisWidth
  if area.width <= 0 or area.height <= 0:
    raise newException(PlotError, "plot margins leave no drawing area")
  let legendHeight = float32(legendEntries.len * 24 +
    continuousGuides.len * 168 + ord(spec.legendSpec.title.len > 0) * 24)
  if legendHeight > area.height:
    raise newException(PlotError, "legend does not fit the drawing height")
  let domains = collectAxisDomains(spec)
  let
    xKind = domains.xKind
    yKind = domains.yKind
  if spec.coordinates == PolarCoordinates and
      (xKind != ckNumeric or yKind != ckNumeric):
    raise newException(PlotError,
      "polar coordinates require numeric angle and radius columns")
  var xScale: ContinuousScale
  var xBand: BandScale
  var yScale: ContinuousScale
  var yBand: BandScale
  let
    xRangeMin = if spec.xScaleSpec.reversed: area.xMax else: area.xMin
    xRangeMax = if spec.xScaleSpec.reversed: area.xMin else: area.xMax
    yRangeMin = if spec.yScaleSpec.reversed: area.yMin else: area.yMax
    yRangeMax = if spec.yScaleSpec.reversed: area.yMax else: area.yMin
  if xKind == ckCategorical and spec.xScaleSpec.domain.configured:
    raise newException(PlotError,
      "numeric x limits cannot be applied to categorical coordinates")
  if xKind == ckNumeric and spec.xScaleSpec.categories.configured:
    raise newException(PlotError,
      "categorical x domain cannot be applied to numeric coordinates")
  if xKind == ckNumeric and spec.coordinates == PolarCoordinates:
    xScale = domains.xContinuous.train(xRangeMin, xRangeMax, 0.0, 2.0 * PI)
  elif xKind == ckNumeric and spec.xScaleSpec.domain.configured:
    xScale = domains.xContinuous.train(xRangeMin, xRangeMax,
      spec.xScaleSpec.domain.minimum, spec.xScaleSpec.domain.maximum)
  elif xKind == ckNumeric:
    xScale = domains.xContinuous.trainAxis(xRangeMin, xRangeMax,
      spec.xScaleSpec.labelKind)
  else:
    xBand = if spec.xScaleSpec.categories.configured:
      domains.xBand.train(xRangeMin, xRangeMax,
        spec.xScaleSpec.categories.values)
    else:
      domains.xBand.train(xRangeMin, xRangeMax)
  if xKind == ckNumeric:
    xScale.validateAxisLabels(spec.xScaleSpec.labelKind)
  if yKind == ckCategorical and spec.yScaleSpec.domain.configured:
    raise newException(PlotError,
      "numeric y limits cannot be applied to categorical coordinates")
  if yKind == ckNumeric and spec.yScaleSpec.categories.configured:
    raise newException(PlotError,
      "categorical y domain cannot be applied to numeric coordinates")
  if yKind == ckNumeric and spec.yScaleSpec.domain.configured:
    yScale = domains.yContinuous.train(yRangeMin, yRangeMax,
      spec.yScaleSpec.domain.minimum, spec.yScaleSpec.domain.maximum)
  elif yKind == ckNumeric and spec.coordinates == PolarCoordinates:
    let radialBounds = domains.yContinuous.fittedBounds
    yScale = domains.yContinuous.train(yRangeMin, yRangeMax, 0.0,
      if radialBounds.maximum > 0.0: radialBounds.maximum else: 1.0)
  elif yKind == ckNumeric:
    yScale = domains.yContinuous.trainAxis(yRangeMin, yRangeMax,
      spec.yScaleSpec.labelKind)
  else:
    yBand = if spec.yScaleSpec.categories.configured:
      domains.yBand.train(yRangeMin, yRangeMax,
        spec.yScaleSpec.categories.values)
    else:
      domains.yBand.train(yRangeMin, yRangeMax)
  if yKind == ckNumeric:
    yScale.validateAxisLabels(spec.yScaleSpec.labelKind)
  if spec.secondaryYSpec.enabled and spec.yScaleSpec.labelKind != alkNumeric:
    raise newException(PlotError,
      "secondary y guides cannot relabel a temporal primary axis")
  var nodeId = 1'u64
  for raster in spec.rasters:
    let
      mappedX0 = xScale.map(raster.xMin)
      mappedX1 = xScale.map(raster.xMax)
      mappedY0 = yScale.map(raster.yMin)
      mappedY1 = yScale.map(raster.yMax)
      pixelX = int(round(min(mappedX0, mappedX1)))
      pixelY = int(round(min(mappedY0, mappedY1)))
      pixelWidth = max(1, int(round(abs(mappedX1 - mappedX0))))
      pixelHeight = max(1, int(round(abs(mappedY1 - mappedY0))))
      filter = case raster.filter
        of RasterNearest: uresize.rfNearest
        of RasterBilinear: uresize.rfBilinear
        of RasterBox: uresize.rfBox
    var resized = uresize.resize(raster.image, pixelWidth, pixelHeight, filter)
    if mappedX1 < mappedX0:
      resized = urotate.rotate(resized, urotate.flipH)
    if mappedY1 > mappedY0:
      resized = urotate.rotate(resized, urotate.flipV)
    result.addImage(resized, pixelX, pixelY, id = nodeId)
    inc nodeId
  if spec.coordinates == PolarCoordinates:
    let
      center = Point(x: (area.xMin + area.xMax) * 0.5'f32,
        y: (area.yMin + area.yMax) * 0.5'f32)
      outerRadius = min(area.width, area.height) * 0.5'f32
    for index in 0 ..< 8:
      let
        angle = float64(index) * PI / 4.0
        edge = polarPoint(area, xScale, yScale, angle, yScale.domainMax)
        labelPoint = Point(x: center.x + (edge.x - center.x) * 1.08'f32,
          y: center.y + (edge.y - center.y) * 1.08'f32)
        label = case index
          of 0: "0"
          of 1: "pi/4"
          of 2: "pi/2"
          of 3: "3pi/4"
          of 4: "pi"
          of 5: "5pi/4"
          of 6: "3pi/2"
          else: "7pi/4"
      result.addPath(segmentPath(center, edge, 1), spec.theme.gridColor)
      result.addText(label, labelPoint, 11, spec.theme.foreground,
        anchor = textMiddle)
    for value in yScale.axisTicks(spec.yScaleSpec.labelKind):
      if value < 0.0: continue
      let mapped = yScale.map(value)
      let radius = outerRadius * (area.yMax - mapped) / area.height
      if radius > 0.0:
        result.addPath(ringPath(center, radius, 1), spec.theme.gridColor)
      result.addText(yScale.axisTickLabel(value, spec.yScaleSpec.labelKind),
        Point(x: center.x + 4, y: center.y - radius - 3), 11,
        spec.theme.foreground)
  elif xKind == ckNumeric:
    for value in xScale.axisTicks(spec.xScaleSpec.labelKind):
      let x = xScale.map(value)
      result.addPath(segmentPath(Point(x: x, y: area.yMin),
        Point(x: x, y: area.yMax), 1), spec.theme.gridColor)
      result.addText(xScale.axisTickLabel(value, spec.xScaleSpec.labelKind),
        Point(x: x, y: area.yMax + 20), 11,
        spec.theme.foreground, anchor = textMiddle)
  else:
    for value in xBand.domain:
      result.addText(value, Point(x: xBand.map(value), y: area.yMax + 20), 11,
        spec.theme.foreground, anchor = textMiddle)
  if spec.coordinates == PolarCoordinates:
    discard
  elif yKind == ckNumeric:
    for value in yScale.axisTicks(spec.yScaleSpec.labelKind):
      let y = yScale.map(value)
      result.addPath(segmentPath(Point(x: area.xMin, y: y),
        Point(x: area.xMax, y: y), 1), spec.theme.gridColor)
      result.addText(yScale.axisTickLabel(value, spec.yScaleSpec.labelKind),
        Point(x: 5, y: y), 11,
        spec.theme.foreground)
      if spec.secondaryYSpec.enabled:
        let secondaryValue = value * spec.secondaryYSpec.scale +
          spec.secondaryYSpec.offset
        if not secondaryValue.isFinite:
          raise newException(PlotError,
            "secondary y transform produced a non-finite tick")
        result.addText(tickLabel(secondaryValue),
          Point(x: area.xMax + 8, y: y), 11, spec.theme.foreground)
  else:
    if spec.secondaryYSpec.enabled:
      raise newException(PlotError,
        "secondary y guides require numeric y coordinates")
    for value in yBand.domain:
      result.addText(value, Point(x: 5, y: yBand.map(value)), 11,
        spec.theme.foreground)
  if spec.title.len > 0:
    result.addText(spec.title, Point(x: area.xMin, y: 25), 18,
      spec.theme.foreground)
  if spec.xLabel.len > 0:
    result.addText(spec.xLabel, Point(x: (area.xMin + area.xMax) * 0.5,
      y: float32(size.height) - 20), 13, spec.theme.foreground,
      anchor = textMiddle)
  if spec.yLabel.len > 0:
    result.addText(spec.yLabel, Point(x: 5, y: area.yMin - 20), 13,
      spec.theme.foreground)
  if spec.secondaryYSpec.enabled and spec.secondaryYSpec.label.len > 0:
    result.addText(spec.secondaryYSpec.label,
      Point(x: area.xMax + secondaryAxisWidth - 5, y: area.yMin - 20), 13,
      spec.theme.foreground, anchor = textEnd)
  for reference in spec.references:
    case reference.kind
    of rkXLine:
      let x = xScale.map(reference.minimum)
      result.addPath(segmentPath(Point(x: x, y: area.yMin),
        Point(x: x, y: area.yMax), reference.width), reference.color, nodeId)
      inc nodeId
      if reference.label.len > 0:
        result.addText(reference.label, Point(x: x + 4, y: area.yMin + 14),
          11, reference.color)
    of rkYLine:
      let y = yScale.map(reference.minimum)
      result.addPath(segmentPath(Point(x: area.xMin, y: y),
        Point(x: area.xMax, y: y), reference.width), reference.color, nodeId)
      inc nodeId
      if reference.label.len > 0:
        result.addText(reference.label, Point(x: area.xMin + 4, y: y - 4),
          11, reference.color)
    of rkXBand:
      let
        first = xScale.map(reference.minimum)
        second = xScale.map(reference.maximum)
      var band = newPath()
      band.rect(min(first, second), area.yMin, abs(second - first), area.height)
      result.addPath(band, reference.color, nodeId)
      inc nodeId
      if reference.label.len > 0:
        result.addText(reference.label,
          Point(x: min(first, second) + 4, y: area.yMin + 14), 11,
          reference.color)
    of rkYBand:
      let
        first = yScale.map(reference.minimum)
        second = yScale.map(reference.maximum)
      var band = newPath()
      band.rect(area.xMin, min(first, second), area.width, abs(second - first))
      result.addPath(band, reference.color, nodeId)
      inc nodeId
      if reference.label.len > 0:
        result.addText(reference.label,
          Point(x: area.xMin + 4, y: min(first, second) + 14), 11,
          reference.color)
  for layer in spec.layers:
    let
      bounded = layer.mark in {mkErrorBar, mkRibbon, mkBoxPlot, mkRect,
        mkImage}
      ys = if yKind == ckNumeric and
          (not bounded or layer.mark == mkBoxPlot):
        spec.data.numeric(layer.mapping.y) else: @[]
      categoricalYs = if yKind == ckCategorical:
        spec.data.categorical(layer.mapping.y) else: @[]
      lowerValues = if bounded: spec.data.numeric(layer.mapping.yMin) else: @[]
      upperValues = if bounded: spec.data.numeric(layer.mapping.yMax) else: @[]
      firstQuartileValues = if layer.mark == mkBoxPlot:
        spec.data.numeric(layer.mapping.yQ1) else: @[]
      thirdQuartileValues = if layer.mark == mkBoxPlot:
        spec.data.numeric(layer.mapping.yQ3) else: @[]
      numericXs = if xKind == ckNumeric and
          layer.mark notin {mkRect, mkImage}:
        spec.data.numeric(layer.mapping.x)
      else:
        @[]
      categoricalXs = if xKind == ckCategorical and
          layer.mark notin {mkRect, mkImage}:
        spec.data.categorical(layer.mapping.x)
      else:
        @[]
      xLowerValues = if layer.mark in {mkRect, mkImage}:
        spec.data.numeric(layer.mapping.xMin) else: @[]
      xUpperValues = if layer.mark in {mkRect, mkImage}:
        spec.data.numeric(layer.mapping.xMax) else: @[]
      xOffsetValues = if layer.mapping.xOffset.len > 0:
        spec.data.numeric(layer.mapping.xOffset) else: @[]
    var finiteColumns = if layer.mark in {mkRect, mkImage}:
      @[layer.mapping.xMin, layer.mapping.xMax] else: @[layer.mapping.x]
    if bounded:
      finiteColumns.add layer.mapping.yMin
      finiteColumns.add layer.mapping.yMax
      if layer.mark == mkBoxPlot:
        finiteColumns.add layer.mapping.y
        finiteColumns.add layer.mapping.yQ1
        finiteColumns.add layer.mapping.yQ3
    else:
      finiteColumns.add layer.mapping.y
    if layer.mapping.size.len > 0: finiteColumns.add layer.mapping.size
    if layer.mapping.alpha.len > 0: finiteColumns.add layer.mapping.alpha
    if layer.mapping.xOffset.len > 0: finiteColumns.add layer.mapping.xOffset
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
    var imageNames: seq[string]
    var breakBefore: seq[bool]
    var lowerPoints, upperPoints, firstQuartilePoints, thirdQuartilePoints:
      seq[Point]
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
    let imageValues = if layer.mark == mkImage:
      spec.data.categorical(layer.mapping.image) else: @[]
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
      of mkLine, mkErrorBar, mkBoxPlot: spec.theme.lineWidth
      of mkText: 12'f32
      of mkBar, mkArea, mkRibbon, mkTile, mkRect, mkImage, mkPolygon: 0'f32
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
      let x = if layer.mark in {mkRect, mkImage}:
        (xScale.map(xLowerValues[row]) + xScale.map(xUpperValues[row])) * 0.5
      elif xKind == ckNumeric:
        xScale.map(numericXs[row])
      else:
        xBand.map(categoricalXs[row]) + (if xOffsetValues.len > 0:
          float32(xOffsetValues[row]) * xBand.bandwidth else: 0'f32)
      if bounded:
        if lowerValues[row] > upperValues[row] or
            (layer.mark in {mkRect, mkImage} and
              xLowerValues[row] >= xUpperValues[row]):
          raise newException(PlotError,
            "rectangle x bounds must increase and y bounds must be ordered")
        if layer.mark == mkBoxPlot and
            (lowerValues[row] > firstQuartileValues[row] or
            firstQuartileValues[row] > ys[row] or
            ys[row] > thirdQuartileValues[row] or
            thirdQuartileValues[row] > upperValues[row]):
          raise newException(PlotError,
            "box-plot statistics must be monotonically ordered")
        let
          lowerX = if layer.mark in {mkRect, mkImage}:
            xScale.map(xLowerValues[row]) else: x
          upperX = if layer.mark in {mkRect, mkImage}:
            xScale.map(xUpperValues[row]) else: x
          lower = Point(x: lowerX, y: yScale.map(lowerValues[row]))
          upper = Point(x: upperX, y: yScale.map(upperValues[row]))
        lowerPoints.add lower
        upperPoints.add upper
        if layer.mark == mkBoxPlot:
          points.add Point(x: x, y: yScale.map(ys[row]))
          firstQuartilePoints.add Point(x: x,
            y: yScale.map(firstQuartileValues[row]))
          thirdQuartilePoints.add Point(x: x,
            y: yScale.map(thirdQuartileValues[row]))
        else:
          points.add Point(x: x, y: (lower.y + upper.y) * 0.5)
      else:
        let y = if yKind == ckNumeric: yScale.map(ys[row]) else:
          yBand.map(categoricalYs[row])
        points.add(if spec.coordinates == PolarCoordinates:
          polarPoint(area, xScale, yScale, numericXs[row], ys[row])
        else:
          Point(x: x, y: y))
      if layer.mark in {mkLine, mkArea, mkRibbon, mkPolygon}:
        breakBefore.add pendingBreak
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
      if imageValues.len > 0: imageNames.add imageValues[row]
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
    of mkPolygon:
      if points.len > 0:
        var start = 0
        for stop in 1 .. points.len:
          if stop == points.len or breakBefore[stop]:
            if stop - start < 3:
              raise newException(PlotError,
                "polygon segments require at least three finite vertices")
            result.addPath(polygon(points.toOpenArray(start, stop - 1)),
              layer.color, nodeId)
            inc nodeId
            start = stop
    of mkText:
      if layer.mapping.label.len == 0:
        raise newException(PlotError, "text layers require a label mapping")
      for i, label in labels:
        result.addText(label, points[i], sizes[i],
          colors[i], nodeId); inc nodeId
    of mkErrorBar:
      for index in 0 ..< lowerPoints.len:
        result.addPath(errorBarPath(lowerPoints[index], upperPoints[index],
          layer.capWidth, sizes[index]), colors[index], nodeId)
        inc nodeId
    of mkRibbon:
      if lowerPoints.len > 0:
        var start = 0
        for stop in 1 .. lowerPoints.len:
          if stop == lowerPoints.len or breakBefore[stop]:
            if stop - start > 1:
              var ribbon = newSeqOfCap[Point]((stop - start) * 2)
              for index in start ..< stop:
                ribbon.add upperPoints[index]
              for index in countdown(stop - 1, start):
                ribbon.add lowerPoints[index]
              result.addPath(polygon(ribbon), layer.color, nodeId)
              inc nodeId
            start = stop
    of mkBoxPlot:
      let availableWidth = if xKind == ckCategorical: xBand.bandwidth else:
        max(1'f32, area.width / float32(max(1, points.len)) * 0.8)
      let boxWidth = availableWidth * layer.boxWidth
      for index, point in points:
        let
          firstQuartileY = firstQuartilePoints[index].y
          thirdQuartileY = thirdQuartilePoints[index].y
        var fill = newPath()
        fill.rect(point.x - boxWidth * 0.5,
          min(firstQuartileY, thirdQuartileY), boxWidth,
          abs(thirdQuartileY - firstQuartileY))
        result.addPath(fill, colors[index].withOpacity(0.18), nodeId)
        inc nodeId
        result.addPath(boxOutlinePath(point.x, boxWidth,
          lowerPoints[index].y, firstQuartileY, point.y, thirdQuartileY,
          upperPoints[index].y, sizes[index]), colors[index], nodeId)
        inc nodeId
    of mkTile:
      for index, point in points:
        var tile = newPath()
        tile.rect(point.x - xBand.bandwidth * 0.5,
          point.y - yBand.bandwidth * 0.5,
          xBand.bandwidth, yBand.bandwidth)
        result.addPath(tile, colors[index], nodeId)
        inc nodeId
    of mkRect:
      for index in 0 ..< lowerPoints.len:
        var rectangle = newPath()
        rectangle.rect(min(lowerPoints[index].x, upperPoints[index].x),
          min(lowerPoints[index].y, upperPoints[index].y),
          abs(upperPoints[index].x - lowerPoints[index].x),
          abs(upperPoints[index].y - lowerPoints[index].y))
        result.addPath(rectangle, colors[index], nodeId)
        inc nodeId
    of mkImage:
      for index in 0 ..< lowerPoints.len:
        if imageNames[index] notin imageResourceIndices:
          raise newException(PlotError,
            "image mark references an unknown image resource")
        let resourceIndex = imageResourceIndices[imageNames[index]]
        let
          mappedX0 = lowerPoints[index].x
          mappedX1 = upperPoints[index].x
          mappedY0 = lowerPoints[index].y
          mappedY1 = upperPoints[index].y
          pixelX = int(round(min(mappedX0, mappedX1)))
          pixelY = int(round(min(mappedY0, mappedY1)))
          pixelWidth = max(1, int(round(abs(mappedX1 - mappedX0))))
          pixelHeight = max(1, int(round(abs(mappedY1 - mappedY0))))
          filter = case layer.imageFilter
            of RasterNearest: uresize.rfNearest
            of RasterBilinear: uresize.rfBilinear
            of RasterBox: uresize.rfBox
        var resized = uresize.resize(spec.imageResources[resourceIndex].image,
          pixelWidth, pixelHeight, filter)
        if mappedX1 < mappedX0:
          resized = urotate.rotate(resized, urotate.flipH)
        if mappedY1 > mappedY0:
          resized = urotate.rotate(resized, urotate.flipV)
        result.addImage(resized, pixelX, pixelY, id = nodeId)
        inc nodeId
  for annotation in spec.annotations:
    let startPoint = if spec.coordinates == PolarCoordinates:
      polarPoint(area, xScale, yScale, annotation.x, annotation.y)
    else:
      Point(x: xScale.map(annotation.x), y: yScale.map(annotation.y))
    case annotation.kind
    of akText:
      result.addText(annotation.text, startPoint, annotation.size,
        annotation.color, nodeId)
      inc nodeId
    of akArrow:
      let endPoint = if spec.coordinates == PolarCoordinates:
        polarPoint(area, xScale, yScale, annotation.xEnd, annotation.yEnd)
      else:
        Point(x: xScale.map(annotation.xEnd), y: yScale.map(annotation.yEnd))
      result.addPath(arrowPath(startPoint, endPoint, annotation.size,
        annotation.headSize), annotation.color, nodeId)
      inc nodeId

  if legendEntries.len > 0 or continuousGuides.len > 0:
    let legendX = area.xMax +
      (if spec.secondaryYSpec.enabled: secondaryAxisWidth else: 0'f32) + 24
    var legendY = area.yMin + 14
    if spec.legendSpec.title.len > 0:
      result.addText(spec.legendSpec.title, Point(x: legendX, y: legendY), 13,
        spec.theme.foreground)
      legendY += 24
    for entry in legendEntries:
      let center = Point(x: legendX + 10, y: legendY - 4)
      case entry.mark
      of mkLine, mkErrorBar:
        let width = if entry.size > 0: entry.size else: spec.theme.lineWidth
        result.addPath(linePath([Point(x: legendX, y: center.y),
          Point(x: legendX + 20, y: center.y)], width, entry.lineStyle),
          entry.color)
      of mkPoint:
        let radius = if entry.size > 0: entry.size else: spec.theme.pointSize
        result.addPath(markerPath(entry.shape, vec2(center.x, center.y),
          min(radius, 7'f32) * 2'f32), entry.color)
      of mkBar, mkArea, mkRibbon, mkBoxPlot, mkTile, mkRect, mkImage,
          mkPolygon:
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
