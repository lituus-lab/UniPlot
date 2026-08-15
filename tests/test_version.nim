# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPlot

suite "version":
  test "UniPlotVersion is 1.0.0":
    check UniPlotVersion == "1.0.0"

