# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, strutils]
import UniGlyph
import UniPlot

proc usage() =
  echo "Usage: uniplot render --font FONT --output FILE [--width N --height N]"
  echo "       uniplot inspect"

proc demoSpec(): PlotSpec =
  var frame = initDataFrame()
  frame.addColumn("x", [0.0, 1.0, 2.0, 3.0, 4.0])
  frame.addColumn("y", [1.0, 4.0, 2.0, 5.0, 3.0])
  result = plot(frame)
  result.geomLine(aes("x", "y"))
  result.geomPoint(aes("x", "y"), color = "#d33f49")
  result.labels(title = "UniPlot")

proc option(args: seq[string]; name: string; fallback = ""): string =
  for i in 0 ..< args.len - 1:
    if args[i] == name: return args[i + 1]
  fallback

when isMainModule:
  let args = commandLineParams()
  if args.len == 1 and args[0] == "inspect":
    let scene = demoSpec().compileScene()
    echo "version=", UniPlotVersion
    echo "nodes=", scene.nodes.len
  elif args.len > 0 and args[0] == "render":
    let fontPath = option(args, "--font")
    let output = option(args, "--output")
    if fontPath.len == 0 or output.len == 0:
      usage(); quit(2)
    let width = parseInt(option(args, "--width", "800"))
    let height = parseInt(option(args, "--height", "500"))
    let scene = demoSpec().compileScene(Size(width: width, height: height))
    let font = loadTtf(fontPath)
    if output.toLowerAscii.endsWith(".svg"): scene.saveSvg(font, output)
    elif output.toLowerAscii.endsWith(".png"): scene.savePng(font, output)
    else: raise newException(ValueError, "output must end in .svg or .png")
  else:
    usage(); quit(2)

