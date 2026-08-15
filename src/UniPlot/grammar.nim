# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import UniColor
import UniPlot/[common, data, scales, stats]

type
  MarkKind* = enum
    mkLine
    mkPoint
    mkBar
    mkArea
    mkText

  LegendPosition* = enum
    lpRight
    lpNone

  LegendSpec* = object
    visible*: bool
    title*: string
    position*: LegendPosition

  Aes* = object
    x*, y*: string
    label*: string

  Layer* = object
    mark*: MarkKind
    mapping*: Aes
    color*: Color
    size*: float32
    legendLabel*: string

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

proc cssColor(value: string): Color =
  let parsed = parseColor(value)
  if parsed.isErr: raise newException(PlotError, "invalid theme color: " & value)
  parsed.get

proc defaultTheme*(): Theme =
  Theme(background: cssColor("#ffffff"), foreground: cssColor("#202124"),
    gridColor: cssColor("#d9dde3"), margins: Insets(left: 70, top: 50,
    right: 30, bottom: 60), pointSize: 4, lineWidth: 2)

proc plot*(data: DataFrame): PlotSpec =
  PlotSpec(data: data, theme: defaultTheme(),
    legendSpec: LegendSpec(position: lpRight))

proc aes*(x, y: string; label = ""): Aes = Aes(x: x, y: y, label: label)

proc addLayer*(spec: var PlotSpec; mark: MarkKind; mapping: Aes;
    color = "#3366cc"; size = 0'f32; legend = "") =
  if mapping.x.len == 0 or mapping.y.len == 0:
    raise newException(PlotError, "x and y mappings are required")
  if size < 0 or not size.isFinite:
    raise newException(PlotError, "mark size must be finite and non-negative")
  spec.layers.add Layer(mark: mark, mapping: mapping, color: cssColor(color),
    size: size, legendLabel: legend)

proc geomLine*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    width = 0'f32; legend = "") =
  spec.addLayer(mkLine, mapping, color, width, legend)
proc geomPoint*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    radius = 0'f32; legend = "") =
  spec.addLayer(mkPoint, mapping, color, radius, legend)
proc geomBar*(spec: var PlotSpec; mapping: Aes; color = "#3366cc";
    legend = "") =
  spec.addLayer(mkBar, mapping, color, legend = legend)
proc geomArea*(spec: var PlotSpec; mapping: Aes; color = "#6699dd";
    legend = "") =
  spec.addLayer(mkArea, mapping, color, legend = legend)
proc geomText*(spec: var PlotSpec; mapping: Aes; color = "#202124";
    size = 12'f32; legend = "") =
  spec.addLayer(mkText, mapping, color, size, legend)

proc labels*(spec: var PlotSpec; title = ""; x = ""; y = "") =
  spec.title = title
  spec.xLabel = x
  spec.yLabel = y

proc legend*(spec: var PlotSpec; title = ""; position = lpRight) =
  ## Configure a legend derived from layers carrying a non-empty legend label.
  spec.legendSpec = LegendSpec(visible: position != lpNone, title: title,
    position: position)

proc linePlot*(x, y: openArray[float64]; color = "#3366cc"): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", x); frame.addColumn("y", y)
  result = plot(frame); result.geomLine(aes("x", "y"), color)

proc scatterPlot*(x, y: openArray[float64]; color = "#3366cc"): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", x); frame.addColumn("y", y)
  result = plot(frame); result.geomPoint(aes("x", "y"), color)

proc barPlot*(categories: openArray[string]; values: openArray[float64];
    color = "#3366cc"): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("category", categories); frame.addColumn("value", values)
  result = plot(frame); result.geomBar(aes("category", "value"), color)

proc histogramPlot*(values: openArray[float64]; binCount = 30;
    color = "#3366cc"): PlotSpec =
  let bins = histogram(values, binCount)
  var labels: seq[string]
  var counts: seq[float64]
  for bin in bins:
    labels.add tickLabel(bin.lower) & "–" & tickLabel(bin.upper)
    counts.add float64(bin.count)
  result = barPlot(labels, counts, color)
