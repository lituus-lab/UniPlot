# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import UniPlot

var frame = initDataFrame()
frame.addColumn("x", [0.0, 1.0, 2.0, 3.0])
frame.addColumn("y", [1.0, 3.0, 2.0, 4.0])
var figure = plot(frame)
figure.geomLine(aes("x", "y"))
figure.geomPoint(aes("x", "y"), color = "#cc3344")
figure.labels(title = "UniPlot 1.0")
let scene = figure.compileScene()
echo "UniPlot ", UniPlotVersion, ": ", scene.nodes.len, " scene nodes"
