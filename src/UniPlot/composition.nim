# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Deterministic composition of independently compiled plots.
import std/tables
import UniVector
import contracts
import UniPlot/[common, data, scales, grammar, scene, guides]

func composedId(panel: int; nodeId: uint64): uint64 {.inline.} =
  if nodeId == 0: return 0
  var value = nodeId xor (uint64(panel + 1) * 0x9e3779b97f4a7c15'u64)
  value = (value xor (value shr 30)) * 0xbf58476d1ce4e5b9'u64
  value = (value xor (value shr 27)) * 0x94d049bb133111eb'u64
  result = value xor (value shr 31)
  if result == 0: result = 1

proc facetSpecs*(spec: PlotSpec; column: string): seq[PlotSpec] {.
    contractual.} =
  ## Split a specification by a categorical column in first-seen order.
  require:
    column.len > 0
  ensure:
    result.len > 0
  body:
    if column.len == 0:
      raise newException(PlotError, "facet column name cannot be empty")
    if column notin spec.data.columns or
        spec.data.columns[column].kind != ckCategorical:
      raise newException(PlotError,
        "faceting requires an existing categorical column")
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

proc shareNumericDomains(specs: openArray[PlotSpec]; shareX,
    shareY: bool): seq[PlotSpec] =
  result = @specs
  if not shareX and not shareY: return
  var
    xDomain = initContinuousDomain()
    yDomain = initContinuousDomain()
    initialized = false
    xKind = skLinear
    yKind = skLinear
    xReversed = false
    yReversed = false
  for spec in specs:
    let domains = collectAxisDomains(spec)
    if not initialized:
      xKind = spec.xScaleSpec.kind
      yKind = spec.yScaleSpec.kind
      xReversed = spec.xScaleSpec.reversed
      yReversed = spec.yScaleSpec.reversed
      xDomain = initContinuousDomain(xKind)
      yDomain = initContinuousDomain(yKind)
      initialized = true
    if shareX:
      if domains.xKind != ckNumeric:
        raise newException(PlotError,
          "shared x axes currently require numeric coordinates")
      if spec.xScaleSpec.kind != xKind or
          spec.xScaleSpec.reversed != xReversed:
        raise newException(PlotError,
          "shared x axes require matching scale kinds and directions")
      if spec.xScaleSpec.domain.configured:
        discard domains.xContinuous.train(0, 1,
          spec.xScaleSpec.domain.minimum, spec.xScaleSpec.domain.maximum)
      xDomain.merge(domains.xContinuous)
      if spec.xScaleSpec.domain.configured:
        xDomain.addValues([spec.xScaleSpec.domain.minimum,
          spec.xScaleSpec.domain.maximum])
    if shareY:
      if spec.yScaleSpec.kind != yKind or
          spec.yScaleSpec.reversed != yReversed:
        raise newException(PlotError,
          "shared y axes require matching scale kinds and directions")
      if spec.yScaleSpec.domain.configured:
        discard domains.yContinuous.train(0, 1,
          spec.yScaleSpec.domain.minimum, spec.yScaleSpec.domain.maximum)
      yDomain.merge(domains.yContinuous)
      if spec.yScaleSpec.domain.configured:
        yDomain.addValues([spec.yScaleSpec.domain.minimum,
          spec.yScaleSpec.domain.maximum])
  if shareX:
    let bounds = xDomain.fittedBounds()
    for spec in result.mitems: spec.xLimits(bounds.minimum, bounds.maximum)
  if shareY:
    let bounds = yDomain.fittedBounds()
    for spec in result.mitems: spec.yLimits(bounds.minimum, bounds.maximum)

proc compileGrid*(specs: openArray[PlotSpec]; columns: int;
                  size = Size(width: 1200, height: 800);
                  gap = 16; sharedX = false;
                  sharedY = false): Scene {.contractual.} =
  ## Compile plots into a row-major grid on one retained scene.
  ##
  ## Panels optionally share numeric x or y domains. Each panel keeps its own
  ## guides, theme and background. Node IDs
  ## are deterministically namespaced by panel so picking can distinguish
  ## otherwise identical specifications.
  require:
    specs.len > 0
    columns > 0 and columns <= specs.len
    gap >= 0
    size.width > 0 and size.height > 0
  ensure:
    result.size == size
  body:
    if specs.len == 0:
      raise newException(PlotError, "plot grid requires at least one plot")
    if columns <= 0 or columns > specs.len:
      raise newException(PlotError,
        "plot grid columns must be within the plot count")
    if gap < 0:
      raise newException(PlotError, "plot grid gap must be non-negative")
    size.validate()
    let
      rows = (specs.len + columns - 1) div columns
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
    result = initScene(size, specs[0].theme.background)
    let preparedSpecs = shareNumericDomains(specs, sharedX, sharedY)
    for panel, spec in preparedSpecs:
      let
        column = panel mod columns
        row = panel div columns
        cellWidth = panelWidth + (if column < extraWidth: 1 else: 0)
        cellHeight = panelHeight + (if row < extraHeight: 1 else: 0)
        dx = column * (panelWidth + gap) + min(column, extraWidth)
        dy = row * (panelHeight + gap) + min(row, extraHeight)
        panelSize = Size(width: cellWidth, height: cellHeight)
        compiled = spec.compileScene(panelSize)
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

proc compileFacetGrid*(spec: PlotSpec; column: string; columns: int;
    size = Size(width: 1200, height: 800); gap = 16; sharedX = false;
    sharedY = false): Scene =
  ## Split one specification by category and compile the panels row-major.
  compileGrid(spec.facetSpecs(column), columns, size, gap, sharedX, sharedY)
