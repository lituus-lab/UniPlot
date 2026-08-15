# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import contracts
import UniPlot

suite "data":
  test "columns retain order and reject mismatched lengths":
    var frame = initDataFrame()
    frame.addColumn("x", [1.0, 2.0, 3.0])
    frame.addColumn("label", ["a", "b", "c"])
    check frame.order == @["x", "label"]
    check frame.numeric("x") == @[1.0, 2.0, 3.0]
    expect PlotError: frame.addColumn("bad", [1.0, 2.0])

  test "finiteRows filters non-finite numeric values":
    var frame = initDataFrame()
    frame.addColumn("x", [1.0, NaN, 3.0])
    frame.addColumn("y", [Inf, 2.0, 3.0])
    frame.addColumn("label", ["a", "b", "c"])
    check frame.finiteRows(["x", "y", "label"]) == @[2]
    let filter = frame.initRowFilter(["x", "y", "label"])
    check not filter.rowIsFinite(0)
    check not filter.rowIsFinite(1)
    check filter.rowIsFinite(2)

    when defined(release):
      expect PlotError: discard filter.rowIsFinite(3)
    else:
      expect PreConditionDefect: discard filter.rowIsFinite(3)

  test "an empty first column still fixes the row count":
    var frame = initDataFrame()
    frame.addColumn("empty", newSeq[float64]())
    expect PlotError: frame.addColumn("nonempty", [1.0])

  test "column access rejects empty names, missing columns and wrong kinds":
    var frame = initDataFrame()
    expect PlotError: frame.addColumn("", [1.0])
    frame.addColumn("number", [1.0])
    frame.addColumn("label", ["a"])
    expect PlotError: discard frame.numeric("missing")
    expect PlotError: discard frame.numeric("label")
    expect PlotError: discard frame.categorical("number")
    expect PlotError: discard frame.finiteRows(["missing"])
