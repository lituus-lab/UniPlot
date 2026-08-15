# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
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
    check frame.finiteRows(["x"]) == @[0, 2]

  test "an empty first column still fixes the row count":
    var frame = initDataFrame()
    frame.addColumn("empty", newSeq[float64]())
    expect PlotError: frame.addColumn("nonempty", [1.0])
