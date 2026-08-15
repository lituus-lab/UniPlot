# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Deterministic composition of independently compiled plots.
import UniVector
import contracts
import UniPlot/[common, grammar, scene, guides]

func composedId(panel: int; nodeId: uint64): uint64 {.inline.} =
  if nodeId == 0: return 0
  var value = nodeId xor (uint64(panel + 1) * 0x9e3779b97f4a7c15'u64)
  value = (value xor (value shr 30)) * 0xbf58476d1ce4e5b9'u64
  value = (value xor (value shr 27)) * 0x94d049bb133111eb'u64
  result = value xor (value shr 31)
  if result == 0: result = 1

proc compileGrid*(specs: openArray[PlotSpec]; columns: int;
                  size = Size(width: 1200, height: 800);
                  gap = 16): Scene {.contractual.} =
  ## Compile plots into a row-major grid on one retained scene.
  ##
  ## Each panel keeps its own scales, guides, theme and background. Node IDs
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
    for panel, spec in specs:
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
            node.fontSize, node.color, id)
