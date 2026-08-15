# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[locks, tables]
import UniColor
import UniGlyph
import UniPlot

const
  UPLOT_OK* = 0.cint
  UPLOT_ERR_ARGUMENT* = 1.cint
  UPLOT_ERR_RENDER* = 2.cint
  UPLOT_ABI_VERSION* = 1.cint

type PlotHandle = ref object
  spec: PlotSpec
  size: Size
  nextColumn: int

var initLock: Lock
var runtimeStarted = false
initLock(initLock)

proc NimMain() {.importc.}

proc uplot_init*(): cint {.exportc, dynlib, cdecl.} =
  withLock initLock:
    if not runtimeStarted:
      NimMain()
      runtimeStarted = true
  UPLOT_OK

proc uplot_version*(): cstring {.exportc, dynlib,
    cdecl.} = UniPlotVersion.cstring
proc uplot_abi_version*(): cint {.exportc, dynlib, cdecl.} = UPLOT_ABI_VERSION

proc uplot_plot_new*(width, height: cint): pointer {.exportc, dynlib, cdecl.} =
  try:
    let size = Size(width: int(width), height: int(height))
    size.validate()
    var frame = initDataFrame()
    let handle = PlotHandle(spec: plot(frame), size: size)
    GC_ref(handle)
    cast[pointer](handle)
  except CatchableError, Defect: nil

proc uplot_plot_from_json*(payload: ptr uint8; length: csize_t; width,
    height: cint): pointer {.exportc, dynlib, cdecl.} =
  if payload.isNil or length == 0 or length > csize_t(high(int)): return nil
  try:
    let size = Size(width: int(width), height: int(height))
    size.validate()
    var encoded = newString(int(length))
    copyMem(addr encoded[0], payload, int(length))
    let parsed = PlotHandle(spec: fromJson(encoded), size: size)
    GC_ref(parsed)
    cast[pointer](parsed)
  except CatchableError, Defect:
    nil

proc handle(value: pointer): PlotHandle {.inline.} = cast[PlotHandle](value)

proc resizeFrame(frame: var DataFrame; rowCount: int) =
  if rowCount <= frame.rowCount: return
  for name in frame.order:
    case frame.columns[name].kind
    of ckNumeric:
      let previous = frame.columns[name].numbers.len
      frame.columns[name].numbers.setLen(rowCount)
      for row in previous ..< rowCount:
        frame.columns[name].numbers[row] = NaN
    of ckCategorical:
      frame.columns[name].categories.setLen(rowCount)
  frame.rowCount = rowCount

proc addSeries(value: pointer; xs, ys: ptr float64; count: csize_t;
    mark: MarkKind; color: cstring; size: float32;
    lineStyle = SolidLine; shape = CircleMarker;
    missingValues = DropMissing): cint =
  if value.isNil or xs.isNil or ys.isNil or count == 0 or color.isNil:
    return UPLOT_ERR_ARGUMENT
  if count > csize_t(high(int)):
    return UPLOT_ERR_ARGUMENT
  if size < 0 or not size.isFinite or parseColor($color).isErr:
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    let inputCount = int(count)
    let targetCount = max(inputCount, h.spec.data.rowCount)
    h.spec.data.resizeFrame(targetCount)
    var xv = newSeq[float64](targetCount)
    var yv = newSeq[float64](targetCount)
    let xa = cast[ptr UncheckedArray[float64]](xs)
    let ya = cast[ptr UncheckedArray[float64]](ys)
    for i in 0 ..< inputCount:
      xv[i] = xa[i]; yv[i] = ya[i]
    for i in inputCount ..< targetCount:
      xv[i] = NaN; yv[i] = NaN
    let xName = "x" & $h.nextColumn
    let yName = "y" & $h.nextColumn
    h.spec.data.addColumn(xName, xv)
    h.spec.data.addColumn(yName, yv)
    h.spec.addLayer(mark, aes(xName, yName), $color, size,
      lineStyle = lineStyle, shape = shape, missingValues = missingValues)
    inc h.nextColumn
    UPLOT_OK
  except CatchableError, Defect: UPLOT_ERR_ARGUMENT

proc uplot_add_line*(value: pointer; xs, ys: ptr float64; count: csize_t;
    color: cstring; width: float32): cint {.exportc, dynlib, cdecl.} =
  addSeries(value, xs, ys, count, mkLine, color, width,
    missingValues = BreakOnMissing)

proc uplot_add_points*(value: pointer; xs, ys: ptr float64; count: csize_t;
    color: cstring; radius: float32): cint {.exportc, dynlib, cdecl.} =
  addSeries(value, xs, ys, count, mkPoint, color, radius)

proc uplot_add_box_plot*(value: pointer; groups: ptr cstring;
    values: ptr float64; count: csize_t; whiskerLength: float64; color,
    outlierColor: cstring): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or groups.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or color.isNil or outlierColor.isNil:
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UPLOT_ERR_ARGUMENT
    let
      inputGroups = cast[ptr UncheckedArray[cstring]](groups)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var copiedGroups = newSeqOfCap[string](int(count))
    var copiedValues = newSeqOfCap[float64](int(count))
    for index in 0 ..< int(count):
      if inputGroups[index].isNil: return UPLOT_ERR_ARGUMENT
      copiedGroups.add $inputGroups[index]
      copiedValues.add inputValues[index]
    h.spec = boxPlot(copiedGroups, copiedValues, whiskerLength, $color,
      $outlierColor)
    h.nextColumn = 0
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc addHistogram(value: pointer; values: ptr float64;
    valueCount: csize_t; breaks: ptr float64; breakCount: csize_t;
    color: cstring; numeric, density: bool): cint =
  if value.isNil or values.isNil or valueCount == 0 or breaks.isNil or
      breakCount < 2 or valueCount > csize_t(high(int)) or
      breakCount > csize_t(high(int)) or color.isNil:
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UPLOT_ERR_ARGUMENT
    let
      inputValues = cast[ptr UncheckedArray[float64]](values)
      inputBreaks = cast[ptr UncheckedArray[float64]](breaks)
    var
      copiedValues = newSeqOfCap[float64](int(valueCount))
      copiedBreaks = newSeqOfCap[float64](int(breakCount))
    for index in 0 ..< int(valueCount):
      copiedValues.add inputValues[index]
    for index in 0 ..< int(breakCount):
      copiedBreaks.add inputBreaks[index]
    h.spec = if numeric:
      histogramPlot(copiedValues, copiedBreaks, density, $color)
    else:
      histogramBreaksPlot(copiedValues, copiedBreaks, $color)
    h.nextColumn = 0
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_add_histogram_breaks*(value: pointer; values: ptr float64;
    valueCount: csize_t; breaks: ptr float64; breakCount: csize_t;
    color: cstring): cint {.exportc, dynlib, cdecl.} =
  addHistogram(value, values, valueCount, breaks, breakCount, color,
    numeric = false, density = false)

proc uplot_add_numeric_histogram*(value: pointer; values: ptr float64;
    valueCount: csize_t; breaks: ptr float64; breakCount: csize_t;
    density: cint; color: cstring): cint {.exportc, dynlib, cdecl.} =
  if density notin [cint(0), cint(1)]: return UPLOT_ERR_ARGUMENT
  addHistogram(value, values, valueCount, breaks, breakCount, color,
    numeric = true, density = density == 1)

proc uplot_add_grouped_aggregate*(value: pointer; groups: ptr cstring;
    values: ptr float64; count: csize_t; aggregation: cint;
    color: cstring): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or groups.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or color.isNil or
      aggregation < cint(low(AggregationKind).ord) or
      aggregation > cint(high(AggregationKind).ord):
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UPLOT_ERR_ARGUMENT
    let
      inputGroups = cast[ptr UncheckedArray[cstring]](groups)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var
      copiedGroups = newSeqOfCap[string](int(count))
      copiedValues = newSeqOfCap[float64](int(count))
    for index in 0 ..< int(count):
      if inputGroups[index].isNil: return UPLOT_ERR_ARGUMENT
      copiedGroups.add $inputGroups[index]
      copiedValues.add inputValues[index]
    h.spec = groupedAggregatePlot(copiedGroups, copiedValues,
      AggregationKind(aggregation), $color)
    h.nextColumn = 0
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_add_heatmap*(value: pointer; xs, ys: ptr cstring;
    values: ptr float64; count: csize_t; aggregation: cint): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil or xs.isNil or ys.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or
      aggregation < cint(low(AggregationKind).ord) or
      aggregation > cint(high(AggregationKind).ord):
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UPLOT_ERR_ARGUMENT
    let
      inputXs = cast[ptr UncheckedArray[cstring]](xs)
      inputYs = cast[ptr UncheckedArray[cstring]](ys)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var copiedXs = newSeqOfCap[string](int(count))
    var copiedYs = newSeqOfCap[string](int(count))
    var copiedValues = newSeqOfCap[float64](int(count))
    for index in 0 ..< int(count):
      if inputXs[index].isNil or inputYs[index].isNil:
        return UPLOT_ERR_ARGUMENT
      copiedXs.add $inputXs[index]
      copiedYs.add $inputYs[index]
      copiedValues.add inputValues[index]
    h.spec = heatmapPlot(copiedXs, copiedYs, copiedValues,
      AggregationKind(aggregation))
    h.nextColumn = 0
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_add_numeric_heatmap*(value: pointer; xBreaks: ptr float64;
    xBreakCount: csize_t; yBreaks: ptr float64; yBreakCount: csize_t;
    values: ptr float64; valueCount: csize_t): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil or xBreaks.isNil or yBreaks.isNil or values.isNil or
      xBreakCount < 2 or yBreakCount < 2 or valueCount == 0 or
      xBreakCount > csize_t(high(int)) or
      yBreakCount > csize_t(high(int)) or valueCount > csize_t(high(int)):
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UPLOT_ERR_ARGUMENT
    let
      inputXBreaks = cast[ptr UncheckedArray[float64]](xBreaks)
      inputYBreaks = cast[ptr UncheckedArray[float64]](yBreaks)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var
      copiedXBreaks = newSeqOfCap[float64](int(xBreakCount))
      copiedYBreaks = newSeqOfCap[float64](int(yBreakCount))
      copiedValues = newSeqOfCap[float64](int(valueCount))
    for index in 0 ..< int(xBreakCount):
      copiedXBreaks.add inputXBreaks[index]
    for index in 0 ..< int(yBreakCount):
      copiedYBreaks.add inputYBreaks[index]
    for index in 0 ..< int(valueCount):
      copiedValues.add inputValues[index]
    h.spec = numericHeatmapPlot(copiedXBreaks, copiedYBreaks, copiedValues)
    h.nextColumn = 0
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_add_categorical_column*(value: pointer; name: cstring;
    values: ptr cstring; count: csize_t): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or name.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or ($name).len == 0:
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if int(count) != h.spec.data.rowCount: return UPLOT_ERR_ARGUMENT
    let input = cast[ptr UncheckedArray[cstring]](values)
    var copied = newSeqOfCap[string](int(count))
    for index in 0 ..< int(count):
      if input[index].isNil: return UPLOT_ERR_ARGUMENT
      copied.add $input[index]
    h.spec.data.addColumn($name, copied)
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_add_line_styled*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; width: float32;
    lineStyle: cint): cint {.exportc, dynlib, cdecl.} =
  if lineStyle < cint(low(LineStyle).ord) or
      lineStyle > cint(high(LineStyle).ord):
    return UPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkLine, color, width,
    LineStyle(lineStyle), missingValues = BreakOnMissing)

proc uplot_add_points_shaped*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; radius: float32;
    shape: cint): cint {.exportc, dynlib, cdecl.} =
  if shape < cint(low(MarkerShape).ord) or
      shape > cint(high(MarkerShape).ord):
    return UPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkPoint, color, radius,
    shape = MarkerShape(shape))

proc uplot_add_line_configured*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; width: float32; lineStyle,
    missingValues: cint): cint {.exportc, dynlib, cdecl.} =
  if lineStyle < cint(low(LineStyle).ord) or
      lineStyle > cint(high(LineStyle).ord) or
      missingValues < cint(low(MissingValuePolicy).ord) or
      missingValues > cint(high(MissingValuePolicy).ord):
    return UPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkLine, color, width,
    LineStyle(lineStyle), missingValues = MissingValuePolicy(missingValues))

proc uplot_add_points_configured*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; radius: float32; shape,
    missingValues: cint): cint {.exportc, dynlib, cdecl.} =
  if shape < cint(low(MarkerShape).ord) or
      shape > cint(high(MarkerShape).ord) or
      missingValues < cint(low(MissingValuePolicy).ord) or
      missingValues > cint(high(MissingValuePolicy).ord):
    return UPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkPoint, color, radius,
    shape = MarkerShape(shape),
    missingValues = MissingValuePolicy(missingValues))

proc uplot_set_title*(value: pointer; title: cstring): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil or title.isNil: return UPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.title = $title
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_set_secondary_y*(value: pointer; scale, offset: float64;
    label: cstring): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or label.isNil or not scale.isFinite or scale == 0 or
      not offset.isFinite:
    return UPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.secondaryY(scale, offset, $label)
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_clear_secondary_y*(value: pointer): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil: return UPLOT_ERR_ARGUMENT
  handle(value).spec.clearSecondaryY()
  UPLOT_OK

proc uplot_annotate_text*(value: pointer; x, y: float64; text,
    color: cstring; fontSize: float32): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or text.isNil or color.isNil: return UPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.annotateText(x, y, $text, $color, fontSize)
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_annotate_arrow*(value: pointer; x, y, xEnd, yEnd: float64;
    color: cstring; width, headSize: float32): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil or color.isNil: return UPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.annotateArrow(x, y, xEnd, yEnd, $color, width, headSize)
    UPLOT_OK
  except CatchableError, Defect:
    UPLOT_ERR_ARGUMENT

proc uplot_clear_annotations*(value: pointer): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil: return UPLOT_ERR_ARGUMENT
  handle(value).spec.clearAnnotations()
  UPLOT_OK

proc copyBuffer(bytes: openArray[byte]; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint =
  if output.isNil or outputLen.isNil: return UPLOT_ERR_ARGUMENT
  output[] = nil; outputLen[] = 0
  if bytes.len == 0: return UPLOT_OK
  let memory = cast[ptr uint8](allocShared(bytes.len))
  if memory.isNil: return UPLOT_ERR_RENDER
  copyMem(memory, unsafeAddr bytes[0], bytes.len)
  output[] = memory; outputLen[] = csize_t(bytes.len)
  UPLOT_OK

proc copyBuffer(bytes: string; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint =
  if bytes.len == 0: return copyBuffer([], output, outputLen)
  copyBuffer(bytes.toOpenArrayByte(0, bytes.high), output, outputLen)

proc uplot_plot_to_json*(value: pointer; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  if value.isNil: return UPLOT_ERR_ARGUMENT
  try:
    copyBuffer(handle(value).spec.toJson, output, outputLen)
  except CatchableError, Defect:
    if not output.isNil: output[] = nil
    if not outputLen.isNil: outputLen[] = 0
    UPLOT_ERR_RENDER

proc uplot_render_png*(value: pointer; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or fontPath.isNil: return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    copyBuffer(h.spec.compileScene(h.size).encodePng(loadTtf($fontPath)),
        output,
      outputLen)
  except CatchableError, Defect: UPLOT_ERR_RENDER

proc uplot_render_svg*(value: pointer; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or fontPath.isNil: return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    let svg = h.spec.compileScene(h.size).toSvg(loadTtf($fontPath))
    copyBuffer(svg.toOpenArrayByte(0, svg.high), output, outputLen)
  except CatchableError, Defect: UPLOT_ERR_RENDER

proc renderGrid(values: ptr pointer; count: csize_t; columns, width, height,
    gap: cint; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t; svg, sharedX, sharedY: bool): cint =
  if output.isNil or outputLen.isNil: return UPLOT_ERR_ARGUMENT
  output[] = nil
  outputLen[] = 0
  if values.isNil or count == 0 or count > csize_t(high(int)) or
      columns <= 0 or width <= 0 or height <= 0 or gap < 0 or fontPath.isNil:
    return UPLOT_ERR_ARGUMENT
  if csize_t(columns) > count:
    return UPLOT_ERR_ARGUMENT
  try:
    let handles = cast[ptr UncheckedArray[pointer]](values)
    var specs = newSeqOfCap[PlotSpec](int(count))
    for index in 0 ..< int(count):
      if handles[index].isNil: return UPLOT_ERR_ARGUMENT
      specs.add handle(handles[index]).spec
    let composed = compileGrid(specs, int(columns),
      Size(width: int(width), height: int(height)), int(gap), sharedX, sharedY)
    let font = loadTtf($fontPath)
    if svg:
      copyBuffer(composed.toSvg(font), output, outputLen)
    else:
      copyBuffer(composed.encodePng(font), output, outputLen)
  except CatchableError, Defect:
    output[] = nil
    outputLen[] = 0
    UPLOT_ERR_RENDER

proc uplot_render_grid_svg*(values: ptr pointer; count: csize_t;
    columns, width, height, gap: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, true, false, false)

proc uplot_render_grid_png*(values: ptr pointer; count: csize_t;
    columns, width, height, gap: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, false, false, false)

proc renderSharedGrid(values: ptr pointer; count: csize_t; columns, width,
    height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t; svg: bool): cint =
  if sharedX notin 0 .. 1 or sharedY notin 0 .. 1:
    if not output.isNil: output[] = nil
    if not outputLen.isNil: outputLen[] = 0
    return UPLOT_ERR_ARGUMENT
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, svg, sharedX == 1, sharedY == 1)

proc uplot_render_grid_svg_shared*(values: ptr pointer; count: csize_t;
    columns, width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderSharedGrid(values, count, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, true)

proc uplot_render_grid_png_shared*(values: ptr pointer; count: csize_t;
    columns, width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderSharedGrid(values, count, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, false)

proc renderFacetGrid(value: pointer; column: cstring; columns, width, height,
    gap, sharedX, sharedY: cint; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t; svg: bool): cint =
  if output.isNil or outputLen.isNil: return UPLOT_ERR_ARGUMENT
  output[] = nil
  outputLen[] = 0
  if value.isNil or column.isNil or ($column).len == 0 or columns <= 0 or
      width <= 0 or height <= 0 or gap < 0 or sharedX notin 0 .. 1 or
      sharedY notin 0 .. 1 or fontPath.isNil:
    return UPLOT_ERR_ARGUMENT
  try:
    let composed = compileFacetGrid(handle(value).spec, $column, int(columns),
      Size(width: int(width), height: int(height)), int(gap), sharedX == 1,
      sharedY == 1)
    let font = loadTtf($fontPath)
    if svg:
      copyBuffer(composed.toSvg(font), output, outputLen)
    else:
      copyBuffer(composed.encodePng(font), output, outputLen)
  except CatchableError, Defect:
    output[] = nil
    outputLen[] = 0
    UPLOT_ERR_RENDER

proc uplot_render_facet_grid_svg*(value: pointer; column: cstring; columns,
    width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderFacetGrid(value, column, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, true)

proc uplot_render_facet_grid_png*(value: pointer; column: cstring; columns,
    width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderFacetGrid(value, column, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, false)

proc renderFacetMatrix(value: pointer; rowColumn, columnColumn: cstring;
    width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t; svg: bool): cint =
  if output.isNil or outputLen.isNil: return UPLOT_ERR_ARGUMENT
  output[] = nil
  outputLen[] = 0
  if value.isNil or rowColumn.isNil or columnColumn.isNil or
      ($rowColumn).len == 0 or ($columnColumn).len == 0 or width <= 0 or
      height <= 0 or gap < 0 or sharedX notin 0 .. 1 or
      sharedY notin 0 .. 1 or fontPath.isNil:
    return UPLOT_ERR_ARGUMENT
  try:
    let composed = compileFacetMatrix(handle(value).spec, $rowColumn,
      $columnColumn, Size(width: int(width), height: int(height)), int(gap),
      sharedX == 1, sharedY == 1)
    let font = loadTtf($fontPath)
    if svg:
      copyBuffer(composed.toSvg(font), output, outputLen)
    else:
      copyBuffer(composed.encodePng(font), output, outputLen)
  except CatchableError, Defect:
    output[] = nil
    outputLen[] = 0
    UPLOT_ERR_RENDER

proc uplot_render_facet_matrix_svg*(value: pointer; rowColumn,
    columnColumn: cstring; width, height, gap, sharedX, sharedY: cint;
    fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  renderFacetMatrix(value, rowColumn, columnColumn, width, height, gap,
    sharedX, sharedY, fontPath, output, outputLen, true)

proc uplot_render_facet_matrix_png*(value: pointer; rowColumn,
    columnColumn: cstring; width, height, gap, sharedX, sharedY: cint;
    fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  renderFacetMatrix(value, rowColumn, columnColumn, width, height, gap,
    sharedX, sharedY, fontPath, output, outputLen, false)

proc uplot_buffer_free*(value: pointer; length: csize_t) {.
    exportc, dynlib, cdecl.} =
  if not value.isNil: deallocShared(value)

proc uplot_plot_free*(value: pointer) {.exportc, dynlib, cdecl.} =
  if not value.isNil: GC_unref(handle(value))
