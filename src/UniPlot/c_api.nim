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
    outputLen: ptr csize_t; svg: bool): cint =
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
      Size(width: int(width), height: int(height)), int(gap))
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
    outputLen, true)

proc uplot_render_grid_png*(values: ptr pointer; count: csize_t;
    columns, width, height, gap: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, false)

proc uplot_buffer_free*(value: pointer; length: csize_t) {.
    exportc, dynlib, cdecl.} =
  if not value.isNil: deallocShared(value)

proc uplot_plot_free*(value: pointer) {.exportc, dynlib, cdecl.} =
  if not value.isNil: GC_unref(handle(value))
