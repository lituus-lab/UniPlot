# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Deterministic composition of independently compiled plots.
import std/tables
import UniVector
import contracts
import UniPlot/[common, data, scales, grammar, scene, guides]

type
  FacetCell* = object
    rowValue*, columnValue*: string
    rows*: seq[int]

  GridCell = object
    spec: PlotSpec
    empty: bool
    title: string

func composedId(panel: int; nodeId: uint64): uint64 {.inline.} =
  if nodeId == 0: return 0
  var value = nodeId xor (uint64(panel + 1) * 0x9e3779b97f4a7c15'u64)
  value = (value xor (value shr 30)) * 0xbf58476d1ce4e5b9'u64
  value = (value xor (value shr 27)) * 0x94d049bb133111eb'u64
  result = value xor (value shr 31)
  if result == 0: result = 1

proc validateFacetColumn(spec: PlotSpec; column: string) =
  if column.len == 0:
    raise newException(PlotError, "facet column name cannot be empty")
  if column notin spec.data.columns or
      spec.data.columns[column].kind != ckCategorical:
    raise newException(PlotError,
      "faceting requires an existing categorical column")

proc facetSpecs*(spec: PlotSpec; column: string): seq[PlotSpec] {.
    contractual.} =
  ## Split a specification by a categorical column in first-seen order.
  require:
    column.len > 0
  ensure:
    result.len > 0
  body:
    spec.validateFacetColumn(column)
    var
      order: seq[string]
      rows = initTable[string, seq[int]]()
    for row, category in spec.data.categorical(column):
      if category notin rows: order.add category
      rows.mgetOrPut(category, @[]).add row
    if order.len == 0:
      raise newException(PlotError, "cannot facet an empty categorical column")
    result = newSeqOfCap[PlotSpec](order.len)
    for category in order:
      var panel = spec
      panel.data = spec.data.selectRows(rows[category])
      let facetTitle = column & " = " & category
      panel.title = if spec.title.len > 0:
        spec.title & " — " & facetTitle
      else:
        facetTitle
      result.add panel

proc facetCells*(spec: PlotSpec; rowColumn,
    columnColumn: string): seq[FacetCell] {.contractual.} =
  ## Build a complete row-major Cartesian facet matrix, including empty cells.
  require:
    rowColumn.len > 0 and columnColumn.len > 0
    rowColumn != columnColumn
  ensure:
    result.len > 0
  body:
    if rowColumn == columnColumn:
      raise newException(PlotError, "facet row and column must be different")
    spec.validateFacetColumn(rowColumn)
    spec.validateFacetColumn(columnColumn)
    var
      rowOrder, columnOrder: seq[string]
      rowSeen, columnSeen = initTable[string, bool]()
      grouped = initTable[(string, string), seq[int]]()
    let
      rowValues = spec.data.categorical(rowColumn)
      columnValues = spec.data.categorical(columnColumn)
    for index in 0 ..< spec.data.rowCount:
      let rowValue = rowValues[index]
      let columnValue = columnValues[index]
      if rowValue notin rowSeen:
        rowSeen[rowValue] = true
        rowOrder.add rowValue
      if columnValue notin columnSeen:
        columnSeen[columnValue] = true
        columnOrder.add columnValue
      grouped.mgetOrPut((rowValue, columnValue), @[]).add index
    if rowOrder.len == 0 or columnOrder.len == 0:
      raise newException(PlotError, "cannot facet empty categorical columns")
    result = newSeqOfCap[FacetCell](rowOrder.len * columnOrder.len)
    for rowValue in rowOrder:
      for columnValue in columnOrder:
        result.add FacetCell(rowValue: rowValue, columnValue: columnValue,
          rows: grouped.getOrDefault((rowValue, columnValue)))

proc shareDomains(specs: openArray[PlotSpec]; shareX,
    shareY: bool): seq[PlotSpec] =
  result = @specs
  if not shareX and not shareY: return
  var
    xDomain = initContinuousDomain()
    xBand = initBandDomain()
    yDomain = initContinuousDomain()
    yBand = initBandDomain()
    initialized = false
    coordinates = CartesianCoordinates
    xCoordinateKind, yCoordinateKind = ckNumeric
    xKind = skLinear
    yKind = skLinear
    xExponent = 1.0
    yExponent = 1.0
    xLabelKind = alkNumeric
    yLabelKind = alkNumeric
    xReversed = false
    yReversed = false
  for spec in specs:
    let domains = collectAxisDomains(spec)
    if not initialized:
      coordinates = spec.coordinates
      xKind = spec.xScaleSpec.kind
      xExponent = spec.xScaleSpec.exponent
      xLabelKind = spec.xScaleSpec.labelKind
      xCoordinateKind = domains.xKind
      yCoordinateKind = domains.yKind
      yKind = spec.yScaleSpec.kind
      yExponent = spec.yScaleSpec.exponent
      yLabelKind = spec.yScaleSpec.labelKind
      xReversed = spec.xScaleSpec.reversed
      yReversed = spec.yScaleSpec.reversed
      xDomain = initContinuousDomain(xKind, xExponent)
      yDomain = initContinuousDomain(yKind, yExponent)
      initialized = true
    if (shareX or shareY) and spec.coordinates != coordinates:
      raise newException(PlotError,
        "shared axes require matching coordinate systems")
    if shareX:
      if domains.xKind != xCoordinateKind:
        raise newException(PlotError,
          "shared x axes require matching coordinate kinds")
      if spec.xScaleSpec.kind != xKind or
          spec.xScaleSpec.exponent != xExponent or
          spec.xScaleSpec.labelKind != xLabelKind or
          spec.xScaleSpec.reversed != xReversed:
        raise newException(PlotError,
          "shared x axes require matching transforms, labels and directions")
      if domains.xKind == ckNumeric:
        if spec.xScaleSpec.categories.configured:
          raise newException(PlotError,
            "categorical x domain cannot be applied to numeric coordinates")
        if spec.xScaleSpec.domain.configured:
          discard domains.xContinuous.train(0, 1,
            spec.xScaleSpec.domain.minimum, spec.xScaleSpec.domain.maximum)
        xDomain.merge(domains.xContinuous)
        if spec.xScaleSpec.domain.configured:
          xDomain.addValues([spec.xScaleSpec.domain.minimum,
            spec.xScaleSpec.domain.maximum])
      else:
        if spec.xScaleSpec.domain.configured:
          raise newException(PlotError,
            "numeric x limits cannot be applied to categorical coordinates")
        if spec.xScaleSpec.categories.configured:
          discard domains.xBand.train(0, 1,
            spec.xScaleSpec.categories.values)
          xBand.addValues(spec.xScaleSpec.categories.values)
        xBand.merge(domains.xBand)
    if shareY:
      if domains.yKind != yCoordinateKind:
        raise newException(PlotError,
          "shared y axes require matching coordinate kinds")
      if spec.yScaleSpec.kind != yKind or
          spec.yScaleSpec.exponent != yExponent or
          spec.yScaleSpec.labelKind != yLabelKind or
          spec.yScaleSpec.reversed != yReversed:
        raise newException(PlotError,
          "shared y axes require matching transforms, labels and directions")
      if domains.yKind == ckNumeric:
        if spec.yScaleSpec.categories.configured:
          raise newException(PlotError,
            "categorical y domain cannot be applied to numeric coordinates")
        if spec.yScaleSpec.domain.configured:
          discard domains.yContinuous.train(0, 1,
            spec.yScaleSpec.domain.minimum, spec.yScaleSpec.domain.maximum)
        yDomain.merge(domains.yContinuous)
        if spec.yScaleSpec.domain.configured:
          yDomain.addValues([spec.yScaleSpec.domain.minimum,
            spec.yScaleSpec.domain.maximum])
      else:
        if spec.yScaleSpec.domain.configured:
          raise newException(PlotError,
            "numeric y limits cannot be applied to categorical coordinates")
        if spec.yScaleSpec.categories.configured:
          discard domains.yBand.train(0, 1,
            spec.yScaleSpec.categories.values)
          yBand.addValues(spec.yScaleSpec.categories.values)
        yBand.merge(domains.yBand)
  if shareX:
    if xCoordinateKind == ckNumeric:
      let bounds = xDomain.fittedBounds()
      for spec in result.mitems: spec.xLimits(bounds.minimum, bounds.maximum)
    else:
      let categories = xBand.train(0, 1).domain
      for spec in result.mitems: spec.xCategories(categories)
  if shareY:
    if yCoordinateKind == ckNumeric:
      let bounds = yDomain.fittedBounds()
      for spec in result.mitems: spec.yLimits(bounds.minimum, bounds.maximum)
    else:
      let categories = yBand.train(0, 1).domain
      for spec in result.mitems: spec.yCategories(categories)

proc compileCells(cells: openArray[GridCell]; columns: int; size: Size;
    gap: int; sharedX, sharedY: bool): Scene =
  if cells.len == 0:
    raise newException(PlotError, "plot grid requires at least one plot")
  if columns <= 0 or columns > cells.len:
    raise newException(PlotError,
      "plot grid columns must be within the plot count")
  if gap < 0:
    raise newException(PlotError, "plot grid gap must be non-negative")
  size.validate()
  let
    rows = (cells.len + columns - 1) div columns
    availableWidth = size.width - gap * (columns - 1)
    availableHeight = size.height - gap * (rows - 1)
  if availableWidth < columns or availableHeight < rows:
    raise newException(PlotError,
      "plot grid cells must have positive dimensions")
  let
    panelWidth = availableWidth div columns
    panelHeight = availableHeight div rows
    extraWidth = availableWidth mod columns
    extraHeight = availableHeight mod rows
  result = initScene(size, cells[0].spec.theme.background)
  var plotSpecs: seq[PlotSpec]
  for cell in cells:
    if not cell.empty: plotSpecs.add cell.spec
  if plotSpecs.len == 0:
    raise newException(PlotError, "plot grid requires a non-empty plot cell")
  let preparedSpecs = shareDomains(plotSpecs, sharedX, sharedY)
  var plotIndex = 0
  for panel, cell in cells:
    let
      column = panel mod columns
      row = panel div columns
      cellWidth = panelWidth + (if column < extraWidth: 1 else: 0)
      cellHeight = panelHeight + (if row < extraHeight: 1 else: 0)
      dx = column * (panelWidth + gap) + min(column, extraWidth)
      dy = row * (panelHeight + gap) + min(row, extraHeight)
      panelSize = Size(width: cellWidth, height: cellHeight)
    var compiled: Scene
    if cell.empty:
      compiled = initScene(panelSize, cell.spec.theme.background)
      compiled.addText(cell.title,
        Point(x: cell.spec.theme.margins.left, y: 25), 18,
        cell.spec.theme.foreground)
    else:
      compiled = preparedSpecs[plotIndex].compileScene(panelSize)
      inc plotIndex
    var background = newPath()
    background.rect(float32(dx), float32(dy), float32(cellWidth),
      float32(cellHeight))
    result.addPath(background, compiled.background)
    for node in compiled.nodes:
      let id = composedId(panel, node.id)
      case node.kind
      of snPath:
        result.addPath(node.path.translated(float32(dx), float32(dy)),
          node.color, id)
      of snText:
        result.addText(node.text,
          Point(x: node.position.x + float32(dx),
            y: node.position.y + float32(dy)),
          node.fontSize, node.color, id, node.anchor)
      of snImage:
        result.addImage(node.image, node.imageX + dx, node.imageY + dy,
          node.opacity, id)

proc compileGrid*(specs: openArray[PlotSpec]; columns: int;
                  size = Size(width: 1200, height: 800);
                  gap = 16; sharedX = false;
                  sharedY = false): Scene {.contractual.} =
  ## Compile plots into a row-major grid on one retained scene.
  ##
  ## Panels optionally share x or y domains. Each panel keeps its own guides,
  ## theme and background. Node IDs are deterministically namespaced by panel.
  require:
    specs.len > 0
    columns > 0 and columns <= specs.len
    gap >= 0
    size.width > 0 and size.height > 0
  ensure:
    result.size == size
  body:
    var cells = newSeqOfCap[GridCell](specs.len)
    for spec in specs: cells.add GridCell(spec: spec)
    result = compileCells(cells, columns, size, gap, sharedX, sharedY)

proc compileFacetGrid*(spec: PlotSpec; column: string; columns: int;
    size = Size(width: 1200, height: 800); gap = 16; sharedX = false;
    sharedY = false): Scene =
  ## Split one specification by category and compile the panels row-major.
  compileGrid(spec.facetSpecs(column), columns, size, gap, sharedX, sharedY)

proc compileFacetMatrix*(spec: PlotSpec; rowColumn, columnColumn: string;
    size = Size(width: 1200, height: 800); gap = 16; sharedX = false;
    sharedY = false): Scene =
  ## Compile a complete row-by-column categorical facet matrix.
  let facets = spec.facetCells(rowColumn, columnColumn)
  var cells = newSeqOfCap[GridCell](facets.len)
  for facet in facets:
    let facetTitle = rowColumn & " = " & facet.rowValue & " — " &
      columnColumn & " = " & facet.columnValue
    let panelTitle = if spec.title.len > 0:
      spec.title & " — " & facetTitle
    else:
      facetTitle
    if facet.rows.len == 0:
      cells.add GridCell(spec: spec, empty: true, title: panelTitle)
    else:
      var panel = spec
      panel.data = spec.data.selectRows(facet.rows)
      panel.title = panelTitle
      cells.add GridCell(spec: panel)
  var columnOrder: seq[string]
  for facet in facets:
    if facet.columnValue notin columnOrder: columnOrder.add facet.columnValue
  compileCells(cells, columnOrder.len, size, gap, sharedX, sharedY)
