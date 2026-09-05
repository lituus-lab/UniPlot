# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/tables
import UniColor
import UniGlyph
import UniImage/core as uimg
import UniPlot

const
  UNIPLOT_OK* = 0.cint
  UNIPLOT_ERR_ARGUMENT* = 1.cint
  UNIPLOT_ERR_RENDER* = 2.cint
  UNIPLOT_ERR_MEMORY* = 3.cint
  UNIPLOT_ABI_VERSION* = 1.cint

type PlotHandle = ref object
  spec: PlotSpec
  size: Size
  nextColumn: int

proc isBlankRecipeTarget(spec: PlotSpec): bool =
  let blank = plot(initDataFrame())
  spec.data.order.len == 0 and spec.data.rowCount == 0 and
    spec.layers.len == 0 and
    spec.title.len == 0 and spec.xLabel.len == 0 and spec.yLabel.len == 0 and
    spec.theme == blank.theme and
    spec.legendSpec == blank.legendSpec and
    spec.categoricalColors == blank.categoricalColors and
    spec.continuousColors == blank.continuousColors and
    spec.mappedSizeRange == blank.mappedSizeRange and
    spec.mappedAlphaRange == blank.mappedAlphaRange and
    spec.xScaleSpec == blank.xScaleSpec and
    spec.yScaleSpec == blank.yScaleSpec and
    spec.secondaryYSpec == blank.secondaryYSpec and
    spec.references.len == 0 and spec.annotations.len == 0 and
    spec.rasters.len == 0 and spec.imageResources.len == 0


proc NimMain() {.importc.}


# A shared library runs NimMain from DllMain (Windows) or an ELF constructor;
# a static one has neither, so nothing initializes the Nim runtime. The first
# entry point then enters Nim code whose globals were never set up and the
# process faults. The static-library tasks pass -d:staticNoAutoInit; shared
# builds must not, or NimMain runs twice.
when defined(staticNoAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE uniplot_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK uniplot_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void uniplot_runtime_ensure(void) {
  InitOnceExecuteOnce(&uniplot_runtime_once, uniplot_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t uniplot_runtime_once = PTHREAD_ONCE_INIT;
static void uniplot_runtime_init(void) { NimMain(); }
static void uniplot_runtime_ensure(void) {
  pthread_once(&uniplot_runtime_once, uniplot_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  uniplot_runtime_ensure();".}
else:
  template ensureRuntime() = discard


proc uniplot_init*(): cint {.exportc, dynlib, cdecl.} =
  ## Starting the runtime is `ensureRuntime`'s job and only its job: the
  ## once-primitive above already guarantees a single NimMain. Repeating it
  ## here behind a Nim global ran it twice in a static build -- module
  ## initialization resets that global, which is the trap the section above
  ## explains and this call reintroduced.
  ensureRuntime()
  UNIPLOT_OK

proc uniplot_version*(): cstring {.exportc, dynlib,
    cdecl.} =
  ensureRuntime()
  UniPlotVersion.cstring

proc uniplot_abi_version*(): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  UNIPLOT_ABI_VERSION

proc uniplot_plot_new*(width, height: cint): pointer {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  try:
    let size = Size(width: int(width), height: int(height))
    size.validate()
    var frame = initDataFrame()
    let handle = PlotHandle(spec: plot(frame), size: size)
    GC_ref(handle)
    cast[pointer](handle)
  except CatchableError, Defect: nil

proc uniplot_plot_from_json_status*(payload: ptr uint8; length: csize_t; width,
    height: cint; output: ptr pointer): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if output.isNil: return UNIPLOT_ERR_ARGUMENT
  output[] = nil
  if payload.isNil or length == 0 or length > csize_t(high(int)):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let size = Size(width: int(width), height: int(height))
    size.validate()
    var encoded = newString(int(length))
    copyMem(addr encoded[0], payload, int(length))
    let parsed = PlotHandle(spec: fromJson(encoded), size: size)
    GC_ref(parsed)
    output[] = cast[pointer](parsed)
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_plot_from_json*(payload: ptr uint8; length: csize_t; width,
    height: cint): pointer {.exportc, dynlib, cdecl.} =
  ## Compatibility entry point. New bindings should use the status API above.
  ensureRuntime()
  discard uniplot_plot_from_json_status(payload, length, width, height,
    addr result)

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

proc snapshotFrame(frame: DataFrame): DataFrame =
  ## Build an independent candidate so ABI mutations publish atomically.
  result = initDataFrame()
  for name in frame.order:
    case frame.columns[name].kind
    of ckNumeric:
      result.addColumn(name, frame.columns[name].numbers)
    of ckCategorical:
      result.addColumn(name, frame.columns[name].categories)

proc addSeries(value: pointer; xs, ys: ptr float64; count: csize_t;
    mark: MarkKind; color: cstring; size: float32;
    lineStyle = SolidLine; shape = CircleMarker;
    missingValues = DropMissing): cint =
  if value.isNil or xs.isNil or ys.isNil or count == 0 or color.isNil:
    return UNIPLOT_ERR_ARGUMENT
  if count > csize_t(high(int)):
    return UNIPLOT_ERR_ARGUMENT
  if size < 0 or not size.isFinite or parseColor($color).isErr:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    let inputCount = int(count)
    let targetCount = max(inputCount, h.spec.data.rowCount)
    var candidate = h.nextColumn
    while "x" & $candidate in h.spec.data.columns or
        "y" & $candidate in h.spec.data.columns:
      if candidate == high(int): return UNIPLOT_ERR_ARGUMENT
      inc candidate
    if candidate == high(int): return UNIPLOT_ERR_ARGUMENT
    var candidateSpec = h.spec
    candidateSpec.data = h.spec.data.snapshotFrame
    candidateSpec.layers = newSeqOfCap[Layer](h.spec.layers.len + 1)
    for layer in h.spec.layers: candidateSpec.layers.add layer
    candidateSpec.data.resizeFrame(targetCount)
    var xv = newSeq[float64](targetCount)
    var yv = newSeq[float64](targetCount)
    let xa = cast[ptr UncheckedArray[float64]](xs)
    let ya = cast[ptr UncheckedArray[float64]](ys)
    for i in 0 ..< inputCount:
      xv[i] = xa[i]; yv[i] = ya[i]
    for i in inputCount ..< targetCount:
      xv[i] = NaN; yv[i] = NaN
    let xName = "x" & $candidate
    let yName = "y" & $candidate
    candidateSpec.data.addColumn(xName, xv)
    candidateSpec.data.addColumn(yName, yv)
    candidateSpec.addLayer(mark, aes(xName, yName), $color, size,
      lineStyle = lineStyle, shape = shape, missingValues = missingValues)
    h.spec = candidateSpec
    h.nextColumn = candidate + 1
    UNIPLOT_OK
  except OutOfMemDefect: UNIPLOT_ERR_MEMORY
  except CatchableError, Defect: UNIPLOT_ERR_ARGUMENT

proc uniplot_add_line*(value: pointer; xs, ys: ptr float64; count: csize_t;
    color: cstring; width: float32): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  addSeries(value, xs, ys, count, mkLine, color, width,
    missingValues = BreakOnMissing)

proc uniplot_add_points*(value: pointer; xs, ys: ptr float64; count: csize_t;
    color: cstring; radius: float32): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  addSeries(value, xs, ys, count, mkPoint, color, radius)

proc uniplot_add_raster*(value: pointer; pixels: ptr uint8; length: csize_t;
    width, height, channels: cint; xMin, xMax, yMin, yMax: float64;
    filter: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or pixels.isNil or width <= 0 or height <= 0 or
      channels notin [1.cint, 3.cint, 4.cint] or filter < cint(RasterNearest) or
      filter > cint(RasterBox) or not xMin.isFinite or not xMax.isFinite or
      xMin >= xMax or not yMin.isFinite or not yMax.isFinite or yMin >= yMax:
    return UNIPLOT_ERR_ARGUMENT
  let
    w = int(width)
    h = int(height)
    ch = int(channels)
  if w > high(int) div h or w * h > high(int) div ch:
    return UNIPLOT_ERR_ARGUMENT
  let expected = w * h * ch
  if length != csize_t(expected):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let colorspace = case ch
      of 1: uimg.csGray
      of 3: uimg.csRgb
      else: uimg.csRgba
    var image = uimg.Image[uint8](width: w, height: h, channels: ch,
      colorspace: colorspace, data: newSeq[uint8](expected))
    copyMem(addr image.data[0], pixels, expected)
    handle(value).spec.rasters.add RasterLayer(image: image, xMin: xMin,
      xMax: xMax, yMin: yMin, yMax: yMax, filter: RasterFilter(filter))
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_raster_heatmap*(value: pointer; width, height: cint;
    values: ptr float64; valueCount: csize_t;
    xMin, xMax, yMin, yMax: float64; filter: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or values.isNil or width <= 0 or height <= 0 or
      filter < cint(RasterNearest) or filter > cint(RasterBox) or
      not xMin.isFinite or not xMax.isFinite or xMin >= xMax or
      not yMin.isFinite or not yMax.isFinite or yMin >= yMax:
    return UNIPLOT_ERR_ARGUMENT
  let
    w = int(width)
    h = int(height)
  if w > high(int) div h or valueCount != csize_t(w * h):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let hnd = handle(value)
    if not hnd.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let input = cast[ptr UncheckedArray[float64]](values)
    var copied = newSeqUninit[float64](w * h)
    for index in 0 ..< copied.len:
      copied[index] = input[index]
    let candidate = rasterHeatmapPlot(w, h, copied, xMin, xMax, yMin, yMax,
      RasterFilter(filter))
    hnd.spec = candidate
    hnd.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_image_mark*(value: pointer; pixels: ptr uint8; length: csize_t;
    width, height, channels: cint; xMin, xMax, yMin, yMax: float64;
    filter: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or pixels.isNil or width <= 0 or height <= 0 or
      channels notin [1.cint, 3.cint, 4.cint] or filter < cint(RasterNearest) or
      filter > cint(RasterBox) or not xMin.isFinite or not xMax.isFinite or
      xMin >= xMax or not yMin.isFinite or not yMax.isFinite or yMin >= yMax:
    return UNIPLOT_ERR_ARGUMENT
  let
    w = int(width)
    h = int(height)
    ch = int(channels)
  if w > high(int) div h or w * h > high(int) div ch:
    return UNIPLOT_ERR_ARGUMENT
  let expected = w * h * ch
  if length != csize_t(expected):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let
      colorspace = case ch
        of 1: uimg.csGray
        of 3: uimg.csRgb
        else: uimg.csRgba
      hnd = handle(value)
      targetCount = max(1, hnd.spec.data.rowCount)
    var candidate = hnd.nextColumn
    while true:
      let
        suffix = $candidate
        resourceName = "image-resource-" & suffix
        leftName = "image-left-" & suffix
        rightName = "image-right-" & suffix
        bottomName = "image-bottom-" & suffix
        topName = "image-top-" & suffix
        resourceColumn = "image-name-" & suffix
      var occupied = leftName in hnd.spec.data.columns or
        rightName in hnd.spec.data.columns or
        bottomName in hnd.spec.data.columns or
        topName in hnd.spec.data.columns or
        resourceColumn in hnd.spec.data.columns
      for resource in hnd.spec.imageResources:
        occupied = occupied or resource.name == resourceName
      if not occupied: break
      if candidate == high(int): return UNIPLOT_ERR_ARGUMENT
      inc candidate
    if candidate == high(int): return UNIPLOT_ERR_ARGUMENT
    let
      suffix = $candidate
      resourceName = "image-resource-" & suffix
      leftName = "image-left-" & suffix
      rightName = "image-right-" & suffix
      bottomName = "image-bottom-" & suffix
      topName = "image-top-" & suffix
      resourceColumn = "image-name-" & suffix
    var image = uimg.Image[uint8](width: w, height: h, channels: ch,
      colorspace: colorspace, data: newSeq[uint8](expected))
    copyMem(addr image.data[0], pixels, expected)
    var candidateSpec = hnd.spec
    candidateSpec.data = hnd.spec.data.snapshotFrame
    candidateSpec.layers = newSeqOfCap[Layer](hnd.spec.layers.len + 1)
    for layer in hnd.spec.layers: candidateSpec.layers.add layer
    candidateSpec.imageResources = newSeqOfCap[ImageResource](
      hnd.spec.imageResources.len + 1)
    for resource in hnd.spec.imageResources:
      candidateSpec.imageResources.add resource
    candidateSpec.data.resizeFrame(targetCount)
    var left = newSeq[float64](targetCount)
    var right = newSeq[float64](targetCount)
    var bottom = newSeq[float64](targetCount)
    var top = newSeq[float64](targetCount)
    var names = newSeq[string](targetCount)
    for index in 0 ..< targetCount:
      left[index] = NaN
      right[index] = NaN
      bottom[index] = NaN
      top[index] = NaN
    left[0] = xMin
    right[0] = xMax
    bottom[0] = yMin
    top[0] = yMax
    names[0] = resourceName
    candidateSpec.data.addColumn(leftName, left)
    candidateSpec.data.addColumn(rightName, right)
    candidateSpec.data.addColumn(bottomName, bottom)
    candidateSpec.data.addColumn(topName, top)
    candidateSpec.data.addColumn(resourceColumn, names)
    candidateSpec.imageResources.add ImageResource(name: resourceName,
      image: image)
    candidateSpec.geomImage(aes("", "", xMin = leftName, xMax = rightName,
      yMin = bottomName, yMax = topName, image = resourceColumn),
      RasterFilter(filter))
    hnd.spec = candidateSpec
    hnd.nextColumn = candidate + 1
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_box_plot*(value: pointer; groups: ptr cstring;
    values: ptr float64; count: csize_t; whiskerLength: float64; color,
    outlierColor: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or groups.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or color.isNil or outlierColor.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputGroups = cast[ptr UncheckedArray[cstring]](groups)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var copiedGroups = newSeqOfCap[string](int(count))
    var copiedValues = newSeqOfCap[float64](int(count))
    for index in 0 ..< int(count):
      if inputGroups[index].isNil: return UNIPLOT_ERR_ARGUMENT
      copiedGroups.add $inputGroups[index]
      copiedValues.add inputValues[index]
    h.spec = boxPlot(copiedGroups, copiedValues, whiskerLength, $color,
      $outlierColor)
    h.nextColumn = 0
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc addHistogram(value: pointer; values: ptr float64;
    valueCount: csize_t; breaks: ptr float64; breakCount: csize_t;
    color: cstring; numeric, density: bool): cint =
  if value.isNil or values.isNil or valueCount == 0 or breaks.isNil or
      breakCount < 2 or valueCount > csize_t(high(int)) or
      breakCount > csize_t(high(int)) or color.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UNIPLOT_ERR_ARGUMENT
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
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_histogram_breaks*(value: pointer; values: ptr float64;
    valueCount: csize_t; breaks: ptr float64; breakCount: csize_t;
    color: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  addHistogram(value, values, valueCount, breaks, breakCount, color,
    numeric = false, density = false)

proc uniplot_add_numeric_histogram*(value: pointer; values: ptr float64;
    valueCount: csize_t; breaks: ptr float64; breakCount: csize_t;
    density: cint; color: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if density notin [cint(0), cint(1)]: return UNIPLOT_ERR_ARGUMENT
  addHistogram(value, values, valueCount, breaks, breakCount, color,
    numeric = true, density = density == 1)

proc uniplot_add_automatic_histogram*(value: pointer; values: ptr float64;
    valueCount: csize_t; rule, density: cint; color: cstring): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or values.isNil or valueCount == 0 or
      valueCount > csize_t(high(int)) or color.isNil or
      rule < cint(low(HistogramRule).ord) or
      rule > cint(high(HistogramRule).ord) or
      density notin [cint(0), cint(1)]:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let inputValues = cast[ptr UncheckedArray[float64]](values)
    var copiedValues = newSeqUninit[float64](int(valueCount))
    for index in 0 ..< copiedValues.len:
      copiedValues[index] = inputValues[index]
    let candidate = histogramPlot(copiedValues, HistogramRule(rule),
      density == 1, $color)
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_linear_smooth*(value: pointer; valuesX, valuesY: ptr float64;
    count: csize_t; pointCount: cint; confidenceLevel: float64;
    showConfidence: cint; lineColor, bandColor: cstring): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or valuesX.isNil or valuesY.isNil or count < 3 or
      count > csize_t(high(int)) or pointCount < 2 or pointCount > 10_000 or
      showConfidence notin [cint(0), cint(1)] or lineColor.isNil or
      bandColor.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputX = cast[ptr UncheckedArray[float64]](valuesX)
      inputY = cast[ptr UncheckedArray[float64]](valuesY)
    var
      copiedX = newSeqUninit[float64](int(count))
      copiedY = newSeqUninit[float64](int(count))
    for index in 0 ..< int(count):
      copiedX[index] = inputX[index]
      copiedY[index] = inputY[index]
    let candidate = linearSmoothPlot(copiedX, copiedY, int(pointCount),
      confidenceLevel, showConfidence == 1, $lineColor, $bandColor)
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_polynomial_smooth*(value: pointer;
    valuesX, valuesY: ptr float64; count: csize_t; degree,
    pointCount: cint; lineColor: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or valuesX.isNil or valuesY.isNil or count < 3 or
      count > csize_t(high(int)) or degree < 1 or degree > 8 or
      pointCount < 2 or pointCount > 10_000 or lineColor.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputX = cast[ptr UncheckedArray[float64]](valuesX)
      inputY = cast[ptr UncheckedArray[float64]](valuesY)
    var
      copiedX = newSeqUninit[float64](int(count))
      copiedY = newSeqUninit[float64](int(count))
    for index in 0 ..< int(count):
      copiedX[index] = inputX[index]
      copiedY[index] = inputY[index]
    let candidate = polynomialSmoothPlot(copiedX, copiedY, int(degree),
      int(pointCount), $lineColor)
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_density*(value: pointer; values: ptr float64; count: csize_t;
    pointCount: cint; bandwidth: float64;
    fillColor, lineColor: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or values.isNil or count < 2 or
      count > csize_t(high(int)) or pointCount < 2 or pointCount > 100_000 or
      fillColor.isNil or lineColor.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let input = cast[ptr UncheckedArray[float64]](values)
    var copied = newSeqUninit[float64](int(count))
    for index in 0 ..< copied.len:
      copied[index] = input[index]
    let candidate = densityPlot(copied, int(pointCount), bandwidth,
      $fillColor, $lineColor)
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_violin*(value: pointer; values: ptr float64; count: csize_t;
    pointCount: cint; bandwidth, width: float64; color: cstring): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or values.isNil or count < 2 or
      count > csize_t(high(int)) or pointCount < 2 or pointCount > 100_000 or
      bandwidth < 0.0 or not bandwidth.isFinite or width <= 0.0 or
      not width.isFinite or color.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let input = cast[ptr UncheckedArray[float64]](values)
    var copied = newSeqUninit[float64](int(count))
    for index in 0 ..< copied.len:
      copied[index] = input[index]
    let candidate = violinPlot(copied, int(pointCount), bandwidth, width,
      $color)
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_grouped_violin*(value: pointer; groups: ptr cstring;
    values: ptr float64; count: csize_t; pointCount: cint;
    bandwidth, width: float64; color: cstring): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or groups.isNil or values.isNil or count < 2 or
      count > csize_t(high(int)) or pointCount < 2 or pointCount > 100_000 or
      bandwidth < 0.0 or not bandwidth.isFinite or width <= 0.0 or
      width > 1.0 or not width.isFinite or color.isNil:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputGroups = cast[ptr UncheckedArray[cstring]](groups)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var
      copiedGroups = newSeqOfCap[string](int(count))
      copiedValues = newSeqUninit[float64](int(count))
    for index in 0 ..< int(count):
      if inputGroups[index].isNil: return UNIPLOT_ERR_ARGUMENT
      copiedGroups.add $inputGroups[index]
      copiedValues[index] = inputValues[index]
    let candidate = violinPlot(copiedGroups, copiedValues, int(pointCount),
      bandwidth, width, $color)
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_contours*(value: pointer; xs: ptr float64; xCount: csize_t;
    ys: ptr float64; yCount: csize_t; values: ptr float64;
    valueCount: csize_t; levels: ptr float64; levelCount: csize_t;
    color: cstring; width: float64): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or xs.isNil or ys.isNil or values.isNil or levels.isNil or
      color.isNil or xCount < 2 or yCount < 2 or levelCount == 0 or
      xCount > csize_t(high(int)) or yCount > csize_t(high(int)) or
      valueCount > csize_t(high(int)) or levelCount > csize_t(high(int)) or
      xCount > csize_t(high(int)) div yCount or valueCount != xCount * yCount or
      width < 0.0 or not width.isFinite or width > float64(high(float32)):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if not h.spec.isBlankRecipeTarget:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputXs = cast[ptr UncheckedArray[float64]](xs)
      inputYs = cast[ptr UncheckedArray[float64]](ys)
      inputValues = cast[ptr UncheckedArray[float64]](values)
      inputLevels = cast[ptr UncheckedArray[float64]](levels)
    var
      copiedXs = newSeqUninit[float64](int(xCount))
      copiedYs = newSeqUninit[float64](int(yCount))
      copiedValues = newSeqUninit[float64](int(valueCount))
      copiedLevels = newSeqUninit[float64](int(levelCount))
    for index in 0 ..< copiedXs.len: copiedXs[index] = inputXs[index]
    for index in 0 ..< copiedYs.len: copiedYs[index] = inputYs[index]
    for index in 0 ..< copiedValues.len:
      copiedValues[index] = inputValues[index]
    for index in 0 ..< copiedLevels.len:
      copiedLevels[index] = inputLevels[index]
    let candidate = contourPlot(copiedXs, copiedYs, copiedValues,
      copiedLevels, $color, float32(width))
    h.spec = candidate
    h.nextColumn = 0
    UNIPLOT_OK
  except OutOfMemDefect:
    UNIPLOT_ERR_MEMORY
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_grouped_aggregate*(value: pointer; groups: ptr cstring;
    values: ptr float64; count: csize_t; aggregation: cint;
    color: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or groups.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or color.isNil or
      aggregation < cint(low(AggregationKind).ord) or
      aggregation > cint(high(AggregationKind).ord):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputGroups = cast[ptr UncheckedArray[cstring]](groups)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var
      copiedGroups = newSeqOfCap[string](int(count))
      copiedValues = newSeqOfCap[float64](int(count))
    for index in 0 ..< int(count):
      if inputGroups[index].isNil: return UNIPLOT_ERR_ARGUMENT
      copiedGroups.add $inputGroups[index]
      copiedValues.add inputValues[index]
    h.spec = groupedAggregatePlot(copiedGroups, copiedValues,
      AggregationKind(aggregation), $color)
    h.nextColumn = 0
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_heatmap*(value: pointer; xs, ys: ptr cstring;
    values: ptr float64; count: csize_t; aggregation: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or xs.isNil or ys.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or
      aggregation < cint(low(AggregationKind).ord) or
      aggregation > cint(high(AggregationKind).ord):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UNIPLOT_ERR_ARGUMENT
    let
      inputXs = cast[ptr UncheckedArray[cstring]](xs)
      inputYs = cast[ptr UncheckedArray[cstring]](ys)
      inputValues = cast[ptr UncheckedArray[float64]](values)
    var copiedXs = newSeqOfCap[string](int(count))
    var copiedYs = newSeqOfCap[string](int(count))
    var copiedValues = newSeqOfCap[float64](int(count))
    for index in 0 ..< int(count):
      if inputXs[index].isNil or inputYs[index].isNil:
        return UNIPLOT_ERR_ARGUMENT
      copiedXs.add $inputXs[index]
      copiedYs.add $inputYs[index]
      copiedValues.add inputValues[index]
    h.spec = heatmapPlot(copiedXs, copiedYs, copiedValues,
      AggregationKind(aggregation))
    h.nextColumn = 0
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_numeric_heatmap*(value: pointer; xBreaks: ptr float64;
    xBreakCount: csize_t; yBreaks: ptr float64; yBreakCount: csize_t;
    values: ptr float64; valueCount: csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or xBreaks.isNil or yBreaks.isNil or values.isNil or
      xBreakCount < 2 or yBreakCount < 2 or valueCount == 0 or
      xBreakCount > csize_t(high(int)) or
      yBreakCount > csize_t(high(int)) or valueCount > csize_t(high(int)):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if h.spec.layers.len > 0 or h.spec.data.rowCount > 0:
      return UNIPLOT_ERR_ARGUMENT
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
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_categorical_column*(value: pointer; name: cstring;
    values: ptr cstring; count: csize_t): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or name.isNil or values.isNil or count == 0 or
      count > csize_t(high(int)) or ($name).len == 0:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    if int(count) != h.spec.data.rowCount: return UNIPLOT_ERR_ARGUMENT
    let input = cast[ptr UncheckedArray[cstring]](values)
    var copied = newSeqOfCap[string](int(count))
    for index in 0 ..< int(count):
      if input[index].isNil: return UNIPLOT_ERR_ARGUMENT
      copied.add $input[index]
    h.spec.data.addColumn($name, copied)
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_add_line_styled*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; width: float32;
    lineStyle: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if lineStyle < cint(low(LineStyle).ord) or
      lineStyle > cint(high(LineStyle).ord):
    return UNIPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkLine, color, width,
    LineStyle(lineStyle), missingValues = BreakOnMissing)

proc uniplot_add_points_shaped*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; radius: float32;
    shape: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if shape < cint(low(MarkerShape).ord) or
      shape > cint(high(MarkerShape).ord):
    return UNIPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkPoint, color, radius,
    shape = MarkerShape(shape))

proc uniplot_add_line_configured*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; width: float32; lineStyle,
    missingValues: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if lineStyle < cint(low(LineStyle).ord) or
      lineStyle > cint(high(LineStyle).ord) or
      missingValues < cint(low(MissingValuePolicy).ord) or
      missingValues > cint(high(MissingValuePolicy).ord):
    return UNIPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkLine, color, width,
    LineStyle(lineStyle), missingValues = MissingValuePolicy(missingValues))

proc uniplot_add_points_configured*(value: pointer; xs, ys: ptr float64;
    count: csize_t; color: cstring; radius: float32; shape,
    missingValues: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if shape < cint(low(MarkerShape).ord) or
      shape > cint(high(MarkerShape).ord) or
      missingValues < cint(low(MissingValuePolicy).ord) or
      missingValues > cint(high(MissingValuePolicy).ord):
    return UNIPLOT_ERR_ARGUMENT
  addSeries(value, xs, ys, count, mkPoint, color, radius,
    shape = MarkerShape(shape),
    missingValues = MissingValuePolicy(missingValues))

proc uniplot_set_title*(value: pointer; title: cstring): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or title.isNil: return UNIPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.title = $title
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc setAxisLabels(value: pointer; labels, reversed: cint;
    xAxis: bool): cint =
  if value.isNil or labels < cint(low(AxisLabelKind).ord) or
      labels > cint(high(AxisLabelKind).ord) or reversed notin [0.cint, 1.cint]:
    return UNIPLOT_ERR_ARGUMENT
  let hnd = handle(value)
  let direction = reversed == 1
  case AxisLabelKind(labels)
  of alkNumeric:
    if xAxis: hnd.spec.scaleX(skLinear, direction)
    else: hnd.spec.scaleY(skLinear, direction)
  of alkUtcDateTime:
    if xAxis: hnd.spec.scaleXUtc(direction)
    else: hnd.spec.scaleYUtc(direction)
  of alkDuration:
    if xAxis: hnd.spec.scaleXDuration(direction)
    else: hnd.spec.scaleYDuration(direction)
  UNIPLOT_OK

proc uniplot_set_x_axis_labels*(value: pointer; labels, reversed: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  setAxisLabels(value, labels, reversed, true)

proc uniplot_set_y_axis_labels*(value: pointer; labels, reversed: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  setAxisLabels(value, labels, reversed, false)

proc setAxisScale(value: pointer; kind, reversed: cint; xAxis: bool): cint =
  if value.isNil or kind < cint(low(ScaleKind).ord) or
      kind > cint(high(ScaleKind).ord) or reversed notin [0.cint, 1.cint]:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let hnd = handle(value)
    if xAxis: hnd.spec.scaleX(ScaleKind(kind), reversed == 1)
    else: hnd.spec.scaleY(ScaleKind(kind), reversed == 1)
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_set_x_scale*(value: pointer; kind, reversed: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  setAxisScale(value, kind, reversed, true)

proc uniplot_set_y_scale*(value: pointer; kind, reversed: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  setAxisScale(value, kind, reversed, false)

proc setPowerScale(value: pointer; exponent: float64; reversed: cint;
    xAxis: bool): cint =
  if value.isNil or exponent <= 0.0 or not exponent.isFinite or
      reversed notin [0.cint, 1.cint]:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let hnd = handle(value)
    if xAxis: hnd.spec.scaleXPower(exponent, reversed == 1)
    else: hnd.spec.scaleYPower(exponent, reversed == 1)
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_set_x_power_scale*(value: pointer; exponent: float64;
    reversed: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  setPowerScale(value, exponent, reversed, true)

proc uniplot_set_y_power_scale*(value: pointer; exponent: float64;
    reversed: cint): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  setPowerScale(value, exponent, reversed, false)

proc uniplot_set_coordinates*(value: pointer; coordinates: cint): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or coordinates < cint(low(CoordinateKind).ord) or
      coordinates > cint(high(CoordinateKind).ord):
    return UNIPLOT_ERR_ARGUMENT
  try:
    let hnd = handle(value)
    case CoordinateKind(coordinates)
    of CartesianCoordinates: hnd.spec.coordCartesian()
    of PolarCoordinates: hnd.spec.coordPolar()
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_set_secondary_y*(value: pointer; scale, offset: float64;
    label: cstring): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or label.isNil or not scale.isFinite or scale == 0 or
      not offset.isFinite:
    return UNIPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.secondaryY(scale, offset, $label)
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_clear_secondary_y*(value: pointer): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil: return UNIPLOT_ERR_ARGUMENT
  handle(value).spec.clearSecondaryY()
  UNIPLOT_OK

proc uniplot_annotate_text*(value: pointer; x, y: float64; text,
    color: cstring; fontSize: float32): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or text.isNil or color.isNil: return UNIPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.annotateText(x, y, $text, $color, fontSize)
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_annotate_arrow*(value: pointer; x, y, xEnd, yEnd: float64;
    color: cstring; width, headSize: float32): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or color.isNil: return UNIPLOT_ERR_ARGUMENT
  try:
    handle(value).spec.annotateArrow(x, y, xEnd, yEnd, $color, width, headSize)
    UNIPLOT_OK
  except CatchableError, Defect:
    UNIPLOT_ERR_ARGUMENT

proc uniplot_clear_annotations*(value: pointer): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil: return UNIPLOT_ERR_ARGUMENT
  handle(value).spec.clearAnnotations()
  UNIPLOT_OK

proc copyBuffer(bytes: openArray[byte]; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint =
  if output.isNil or outputLen.isNil: return UNIPLOT_ERR_ARGUMENT
  output[] = nil; outputLen[] = 0
  if bytes.len == 0: return UNIPLOT_OK
  let memory = cast[ptr uint8](allocShared(bytes.len))
  if memory.isNil: return UNIPLOT_ERR_RENDER
  copyMem(memory, unsafeAddr bytes[0], bytes.len)
  output[] = memory; outputLen[] = csize_t(bytes.len)
  UNIPLOT_OK

proc copyBuffer(bytes: string; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint =
  if bytes.len == 0: return copyBuffer([], output, outputLen)
  copyBuffer(bytes.toOpenArrayByte(0, bytes.high), output, outputLen)

proc uniplot_plot_to_json*(value: pointer; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil: return UNIPLOT_ERR_ARGUMENT
  try:
    copyBuffer(handle(value).spec.toJson, output, outputLen)
  except CatchableError, Defect:
    if not output.isNil: output[] = nil
    if not outputLen.isNil: outputLen[] = 0
    UNIPLOT_ERR_RENDER

proc uniplot_render_png*(value: pointer; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or fontPath.isNil: return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    copyBuffer(h.spec.compileScene(h.size).encodePng(loadTtf($fontPath)),
        output,
      outputLen)
  except CatchableError, Defect: UNIPLOT_ERR_RENDER

proc uniplot_render_svg*(value: pointer; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if value.isNil or fontPath.isNil: return UNIPLOT_ERR_ARGUMENT
  try:
    let h = handle(value)
    let svg = h.spec.compileScene(h.size).toSvg(loadTtf($fontPath))
    copyBuffer(svg.toOpenArrayByte(0, svg.high), output, outputLen)
  except CatchableError, Defect: UNIPLOT_ERR_RENDER

proc renderGrid(values: ptr pointer; count: csize_t; columns, width, height,
    gap: cint; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t; svg, sharedX, sharedY: bool): cint =
  if output.isNil or outputLen.isNil: return UNIPLOT_ERR_ARGUMENT
  output[] = nil
  outputLen[] = 0
  if values.isNil or count == 0 or count > csize_t(high(int)) or
      columns <= 0 or width <= 0 or height <= 0 or gap < 0 or fontPath.isNil:
    return UNIPLOT_ERR_ARGUMENT
  if csize_t(columns) > count:
    return UNIPLOT_ERR_ARGUMENT
  try:
    let handles = cast[ptr UncheckedArray[pointer]](values)
    var specs = newSeqOfCap[PlotSpec](int(count))
    for index in 0 ..< int(count):
      if handles[index].isNil: return UNIPLOT_ERR_ARGUMENT
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
    UNIPLOT_ERR_RENDER

proc uniplot_render_grid_svg*(values: ptr pointer; count: csize_t;
    columns, width, height, gap: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, true, false, false)

proc uniplot_render_grid_png*(values: ptr pointer; count: csize_t;
    columns, width, height, gap: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, false, false, false)

proc renderSharedGrid(values: ptr pointer; count: csize_t; columns, width,
    height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t; svg: bool): cint =
  if sharedX notin 0 .. 1 or sharedY notin 0 .. 1:
    if not output.isNil: output[] = nil
    if not outputLen.isNil: outputLen[] = 0
    return UNIPLOT_ERR_ARGUMENT
  renderGrid(values, count, columns, width, height, gap, fontPath, output,
    outputLen, svg, sharedX == 1, sharedY == 1)

proc uniplot_render_grid_svg_shared*(values: ptr pointer; count: csize_t;
    columns, width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderSharedGrid(values, count, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, true)

proc uniplot_render_grid_png_shared*(values: ptr pointer; count: csize_t;
    columns, width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderSharedGrid(values, count, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, false)

proc renderFacetGrid(value: pointer; column: cstring; columns, width, height,
    gap, sharedX, sharedY: cint; fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t; svg: bool): cint =
  if output.isNil or outputLen.isNil: return UNIPLOT_ERR_ARGUMENT
  output[] = nil
  outputLen[] = 0
  if value.isNil or column.isNil or ($column).len == 0 or columns <= 0 or
      width <= 0 or height <= 0 or gap < 0 or sharedX notin 0 .. 1 or
      sharedY notin 0 .. 1 or fontPath.isNil:
    return UNIPLOT_ERR_ARGUMENT
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
    UNIPLOT_ERR_RENDER

proc uniplot_render_facet_grid_svg*(value: pointer; column: cstring; columns,
    width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderFacetGrid(value, column, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, true)

proc uniplot_render_facet_grid_png*(value: pointer; column: cstring; columns,
    width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t): cint {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderFacetGrid(value, column, columns, width, height, gap, sharedX,
    sharedY, fontPath, output, outputLen, false)

proc renderFacetMatrix(value: pointer; rowColumn, columnColumn: cstring;
    width, height, gap, sharedX, sharedY: cint; fontPath: cstring;
    output: ptr ptr uint8; outputLen: ptr csize_t; svg: bool): cint =
  if output.isNil or outputLen.isNil: return UNIPLOT_ERR_ARGUMENT
  output[] = nil
  outputLen[] = 0
  if value.isNil or rowColumn.isNil or columnColumn.isNil or
      ($rowColumn).len == 0 or ($columnColumn).len == 0 or width <= 0 or
      height <= 0 or gap < 0 or sharedX notin 0 .. 1 or
      sharedY notin 0 .. 1 or fontPath.isNil:
    return UNIPLOT_ERR_ARGUMENT
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
    UNIPLOT_ERR_RENDER

proc uniplot_render_facet_matrix_svg*(value: pointer; rowColumn,
    columnColumn: cstring; width, height, gap, sharedX, sharedY: cint;
    fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderFacetMatrix(value, rowColumn, columnColumn, width, height, gap,
    sharedX, sharedY, fontPath, output, outputLen, true)

proc uniplot_render_facet_matrix_png*(value: pointer; rowColumn,
    columnColumn: cstring; width, height, gap, sharedX, sharedY: cint;
    fontPath: cstring; output: ptr ptr uint8;
    outputLen: ptr csize_t): cint {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  renderFacetMatrix(value, rowColumn, columnColumn, width, height, gap,
    sharedX, sharedY, fontPath, output, outputLen, false)

proc uniplot_buffer_free*(value: pointer; length: csize_t) {.
    exportc, dynlib, cdecl.} =
  ensureRuntime()
  if not value.isNil: deallocShared(value)

proc uniplot_plot_free*(value: pointer) {.exportc, dynlib, cdecl.} =
  ensureRuntime()
  if not value.isNil: GC_unref(handle(value))
