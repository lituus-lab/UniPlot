# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/os
import nimibook

createDir("__site")

var book = initBook()
book.title = "UniPlot — scientific visualisation in pure Nim"
book.description = "Executable user manual for UniPlot 1.0"

book.toc = initToc:
  entry("Preface", "preface.md")
  entry("Installation and quick start", "quickstart.nim")
  entry("Typed data", "data.nim")
  entry("Recipes and layered grammar", "grammar.nim")
  entry("Scales and statistics", "scales_stats.nim")
  entry("Scenes and rendering", "scene_rendering.nim")
  entry("Plot grids", "composition.nim")
  entry("Versioned JSON", "serialization.nim")
  entry("WGPU and validation", "wgpu_errors.nim")
  entry("Command-line interface", "cli.nim")
  entry("C binding", "c_binding.nim")
  entry("Python binding", "python_binding.nim")
  entry("Rosetta stone and benchmarks", "rosetta_benchmarks.nim")
  entry("Architecture and roadmap", "architecture.md")

nimibookCli(book)
