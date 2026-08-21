# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/tables
import UniColor
import UniImage/core as ucore
import UniStatistics as statistics
from UniVector import MarkerShape, CircleMarker, SquareMarker, TriangleMarker,
  DiamondMarker, PlusMarker, CrossMarker
import contracts
import UniPlot/[common, data, scales, stats]

export MarkerShape

type
  MarkKind* = enum
    mkLine
    mkPoint
    mkBar
    mkArea
    mkText
    mkErrorBar
    mkRibbon
    mkBoxPlot
    mkTile
    mkRect
    mkImage
    mkPolygon

  LineStyle* = enum
    SolidLine
    DashedLine
    DottedLine
    DotDashLine
    LongDashLine

  MissingValuePolicy* = enum
    DropMissing
    BreakOnMissing
    RejectMissing

  LegendPosition* = enum
    lpRight
    lpNone

  LegendSpec* = object
    visible*: bool
    title*: string
    position*: LegendPosition

  AestheticRange* = object
    minimum*, maximum*: float32

  AxisDomainSpec* = object
    configured*: bool
    minimum*, maximum*: float64

  AxisCategoryDomainSpec* = object
    configured*: bool
    values*: seq[string]

  AxisScaleSpec* = object
    kind*: ScaleKind
    labelKind*: AxisLabelKind
    reversed*: bool
    domain*: AxisDomainSpec
    categories*: AxisCategoryDomainSpec

  SecondaryAxisSpec* = object
    enabled*: bool
    scale*, offset*: float64
    label*: string

  ReferenceKind* = enum
    rkXLine
    rkYLine
    rkXBand
    rkYBand

  Reference* = object
    kind*: ReferenceKind
    minimum*, maximum*: float64
    color*: Color
    width*: float32
    label*: string

  AnnotationKind* = enum
    akText
    akArrow

  Annotation* = object
    kind*: AnnotationKind
    x*, y*, xEnd*, yEnd*: float64
    text*: string
    color*: Color
    size*, headSize*: float32

  RasterFilter* = enum
    RasterNearest
    RasterBilinear
    RasterBox

  RasterLayer* = object
    image*: ucore.Image[uint8]
    xMin*, xMax*, yMin*, yMax*: float64
    filter*: RasterFilter

  ImageResource* = object
    name*: string
    image*: ucore.Image[uint8]

  Aes* = object
    x*, y*: string
    xOffset*: string
    xMin*, xMax*: string
    yMin*, yMax*: string
    yQ1*, yQ3*: string
    label*: string
    color*: string
    fill*: string
    size*: string
    alpha*: string
    shape*: string
    lineStyle*: string
    image*: string

  Layer* = object
    mark*: MarkKind
    mapping*: Aes
    color*: Color
    size*: float32
    legendLabel*: string
    shape*: MarkerShape
    lineStyle*: LineStyle
    missingValues*: MissingValuePolicy
    capWidth*: float32
    boxWidth*: float32
    imageFilter*: RasterFilter

  Theme* = object
    background*, foreground*, gridColor*: Color
    margins*: Insets
    pointSize*, lineWidth*: float32

  PlotSpec* = object
    data*: DataFrame
    layers*: seq[Layer]
    title*, xLabel*, yLabel*: string
    theme*: Theme
    legendSpec*: LegendSpec
    categoricalColors*: Palette
    continuousColors*: Palette
    mappedSizeRange*, mappedAlphaRange*: AestheticRange
    xScaleSpec*, yScaleSpec*: AxisScaleSpec
    secondaryYSpec*: SecondaryAxisSpec
    references*: seq[Reference]
    annotations*: seq[Annotation]
    rasters*: seq[RasterLayer]
    imageResources*: seq[ImageResource]

proc snapshot(image: ucore.Image[uint8]): ucore.Image[uint8] =
  result = image
  result.data = newSeq[uint8](image.data.len)
  if image.data.len > 0:
    copyMem(addr result.data[0], unsafeAddr image.data[0], image.data.len)

proc raster*(spec: var PlotSpec; image: ucore.Image[uint8]; xMin, xMax, yMin,
    yMax: float64; filter = RasterBilinear) {.contractual.} =
  ## Add a retained raster behind data marks, positioned in numeric data
  ## coordinates. Pixel storage is snapshotted so later caller mutation cannot
  ## change the plot specification.
  require:
    image.validPackedImage
    image.colorspace in {ucore.csGray, ucore.csRgb, ucore.csRgba}
    xMin.isFinite and xMax.isFinite and xMin < xMax
    yMin.isFinite and yMax.isFinite and yMin < yMax
  body:
    if not image.validPackedImage or
        image.colorspace notin {ucore.csGray, ucore.csRgb, ucore.csRgba}:
      raise newException(PlotError, "raster requires a valid Gray/RGB/RGBA8 image")
    if not xMin.isFinite or not xMax.isFinite or xMin >= xMax or
        not yMin.isFinite or not yMax.isFinite or yMin >= yMax:
      raise newException(PlotError, "raster extents must be finite and increasing")
    spec.rasters.add RasterLayer(image: image.snapshot, xMin: xMin,
      xMax: xMax, yMin: yMin, yMax: yMax, filter: filter)

proc addImageResource*(spec: var PlotSpec; name: string;
    image: ucore.Image[uint8]) {.contractual.} =
  ## Retain one named immutable image snapshot for data-mapped image marks.
  require:
    name.len > 0
    image.validPackedImage
    image.colorspace in {ucore.csGray, ucore.csRgb, ucore.csRgba}
  body:
    if name.len == 0:
      raise newException(PlotError, "image resource name cannot be empty")
    if not image.validPackedImage or
        image.colorspace notin {ucore.csGray, ucore.csRgb, ucore.csRgba}:
      raise newException(PlotError,
        "image resource requires a valid Gray/RGB/RGBA8 image")
    for resource in spec.imageResources:
      if resource.name == name:
        raise newException(PlotError, "image resource names must be unique")
    spec.imageResources.add ImageResource(name: name, image: image.snapshot)

proc cssColor(value: string): Color =
  let parsed = parseColor(value)
  if parsed.isErr: raise newException(PlotError, "invalid theme color: " & value)
  parsed.get

proc defaultTheme*(): Theme =
  Theme(background: cssColor("#ffffff"), foreground: cssColor("#202124"),
    gridColor: cssColor("#d9dde3"), margins: Insets(left: 70, top: 50,
    right: 30, bottom: 60), pointSize: 4, lineWidth: 2)

proc deriveTheme*(base: Theme; background = ""; foreground = "";
    gridColor = ""; pointSize = 0'f32; lineWidth = 0'f32): Theme {.
    contractual.} =
  ## Derive a reusable theme. Empty colours and zero numeric values inherit.
  require:
    pointSize >= 0 and pointSize.isFinite
    lineWidth >= 0 and lineWidth.isFinite
  body:
    if pointSize < 0 or not pointSize.isFinite or lineWidth < 0 or
        not lineWidth.isFinite:
      raise newException(PlotError,
        "derived theme sizes must be finite and non-negative")
    result = base
    if background.len > 0: result.background = cssColor(background)
    if foreground.len > 0: result.foreground = cssColor(foreground)
    if gridColor.len > 0: result.gridColor = cssColor(gridColor)
    if pointSize > 0: result.pointSize = pointSize
    if lineWidth > 0: result.lineWidth = lineWidth

proc withMargins*(base: Theme; margins: Insets): Theme {.contractual.} =
  ## Return a theme with an explicit, validated margin set.
  require:
    margins.left >= 0 and margins.left.isFinite
    margins.top >= 0 and margins.top.isFinite
    margins.right >= 0 and margins.right.isFinite
    margins.bottom >= 0 and margins.bottom.isFinite
  body:
    for margin in [margins.left, margins.top, margins.right, margins.bottom]:
      if margin < 0 or not margin.isFinite:
        raise newException(PlotError,
          "theme margins must be finite and non-negative")
    result = base
    result.margins = margins

proc minimalTheme*(): Theme =
  ## Publication-oriented light preset with quiet grid lines.
  defaultTheme().deriveTheme(gridColor = "#edf0f2", pointSize = 3.5,
    lineWidth = 1.5).withMargins(
      Insets(left: 64, top: 44, right: 24, bottom: 54))

proc darkTheme*(): Theme =
  ## Dark preset retaining accessible contrast through UniColor parsing.
  defaultTheme().deriveTheme(background = "#17191c",
    foreground = "#f1f3f5", gridColor = "#3a3f45")

proc applyTheme*(spec: var PlotSpec; value: Theme) =
  ## Apply a reusable theme value; compileScene validates public fields.
  spec.theme = value

proc plot*(data: DataFrame): PlotSpec =
  let continuous = viridis(5)
  if continuous.isErr:
    raise newException(PlotError, "cannot initialize the continuous palette")
  PlotSpec(data: data, theme: defaultTheme(),
    legendSpec: LegendSpec(position: lpRight), categoricalColors: okabeIto(),
    continuousColors: continuous.get,
    mappedSizeRange: AestheticRange(minimum: 2, maximum: 10),
    mappedAlphaRange: AestheticRange(minimum: 0.2, maximum: 1))

proc aes*(x, y: string; label = ""; color = ""; size = ""; alpha = "";
    shape = ""; lineStyle = ""; fill = ""; xMin = ""; xMax = "";
    yMin = ""; yMax = ""; yQ1 = ""; yQ3 = ""; image = "";
    xOffset = ""): Aes =
  Aes(x: x, y: y, label: label, color: color, fill: fill, size: size,
    alpha: alpha, shape: shape, lineStyle: lineStyle, xMin: xMin, xMax: xMax,
    yMin: yMin, yMax: yMax, yQ1: yQ1, yQ3: yQ3, image: image,
    xOffset: xOffset)

proc addLayer*(spec: var PlotSpec; mark: MarkKind; mapping: Aes;
    color = "#3366cc"; size = 0'f32; legend = "";
    shape = CircleMarker; lineStyle = SolidLine;
    missingValues = DropMissing) =
  if (mark notin {mkRect, mkImage} and mapping.x.len == 0) or
      (mark notin {mkErrorBar, mkRibbon, mkRect, mkImage} and
      mapping.y.len == 0):
    raise newException(PlotError, "required position mappings are missing")
  if mark in {mkRect, mkImage} and
      (mapping.xMin.len == 0 or mapping.xMax.len == 0 or
      mapping.yMin.len == 0 or mapping.yMax.len == 0):
    raise newException(PlotError,
      "rectangles require xMin, xMax, yMin and yMax mappings")
  if mark == mkImage and mapping.image.len == 0:
    raise newException(PlotError,
      "image marks require an image-resource mapping")
  if mark in {mkErrorBar, mkRibbon} and
      (mapping.yMin.len == 0 or mapping.yMax.len == 0):
    raise newException(PlotError,
      "error bars and ribbons require yMin and yMax mappings")
  if mark == mkBoxPlot and (mapping.yMin.len == 0 or mapping.yMax.len == 0 or
      mapping.yQ1.len == 0 or mapping.yQ3.len == 0):
    raise newException(PlotError,
      "box plots require whisker and quartile mappings")
  if size < 0 or not size.isFinite:
    raise newException(PlotError, "mark size must be finite and non-negative")
  spec.layers.add Layer(mark: mark, mapping: mapping, color: cssColor(color),
    size: size, legendLabel: legend, shape: shape, lineStyle: lineStyle,
    missingValues: missingValues)

proc geomLine*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    width = 0'f32; legend = ""; lineStyle = SolidLine;
    missingValues = BreakOnMissing) =
  spec.addLayer(mkLine, mapping, color, width, legend,
    lineStyle = lineStyle, missingValues = missingValues)
proc geomPoint*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    radius = 0'f32; legend = ""; shape = CircleMarker;
    missingValues = DropMissing) =
  spec.addLayer(mkPoint, mapping, color, radius, legend, shape = shape,
    missingValues = missingValues)
proc geomBar*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    legend = ""; missingValues = DropMissing) =
  spec.addLayer(mkBar, mapping, color, legend = legend,
    missingValues = missingValues)
proc geomRect*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    legend = ""; missingValues = DropMissing) =
  ## Add numeric rectangles with increasing x and nondecreasing y bounds.
  spec.addLayer(mkRect, mapping, color, legend = legend,
    missingValues = missingValues)
proc geomImage*(spec: var PlotSpec; mapping: Aes;
    filter = RasterBilinear; missingValues = DropMissing) =
  ## Add row-wise named image resources within numeric data-space bounds.
  spec.addLayer(mkImage, mapping, missingValues = missingValues)
  spec.layers[^1].imageFilter = filter
proc geomArea*(spec: var PlotSpec; mapping: Aes; color = "#6699dd";
    legend = ""; missingValues = BreakOnMissing) =
  spec.addLayer(mkArea, mapping, color, legend = legend,
    missingValues = missingValues)
proc geomPolygon*(spec: var PlotSpec; mapping: Aes; color = "#6699dd";
    legend = ""; missingValues = BreakOnMissing) =
  ## Add filled polygons from ordered numeric vertices.
  spec.addLayer(mkPolygon, mapping, color, legend = legend,
    missingValues = missingValues)
proc geomText*(spec: var PlotSpec; mapping: Aes; color = "#202124";
    size = 12'f32; legend = ""; missingValues = DropMissing) =
  spec.addLayer(mkText, mapping, color, size, legend,
    missingValues = missingValues)

proc geomErrorBar*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    width = 1'f32; capWidth = 8'f32; legend = "";
    missingValues = DropMissing) {.contractual.} =
  ## Add independent vertical uncertainty intervals with horizontal caps.
  require:
    capWidth >= 0 and capWidth.isFinite
  body:
    if capWidth < 0 or not capWidth.isFinite:
      raise newException(PlotError,
        "error-bar cap width must be finite and non-negative")
    spec.addLayer(mkErrorBar, mapping, color, width, legend,
      missingValues = missingValues)
    spec.layers[^1].capWidth = capWidth

proc geomRibbon*(spec: var PlotSpec; mapping: Aes; color = "#6699dd80";
    legend = ""; missingValues = BreakOnMissing) =
  ## Add a filled uncertainty envelope between yMin and yMax.
  spec.addLayer(mkRibbon, mapping, color, legend = legend,
    missingValues = missingValues)

proc geomBoxPlot*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    width = 1'f32; boxWidth = 0.65'f32; legend = "";
    missingValues = DropMissing) {.contractual.} =
  ## Add precomputed median, quartile and whisker rows as box plots.
  require:
    width > 0 and width.isFinite
    boxWidth > 0 and boxWidth <= 1 and boxWidth.isFinite
  body:
    if width <= 0 or not width.isFinite or boxWidth <= 0 or boxWidth > 1 or
        not boxWidth.isFinite:
      raise newException(PlotError, "invalid box-plot dimensions")
    spec.addLayer(mkBoxPlot, mapping, color, width, legend,
      missingValues = missingValues)
    spec.layers[^1].boxWidth = boxWidth

proc geomTile*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    legend = ""; missingValues = DropMissing) =
  ## Add categorical x-by-y cells; numeric color mappings use UniColor.
  spec.addLayer(mkTile, mapping, color, legend = legend,
    missingValues = missingValues)

proc labels*(spec: var PlotSpec; title = ""; x = ""; y = "") =
  spec.title = title
  spec.xLabel = x
  spec.yLabel = y

proc legend*(spec: var PlotSpec; title = ""; position = lpRight) =
  ## Configure a legend derived from layers carrying a non-empty legend label.
  spec.legendSpec = LegendSpec(visible: position != lpNone, title: title,
    position: position)

proc categoricalPalette*(spec: var PlotSpec; colors: Palette) =
  ## Select the discrete UniColor palette used by categorical color mappings.
  if colors.tag notin {palOrdered, palUnordered, palScientific, palTerminal,
      palCategorical}:
    raise newException(PlotError, "categorical mappings require a discrete palette")
  spec.categoricalColors = colors

proc continuousPalette*(spec: var PlotSpec; colors: Palette) =
  ## Select the ordered UniColor ramp used by numeric color mappings.
  if colors.tag notin {palOrdered, palScientific, palContinuous}:
    raise newException(PlotError,
      "continuous mappings require an ordered palette")
  spec.continuousColors = colors

proc sizeRange*(spec: var PlotSpec; minimum, maximum: float32) {.contractual.} =
  ## Configure the output range of numeric size mappings.
  require:
    minimum > 0 and minimum.isFinite
    maximum >= minimum and maximum.isFinite
  body:
    if minimum <= 0 or not minimum.isFinite or maximum < minimum or
        not maximum.isFinite:
      raise newException(PlotError,
        "size range must be finite, positive and ordered")
    spec.mappedSizeRange = AestheticRange(minimum: minimum, maximum: maximum)

proc alphaRange*(spec: var PlotSpec; minimum,
    maximum: float32) {.contractual.} =
  ## Configure the output range of numeric alpha mappings.
  require:
    minimum >= 0 and minimum.isFinite
    maximum >= minimum and maximum <= 1 and maximum.isFinite
  body:
    if minimum < 0 or not minimum.isFinite or maximum < minimum or
        maximum > 1 or not maximum.isFinite:
      raise newException(PlotError,
        "alpha range must be finite, ordered and within [0, 1]")
    spec.mappedAlphaRange = AestheticRange(minimum: minimum, maximum: maximum)

proc scaleX*(spec: var PlotSpec; kind = skLinear; reversed = false) =
  ## Configure the numeric x transform and the direction of numeric or
  ## categorical x coordinates.
  spec.xScaleSpec.kind = kind
  spec.xScaleSpec.labelKind = alkNumeric
  spec.xScaleSpec.reversed = reversed

proc scaleY*(spec: var PlotSpec; kind = skLinear; reversed = false) =
  ## Configure the numeric y transform and coordinate direction.
  spec.yScaleSpec.kind = kind
  spec.yScaleSpec.labelKind = alkNumeric
  spec.yScaleSpec.reversed = reversed

proc scaleXUtc*(spec: var PlotSpec; reversed = false) =
  ## Interpret numeric x values as POSIX seconds and label them in UTC.
  spec.xScaleSpec.kind = skLinear
  spec.xScaleSpec.labelKind = alkUtcDateTime
  spec.xScaleSpec.reversed = reversed

proc scaleYUtc*(spec: var PlotSpec; reversed = false) =
  ## Interpret numeric y values as POSIX seconds and label them in UTC.
  spec.yScaleSpec.kind = skLinear
  spec.yScaleSpec.labelKind = alkUtcDateTime
  spec.yScaleSpec.reversed = reversed

proc scaleXDuration*(spec: var PlotSpec; reversed = false) =
  ## Interpret numeric x values as signed elapsed seconds.
  spec.xScaleSpec.kind = skLinear
  spec.xScaleSpec.labelKind = alkDuration
  spec.xScaleSpec.reversed = reversed

proc scaleYDuration*(spec: var PlotSpec; reversed = false) =
  ## Interpret numeric y values as signed elapsed seconds.
  spec.yScaleSpec.kind = skLinear
  spec.yScaleSpec.labelKind = alkDuration
  spec.yScaleSpec.reversed = reversed

proc secondaryY*(spec: var PlotSpec; scale = 1.0; offset = 0.0;
    label = "") {.contractual.} =
  ## Add a right guide transformed bijectively from primary y values.
  require:
    scale.isFinite and scale != 0
    offset.isFinite
  body:
    if not scale.isFinite or scale == 0 or not offset.isFinite:
      raise newException(PlotError,
        "secondary y transform must be finite with a non-zero scale")
    spec.secondaryYSpec = SecondaryAxisSpec(enabled: true, scale: scale,
      offset: offset, label: label)

proc clearSecondaryY*(spec: var PlotSpec) =
  ## Remove the transformed right-side y guide.
  spec.secondaryYSpec = SecondaryAxisSpec()

proc annotateText*(spec: var PlotSpec; x, y: float64; text: string;
    color = "#202124"; fontSize = 13'f32) {.contractual.} =
  ## Add plain UniGlyph text at numeric data coordinates.
  require:
    x.isFinite and y.isFinite
    text.len > 0
    fontSize > 0 and fontSize.isFinite
  body:
    if not x.isFinite or not y.isFinite or text.len == 0 or fontSize <= 0 or
        not fontSize.isFinite:
      raise newException(PlotError, "invalid text annotation")
    spec.annotations.add Annotation(kind: akText, x: x, y: y, text: text,
      color: cssColor(color), size: fontSize)

proc annotateArrow*(spec: var PlotSpec; x, y, xEnd, yEnd: float64;
    color = "#202124"; width = 2'f32; headSize = 8'f32) {.contractual.} =
  ## Add a UniVector arrow between two distinct numeric data coordinates.
  require:
    x.isFinite and y.isFinite and xEnd.isFinite and yEnd.isFinite
    x != xEnd or y != yEnd
    width > 0 and width.isFinite
    headSize > 0 and headSize.isFinite
  body:
    if not x.isFinite or not y.isFinite or not xEnd.isFinite or
        not yEnd.isFinite or (x == xEnd and y == yEnd) or width <= 0 or
        not width.isFinite or headSize <= 0 or not headSize.isFinite:
      raise newException(PlotError, "invalid arrow annotation")
    spec.annotations.add Annotation(kind: akArrow, x: x, y: y, xEnd: xEnd,
      yEnd: yEnd, color: cssColor(color), size: width, headSize: headSize)

proc clearAnnotations*(spec: var PlotSpec) =
  ## Remove all retained text and arrow annotations.
  spec.annotations.setLen(0)

proc xLimits*(spec: var PlotSpec; minimum, maximum: float64) {.contractual.} =
  ## Fix the numeric x domain. The limits must contain every rendered value.
  require:
    minimum.isFinite and maximum.isFinite
    minimum < maximum
  body:
    if not minimum.isFinite or not maximum.isFinite or minimum >= maximum:
      raise newException(PlotError,
        "x limits must be finite and strictly increasing")
    spec.xScaleSpec.domain = AxisDomainSpec(configured: true,
      minimum: minimum, maximum: maximum)
    spec.xScaleSpec.categories = AxisCategoryDomainSpec()

proc xCategories*(spec: var PlotSpec; values: openArray[string]) {.
    contractual.} =
  ## Fix categorical x order while retaining categories absent from the data.
  require:
    values.len > 0
  body:
    if values.len == 0:
      raise newException(PlotError, "x category domain cannot be empty")
    var copied = newSeqOfCap[string](values.len)
    for value in values:
      if value in copied:
        raise newException(PlotError,
          "x category domain cannot contain duplicates")
      copied.add value
    spec.xScaleSpec.categories = AxisCategoryDomainSpec(configured: true,
      values: copied)
    spec.xScaleSpec.domain = AxisDomainSpec()

proc yLimits*(spec: var PlotSpec; minimum, maximum: float64) {.contractual.} =
  ## Fix the numeric y domain. The limits must contain every rendered value.
  require:
    minimum.isFinite and maximum.isFinite
    minimum < maximum
  body:
    if not minimum.isFinite or not maximum.isFinite or minimum >= maximum:
      raise newException(PlotError,
        "y limits must be finite and strictly increasing")
    spec.yScaleSpec.domain = AxisDomainSpec(configured: true,
      minimum: minimum, maximum: maximum)
    spec.yScaleSpec.categories = AxisCategoryDomainSpec()

proc yCategories*(spec: var PlotSpec; values: openArray[string]) {.
    contractual.} =
  ## Fix categorical y order while retaining categories absent from the data.
  require:
    values.len > 0
  body:
    if values.len == 0:
      raise newException(PlotError, "y category domain cannot be empty")
    var copied = newSeqOfCap[string](values.len)
    for value in values:
      if value in copied:
        raise newException(PlotError,
          "y category domain cannot contain duplicates")
      copied.add value
    spec.yScaleSpec.categories = AxisCategoryDomainSpec(configured: true,
      values: copied)
    spec.yScaleSpec.domain = AxisDomainSpec()

proc clearXLimits*(spec: var PlotSpec) =
  ## Restore automatic x-domain training.
  spec.xScaleSpec.domain = AxisDomainSpec()

proc clearXCategories*(spec: var PlotSpec) =
  ## Restore automatic categorical x-domain training.
  spec.xScaleSpec.categories = AxisCategoryDomainSpec()

proc clearYLimits*(spec: var PlotSpec) =
  ## Restore automatic y-domain training.
  spec.yScaleSpec.domain = AxisDomainSpec()

proc clearYCategories*(spec: var PlotSpec) =
  ## Restore automatic categorical y-domain training.
  spec.yScaleSpec.categories = AxisCategoryDomainSpec()

proc addReference(spec: var PlotSpec; kind: ReferenceKind; minimum,
    maximum: float64; color: string; width: float32; label: string) =
  if not minimum.isFinite or not maximum.isFinite or minimum > maximum or
      (kind in {rkXBand, rkYBand} and minimum == maximum):
    raise newException(PlotError,
      "reference bounds must be finite and bands must have positive extent")
  if width <= 0 or not width.isFinite:
    raise newException(PlotError, "reference width must be finite and positive")
  spec.references.add Reference(kind: kind, minimum: minimum, maximum: maximum,
    color: cssColor(color), width: width, label: label)

proc referenceX*(spec: var PlotSpec; value: float64; color = "#7a3db8";
    width = 1'f32; label = "") {.contractual.} =
  ## Add a vertical reference line in data coordinates.
  require:
    value.isFinite
    width > 0 and width.isFinite
  body:
    spec.addReference(rkXLine, value, value, color, width, label)

proc referenceY*(spec: var PlotSpec; value: float64; color = "#7a3db8";
    width = 1'f32; label = "") {.contractual.} =
  ## Add a horizontal reference line in data coordinates.
  require:
    value.isFinite
    width > 0 and width.isFinite
  body:
    spec.addReference(rkYLine, value, value, color, width, label)

proc referenceXBand*(spec: var PlotSpec; minimum, maximum: float64;
    color = "#d9e2f380"; label = "") {.contractual.} =
  ## Add a vertical filled band in data coordinates.
  require:
    minimum.isFinite and maximum.isFinite
    minimum < maximum
  body:
    spec.addReference(rkXBand, minimum, maximum, color, 1, label)

proc referenceYBand*(spec: var PlotSpec; minimum, maximum: float64;
    color = "#d9e2f380"; label = "") {.contractual.} =
  ## Add a horizontal filled band in data coordinates.
  require:
    minimum.isFinite and maximum.isFinite
    minimum < maximum
  body:
    spec.addReference(rkYBand, minimum, maximum, color, 1, label)

proc linePlot*(x, y: openArray[float64]; color = "#3366cc";
    legend = ""): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", x); frame.addColumn("y", y)
  result = plot(frame); result.geomLine(aes("x", "y"), color, legend = legend)

proc scatterPlot*(x, y: openArray[float64]; color = "#3366cc";
    legend = ""): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", x); frame.addColumn("y", y)
  result = plot(frame); result.geomPoint(aes("x", "y"), color,
    legend = legend)

proc linearSmoothPlot*(x, y: openArray[float64]; pointCount = 100;
    confidenceLevel = 0.95; showConfidence = true;
    lineColor = "#3366cc"; bandColor = "#3366cc40";
    legend = ""): PlotSpec {.contractual.} =
  ## Fit a linear smoother and materialise its mean-confidence band.
  require:
    x.len == y.len
    pointCount >= 2 and pointCount <= 10_000
    confidenceLevel > 0.0 and confidenceLevel < 1.0 and
      confidenceLevel.isFinite
  body:
    if x.len != y.len or pointCount < 2 or pointCount > 10_000 or
        not confidenceLevel.isFinite or confidenceLevel <= 0.0 or
        confidenceLevel >= 1.0:
      raise newException(PlotError, "invalid linear smoothing input")
    var
      finiteX = newSeqOfCap[float64](x.len)
      finiteY = newSeqOfCap[float64](y.len)
    for index in 0 ..< x.len:
      if x[index].isFinite and y[index].isFinite:
        finiteX.add x[index]
        finiteY.add y[index]
    if finiteX.len < 3:
      raise newException(PlotError,
        "linear smoothing requires at least three finite pairs")
    var minimumX = finiteX[0]
    var maximumX = finiteX[0]
    for value in finiteX:
      minimumX = min(minimumX, value)
      maximumX = max(maximumX, value)
    if minimumX == maximumX:
      raise newException(PlotError,
        "linear smoothing predictor must not be constant")
    try:
      let fit = statistics.linearRegressionDiagnostics(finiteX, finiteY)
      let predictionContext = statistics.linearPredictionContext(fit,
        confidenceLevel)
      var
        grid = newSeq[float64](pointCount)
        estimate = newSeq[float64](pointCount)
        lower = newSeq[float64](pointCount)
        upper = newSeq[float64](pointCount)
      for index in 0 ..< pointCount:
        let fraction = float64(index) / float64(pointCount - 1)
        grid[index] = minimumX * (1.0 - fraction) + maximumX * fraction
        let prediction = statistics.predictLinear(predictionContext,
          grid[index])
        estimate[index] = prediction.estimate
        lower[index] = prediction.confidenceLower
        upper[index] = prediction.confidenceUpper
      var frame = initDataFrame()
      frame.addColumn("x", grid)
      frame.addColumn("estimate", estimate)
      if showConfidence:
        frame.addColumn("confidenceLower", lower)
        frame.addColumn("confidenceUpper", upper)
      result = plot(frame)
      if showConfidence:
        result.geomRibbon(aes("x", "estimate", yMin = "confidenceLower",
          yMax = "confidenceUpper"), bandColor)
      result.geomLine(aes("x", "estimate"), lineColor, legend = legend)
    except ValueError as error:
      raise newException(PlotError, error.msg)

proc densityPlot*(values: openArray[float64]; pointCount = 512;
    bandwidth = 0.0; fillColor = "#3366cc40";
    lineColor = "#3366cc"; legend = ""): PlotSpec {.contractual.} =
  ## Materialise a UniStatistics Gaussian KDE as retained area and line marks.
  require:
    pointCount >= 2 and pointCount <= 100_000
    bandwidth >= 0.0 and bandwidth.isFinite
  body:
    if pointCount < 2 or pointCount > 100_000 or bandwidth < 0.0 or
        not bandwidth.isFinite:
      raise newException(PlotError, "invalid density plot configuration")
    var finiteValues = newSeqOfCap[float64](values.len)
    for value in values:
      if value.isFinite: finiteValues.add value
    if finiteValues.len < 2:
      raise newException(PlotError,
        "density plot requires at least two finite observations")
    try:
      let estimate = statistics.kernelDensity(finiteValues, pointCount,
        bandwidth)
      var frame = initDataFrame()
      frame.addColumn("x", estimate.points)
      frame.addColumn("density", estimate.density)
      result = plot(frame)
      result.geomArea(aes("x", "density"), fillColor)
      result.geomLine(aes("x", "density"), lineColor, legend = legend)
    except ValueError as error:
      raise newException(PlotError, error.msg)

proc violinPlot*(values: openArray[float64]; pointCount = 256;
    bandwidth = 0.0; width = 0.8; color = "#3366cc80";
    legend = ""): PlotSpec {.contractual.} =
  ## Materialise one mirrored UniStatistics Gaussian KDE as a polygon.
  require:
    pointCount >= 2 and pointCount <= 100_000
    bandwidth >= 0.0 and bandwidth.isFinite
    width > 0.0 and width.isFinite
  body:
    if pointCount < 2 or pointCount > 100_000 or bandwidth < 0.0 or
        not bandwidth.isFinite or width <= 0.0 or not width.isFinite:
      raise newException(PlotError, "invalid violin plot configuration")
    var finiteValues = newSeqOfCap[float64](values.len)
    for value in values:
      if value.isFinite: finiteValues.add value
    if finiteValues.len < 2:
      raise newException(PlotError,
        "violin plot requires at least two finite observations")
    try:
      let estimate = statistics.kernelDensity(finiteValues, pointCount,
        bandwidth)
      var maximumDensity = 0.0
      for density in estimate.density:
        maximumDensity = max(maximumDensity, density)
      if maximumDensity <= 0.0 or not maximumDensity.isFinite:
        raise newException(PlotError,
          "violin density must have a positive finite maximum")
      var
        horizontal = newSeqOfCap[float64](pointCount * 2)
        vertical = newSeqOfCap[float64](pointCount * 2)
      let halfWidth = width * 0.5
      for index in 0 ..< pointCount:
        horizontal.add(-halfWidth * estimate.density[index] / maximumDensity)
        vertical.add(estimate.points[index])
      for index in countdown(pointCount - 1, 0):
        horizontal.add(halfWidth * estimate.density[index] / maximumDensity)
        vertical.add(estimate.points[index])
      var frame = initDataFrame()
      frame.addColumn("violinWidth", horizontal)
      frame.addColumn("value", vertical)
      result = plot(frame)
      result.geomPolygon(aes("violinWidth", "value"), color,
        legend = legend)
    except ValueError as error:
      raise newException(PlotError, error.msg)

proc violinPlot*(groups: openArray[string]; values: openArray[float64];
    pointCount = 256; bandwidth = 0.0; width = 0.8;
    color = "#3366cc80"; legend = ""): PlotSpec {.contractual.} =
  ## Materialise first-seen groups as categorical mirrored KDE polygons.
  require:
    groups.len == values.len
    pointCount >= 2 and pointCount <= 100_000
    bandwidth >= 0.0 and bandwidth.isFinite
    width > 0.0 and width <= 1.0 and width.isFinite
  body:
    if groups.len != values.len or pointCount < 2 or pointCount > 100_000 or
        bandwidth < 0.0 or not bandwidth.isFinite or width <= 0.0 or
        width > 1.0 or not width.isFinite:
      raise newException(PlotError, "invalid grouped violin input")
    var samples = initOrderedTable[string, seq[float64]]()
    for index in 0 ..< groups.len:
      if groups[index].len == 0:
        raise newException(PlotError, "violin groups must not be empty")
      if values[index].isFinite:
        if groups[index] notin samples: samples[groups[index]] = @[]
        samples[groups[index]].add values[index]
    if samples.len == 0:
      raise newException(PlotError,
        "grouped violin plots require finite observations")
    var
      category: seq[string]
      offset, vertical: seq[float64]
      groupIndex = 0
    try:
      for name, observations in samples:
        if observations.len < 2:
          raise newException(PlotError,
            "each violin group requires at least two finite observations")
        let estimate = statistics.kernelDensity(observations, pointCount,
          bandwidth)
        var maximumDensity = 0.0
        for density in estimate.density:
          maximumDensity = max(maximumDensity, density)
        if maximumDensity <= 0.0 or not maximumDensity.isFinite:
          raise newException(PlotError,
            "violin density must have a positive finite maximum")
        let halfWidth = width * 0.5
        for index in 0 ..< pointCount:
          category.add name
          offset.add(-halfWidth * estimate.density[index] / maximumDensity)
          vertical.add estimate.points[index]
        for index in countdown(pointCount - 1, 0):
          category.add name
          offset.add(halfWidth * estimate.density[index] / maximumDensity)
          vertical.add estimate.points[index]
        inc groupIndex
        if groupIndex < samples.len:
          category.add name
          offset.add NaN
          vertical.add NaN
      var frame = initDataFrame()
      frame.addColumn("group", category)
      frame.addColumn("violinOffset", offset)
      frame.addColumn("value", vertical)
      result = plot(frame)
      result.geomPolygon(aes("group", "value", xOffset = "violinOffset"),
        color, legend = legend)
    except ValueError as error:
      raise newException(PlotError, error.msg)

proc barPlot*(categories: openArray[string]; values: openArray[float64];
    color = "#3366cc"; legend = ""): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("category", categories); frame.addColumn("value", values)
  result = plot(frame); result.geomBar(aes("category", "value"), color,
    legend = legend)

proc histogramPlot*(values: openArray[float64]; binCount = 30;
    color = "#3366cc"; legend = ""): PlotSpec =
  let bins = histogram(values, binCount)
  var labels: seq[string]
  var counts: seq[float64]
  for bin in bins:
    labels.add tickLabel(bin.lower) & "–" & tickLabel(bin.upper)
    counts.add float64(bin.count)
  result = barPlot(labels, counts, color, legend)

proc histogramBreaksPlot*(values, breaks: openArray[float64];
    color = "#3366cc"; legend = ""): PlotSpec =
  ## Build a categorical bar plot from explicit histogram boundaries.
  let bins = histogramBreaks(values, breaks)
  var
    labels = newSeqOfCap[string](bins.len)
    counts = newSeqOfCap[float64](bins.len)
  for bin in bins:
    labels.add tickLabel(bin.lower) & "–" & tickLabel(bin.upper)
    counts.add float64(bin.count)
  result = barPlot(labels, counts, color, legend)

proc histogramPlot*(values, breaks: openArray[float64]; density = false;
    color = "#3366cc"; legend = ""): PlotSpec =
  ## Build numeric variable-width count or probability-density rectangles.
  let bins = histogramBreaks(values, breaks)
  var
    lower = newSeqOfCap[float64](bins.len)
    upper = newSeqOfCap[float64](bins.len)
    baseline = newSeq[float64](bins.len)
    heights = newSeqOfCap[float64](bins.len)
    finiteCount = 0
  for bin in bins: finiteCount += bin.count
  for bin in bins:
    let width = bin.upper - bin.lower
    if width <= 0 or not width.isFinite:
      raise newException(PlotError,
        "numeric histogram intervals must have finite positive widths")
    lower.add bin.lower
    upper.add bin.upper
    let height = if density and finiteCount > 0:
      float64(bin.count) / float64(finiteCount) / width
    else:
      float64(bin.count)
    if not height.isFinite:
      raise newException(PlotError,
        "numeric histogram height must remain finite")
    heights.add height
  var frame = initDataFrame()
  frame.addColumn("xMin", lower)
  frame.addColumn("xMax", upper)
  frame.addColumn("yMin", baseline)
  frame.addColumn("yMax", heights)
  result = plot(frame)
  result.geomRect(aes("", "", xMin = "xMin", xMax = "xMax",
    yMin = "yMin", yMax = "yMax"), color, legend)

proc histogramPlot*(values: openArray[float64]; rule: HistogramRule;
    density = false; color = "#3366cc"; legend = ""): PlotSpec =
  ## Build a numeric equal-width histogram using an automatic selection rule.
  let breaks = automaticHistogramBreaks(values, rule)
  if breaks.len == 0:
    raise newException(PlotError,
      "automatic histogram requires a finite sample")
  result = histogramPlot(values, breaks, density, color, legend)

proc groupedAggregatePlot*(groups: openArray[string];
    values: openArray[float64]; aggregation = agMean; color = "#3366cc";
    legend = ""): PlotSpec =
  ## Aggregate finite samples per first-seen group into categorical bars.
  let grouped = aggregateGroups(groups, values, aggregation)
  var
    categories = newSeqOfCap[string](grouped.len)
    aggregated = newSeqOfCap[float64](grouped.len)
  for value in grouped:
    categories.add value.group
    aggregated.add value.value
  result = barPlot(categories, aggregated, color, legend)

proc boxPlot*(groups: openArray[string]; values: openArray[float64];
    whiskerLength = 1.5; color = "#3366cc"; outlierColor = "#cc3344";
    legend = ""): PlotSpec {.contractual.} =
  ## Summarize finite values per first-seen group and retain outlier points.
  require:
    groups.len == values.len
    groups.len > 0
    whiskerLength.isFinite and whiskerLength >= 0
  body:
    if groups.len != values.len or groups.len == 0 or
        not whiskerLength.isFinite or whiskerLength < 0:
      raise newException(PlotError, "invalid grouped box-plot input")
    var grouped = initOrderedTable[string, seq[float64]]()
    for index, group in groups:
      if group.len == 0:
        raise newException(PlotError, "box-plot group names cannot be empty")
      if group notin grouped: grouped[group] = @[]
      if values[index].isFinite: grouped[group].add values[index]
    var categories: seq[string]
    var medians, firstQuartiles, thirdQuartiles, lowerWhiskers,
      upperWhiskers, outliers: seq[float64]
    template addRow(category: string; median, q1, q3, lower, upper,
        outlier: float64) =
      categories.add category
      medians.add median
      firstQuartiles.add q1
      thirdQuartiles.add q3
      lowerWhiskers.add lower
      upperWhiskers.add upper
      outliers.add outlier
    for group, samples in grouped:
      if samples.len == 0:
        raise newException(PlotError,
          "every box-plot group requires a finite sample")
      let summary = summarize(samples, whiskerLength)
      addRow(group, summary.median, summary.firstQuartile,
        summary.thirdQuartile, summary.lowerWhisker, summary.upperWhisker, NaN)
      for outlier in summary.outliers:
        addRow(group, NaN, NaN, NaN, NaN, NaN, outlier)
    var frame = initDataFrame()
    frame.addColumn("category", categories)
    frame.addColumn("median", medians)
    frame.addColumn("firstQuartile", firstQuartiles)
    frame.addColumn("thirdQuartile", thirdQuartiles)
    frame.addColumn("lowerWhisker", lowerWhiskers)
    frame.addColumn("upperWhisker", upperWhiskers)
    frame.addColumn("outlier", outliers)
    result = plot(frame)
    result.geomBoxPlot(aes("category", "median", yMin = "lowerWhisker",
      yMax = "upperWhisker", yQ1 = "firstQuartile",
      yQ3 = "thirdQuartile"), color, legend = legend)
    result.geomPoint(aes("category", "outlier"), outlierColor, radius = 3)

proc heatmapPlot*(xs, ys: openArray[string]; values: openArray[float64];
    aggregation = agMean; legend = "value"): PlotSpec =
  ## Aggregate observations into a complete categorical x-by-y tile matrix.
  let cells = aggregate2D(xs, ys, values, aggregation)
  var
    xValues = newSeqOfCap[string](cells.len)
    yValues = newSeqOfCap[string](cells.len)
    aggregated = newSeqOfCap[float64](cells.len)
  for cell in cells:
    xValues.add cell.x
    yValues.add cell.y
    aggregated.add cell.value
  var frame = initDataFrame()
  frame.addColumn("x", xValues)
  frame.addColumn("y", yValues)
  frame.addColumn("value", aggregated)
  result = plot(frame)
  result.geomTile(aes("x", "y", color = "value"), legend = legend)
  if legend.len > 0:
    result.legend()

proc numericHeatmapPlot*(xBreaks, yBreaks, values: openArray[float64];
    legend = "value"): PlotSpec {.contractual.} =
  ## Build row-major numeric cells from explicit x and y boundaries.
  require:
    xBreaks.len >= 2
    yBreaks.len >= 2
  body:
    if xBreaks.len < 2 or yBreaks.len < 2:
      raise newException(PlotError,
        "numeric heatmap axes require at least two boundaries")
    let
      xBins = histogramBreaks([], xBreaks)
      yBins = histogramBreaks([], yBreaks)
    if xBins.len > high(int) div yBins.len or
        values.len != xBins.len * yBins.len:
      raise newException(PlotError,
        "numeric heatmap values must match the row-major cell count")
    var xMin, xMax, yMin, yMax, cellValues: seq[float64]
    xMin = newSeqOfCap[float64](values.len)
    xMax = newSeqOfCap[float64](values.len)
    yMin = newSeqOfCap[float64](values.len)
    yMax = newSeqOfCap[float64](values.len)
    cellValues = newSeqOfCap[float64](values.len)
    for xBin in xBins:
      let width = xBin.upper - xBin.lower
      if width <= 0 or not width.isFinite:
        raise newException(PlotError,
          "numeric heatmap intervals must have finite positive widths")
    for yIndex, yBin in yBins:
      let yWidth = yBin.upper - yBin.lower
      if yWidth <= 0 or not yWidth.isFinite:
        raise newException(PlotError,
          "numeric heatmap intervals must have finite positive widths")
      for xIndex, xBin in xBins:
        xMin.add xBin.lower
        xMax.add xBin.upper
        yMin.add yBin.lower
        yMax.add yBin.upper
        cellValues.add values[yIndex * xBins.len + xIndex]
    var frame = initDataFrame()
    frame.addColumn("xMin", xMin)
    frame.addColumn("xMax", xMax)
    frame.addColumn("yMin", yMin)
    frame.addColumn("yMax", yMax)
    frame.addColumn("value", cellValues)
    result = plot(frame)
    result.geomRect(aes("", "", xMin = "xMin", xMax = "xMax",
      yMin = "yMin", yMax = "yMax", fill = "value"), legend = legend)
    if legend.len > 0:
      result.legend()

proc contourPlot*(xs, ys, values, levels: openArray[float64];
    color = "#3366cc"; width = 0'f32; legend = ""): PlotSpec {.contractual.} =
  ## Materialise rectilinear marching-squares contours as retained lines.
  require:
    xs.len >= 2 and ys.len >= 2
    levels.len > 0
    width >= 0 and width.isFinite
  body:
    if width < 0 or not width.isFinite:
      raise newException(PlotError,
        "contour line width must be finite and non-negative")
    let segments = contourSegments(xs, ys, values, levels)
    if segments.len == 0:
      raise newException(PlotError,
        "contour levels do not intersect any complete grid cell")
    if segments.len > high(int) div 3:
      raise newException(PlotError, "contour path is too large")
    var
      pathX = newSeqOfCap[float64](segments.len * 3)
      pathY = newSeqOfCap[float64](segments.len * 3)
    for segment in segments:
      pathX.add segment.x0
      pathY.add segment.y0
      pathX.add segment.x1
      pathY.add segment.y1
      pathX.add NaN
      pathY.add NaN
    var frame = initDataFrame()
    frame.addColumn("x", pathX)
    frame.addColumn("y", pathY)
    result = plot(frame)
    result.geomLine(aes("x", "y"), color, width, legend,
      missingValues = BreakOnMissing)
