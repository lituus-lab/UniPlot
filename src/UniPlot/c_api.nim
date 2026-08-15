# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/locks
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
  except CatchableError: nil

proc handle(value: pointer): PlotHandle {.inline.} = cast[PlotHandle](value)

proc addSeries(value: pointer; xs, ys: ptr float64; count: csize_t;
    mark: MarkKind; color: cstring; size: float32;
    lineStyle = SolidLine; shape = CircleMarker): cint =
  if value.isNil or xs.isNil or ys.isNil or count == 0 or color.isNil:
    return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    var xv = newSeq[float64](int(count))
    var yv = newSeq[float64](int(count))
    let xa = cast[ptr UncheckedArray[float64]](xs)
    let ya = cast[ptr UncheckedArray[float64]](ys)
    for i in 0 ..< int(count):
      xv[i] = xa[i]; yv[i] = ya[i]
    let xName = "x" & $h.nextColumn
    let yName = "y" & $h.nextColumn
    inc h.nextColumn
    h.spec.data.addColumn(xName, xv)
    h.spec.data.addColumn(yName, yv)
    h.spec.addLayer(mark, aes(xName, yName), $color, size,
      lineStyle = lineStyle, shape = shape)
    UPLOT_OK
  except CatchableError: UPLOT_ERR_ARGUMENT

proc uplot_add_line*(value: pointer; xs, ys: ptr float64; count: csize_t;
    color: cstring; width: float32): cint {.exportc, dynlib, cdecl.} =
  addSeries(value, xs, ys, count, mkLine, color, width)

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
    LineStyle(lineStyle))

proc uplot_add_points_shaped*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; radius: float32;
    shape: cint): cint {.exportc, dynlib, cdecl.} =
  if shape < cint(low(MarkerShape).ord) or
      shape > cint(high(MarkerShape).ord):
    return UPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkPoint, color, radius,
    shape = MarkerShape(shape))

proc uplot_set_title*(value: pointer; title: cstring): cint {.
    exportc, dynlib, cdecl.} =
  if value.isNil or title.isNil: return UPLOT_ERR_ARGUMENT
  handle(value).spec.title = $title
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

proc uplot_render_png*(value: pointer; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or fontPath.isNil: return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    copyBuffer(h.spec.compileScene(h.size).encodePng(loadTtf($fontPath)),
        output,
      outputLen)
  except CatchableError: UPLOT_ERR_RENDER

proc uplot_render_svg*(value: pointer; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  if value.isNil or fontPath.isNil: return UPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    let svg = h.spec.compileScene(h.size).toSvg(loadTtf($fontPath))
    copyBuffer(svg.toOpenArrayByte(0, svg.high), output, outputLen)
  except CatchableError: UPLOT_ERR_RENDER

proc uplot_buffer_free*(value: pointer; length: csize_t) {.
    exportc, dynlib, cdecl.} =
  if not value.isNil: deallocShared(value)

proc uplot_plot_free*(value: pointer) {.exportc, dynlib, cdecl.} =
  if not value.isNil: GC_unref(handle(value))
