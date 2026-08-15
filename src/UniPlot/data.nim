# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[tables, math]
import UniPlot/common

type
  ColumnKind* = enum
    ckNumeric
    ckCategorical

  Column* = object
    case kind*: ColumnKind
    of ckNumeric:
      numbers*: seq[float64]
    of ckCategorical:
      categories*: seq[string]

  DataFrame* = object
    order*: seq[string]
    columns*: Table[string, Column]
    rowCount*: int

proc initDataFrame*(): DataFrame =
  result.columns = initTable[string, Column]()

proc addColumn*(frame: var DataFrame; name: string; values: openArray[float64]) =
  if name.len == 0:
    raise newException(PlotError, "column name cannot be empty")
  if frame.order.len != 0 and values.len != frame.rowCount:
    raise newException(PlotError, "all columns must have the same length")
  if name notin frame.columns: frame.order.add name
  frame.columns[name] = Column(kind: ckNumeric, numbers: @values)
  frame.rowCount = values.len

proc addColumn*(frame: var DataFrame; name: string; values: openArray[string]) =
  if name.len == 0:
    raise newException(PlotError, "column name cannot be empty")
  if frame.order.len != 0 and values.len != frame.rowCount:
    raise newException(PlotError, "all columns must have the same length")
  if name notin frame.columns: frame.order.add name
  frame.columns[name] = Column(kind: ckCategorical, categories: @values)
  frame.rowCount = values.len

proc numeric*(frame: DataFrame; name: string): seq[float64] =
  if name notin frame.columns or frame.columns[name].kind != ckNumeric:
    raise newException(PlotError, "numeric column not found: " & name)
  frame.columns[name].numbers

proc categorical*(frame: DataFrame; name: string): seq[string] =
  if name notin frame.columns or frame.columns[name].kind != ckCategorical:
    raise newException(PlotError, "categorical column not found: " & name)
  frame.columns[name].categories

proc finiteRows*(frame: DataFrame; columns: openArray[string]): seq[int] =
  for row in 0 ..< frame.rowCount:
    var valid = true
    for name in columns:
      if name notin frame.columns:
        raise newException(PlotError, "column not found: " & name)
      let column = frame.columns[name]
      if column.kind == ckNumeric and classify(column.numbers[row]) in
          {fcNan, fcInf, fcNegInf}:
        valid = false
    if valid: result.add row
