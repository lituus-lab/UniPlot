# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import UniColor
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

  AxisScaleSpec* = object
    kind*: ScaleKind
    reversed*: bool

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

  Aes* = object
    x*, y*: string
    label*: string
    color*: string
    fill*: string
    size*: string
    alpha*: string
    shape*: string
    lineStyle*: string

  Layer* = object
    mark*: MarkKind
    mapping*: Aes
    color*: Color
    size*: float32
    legendLabel*: string
    shape*: MarkerShape
    lineStyle*: LineStyle
    missingValues*: MissingValuePolicy

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
    references*: seq[Reference]

proc cssColor(value: string): Color =
  let parsed = parseColor(value)
  if parsed.isErr: raise newException(PlotError, "invalid theme color: " & value)
  parsed.get

proc defaultTheme*(): Theme =
  Theme(background: cssColor("#ffffff"), foreground: cssColor("#202124"),
    gridColor: cssColor("#d9dde3"), margins: Insets(left: 70, top: 50,
    right: 30, bottom: 60), pointSize: 4, lineWidth: 2)

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
    shape = ""; lineStyle = ""; fill = ""): Aes =
  Aes(x: x, y: y, label: label, color: color, fill: fill, size: size,
    alpha: alpha, shape: shape, lineStyle: lineStyle)

proc addLayer*(spec: var PlotSpec; mark: MarkKind; mapping: Aes;
    color = "#3366cc"; size = 0'f32; legend = "";
    shape = CircleMarker; lineStyle = SolidLine;
    missingValues = DropMissing) =
  if mapping.x.len == 0 or mapping.y.len == 0:
    raise newException(PlotError, "x and y mappings are required")
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
proc geomArea*(spec: var PlotSpec; mapping: Aes; color = "#6699dd";
    legend = ""; missingValues = BreakOnMissing) =
  spec.addLayer(mkArea, mapping, color, legend = legend,
    missingValues = missingValues)
proc geomText*(spec: var PlotSpec; mapping: Aes; color = "#202124";
    size = 12'f32; legend = ""; missingValues = DropMissing) =
  spec.addLayer(mkText, mapping, color, size, legend,
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
  spec.xScaleSpec = AxisScaleSpec(kind: kind, reversed: reversed)

proc scaleY*(spec: var PlotSpec; kind = skLinear; reversed = false) =
  ## Configure the numeric y transform and coordinate direction.
  spec.yScaleSpec = AxisScaleSpec(kind: kind, reversed: reversed)

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
