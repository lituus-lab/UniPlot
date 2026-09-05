# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, os, osproc, strformat, strutils, times]

const Phases = [
  "construct_compile",
  "cpu_prepare_scene",
  "svg_from_prepared_scene",
  "png_from_prepared_scene",
]

proc quoted(path: string): string = quoteShell(path)

when isMainModule:
  if paramCount() < 1 or paramCount() > 3:
    quit("usage: run_memory_benchmarks BENCHMARK [POINTS] [FONT]", QuitFailure)
  let
    executable = absolutePath(paramStr(1))
    points = if paramCount() >= 2: parseInt(paramStr(2)) else: 100_000
    font = absolutePath(if paramCount() >= 3: paramStr(3) else:
      "tests/DejaVuSans.ttf")
  if not fileExists(executable):
    quit("memory benchmark executable not found: " & executable, QuitFailure)
  if not fileExists(font):
    quit("font not found: " & font, QuitFailure)
  if points <= 0:
    quit("POINTS must be positive", QuitFailure)

  var measurements = newJArray()
  for phase in Phases:
    let command = quoted(executable) & " " & quoted(phase) & " " & $points &
      " " & quoted(font)
    let child = execCmdEx(command, options = {poUsePath, poStdErrToStdOut})
    if child.exitCode != 0:
      quit(&"memory phase {phase} failed:\n{child.output}", QuitFailure)
    try:
      measurements.add parseJson(child.output.strip)
    except JsonParsingError:
      quit(&"memory phase {phase} returned invalid JSON:\n{child.output}",
        QuitFailure)

  let report = %*{
    "schema": 1,
    "generated_at": now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    "platform": hostOS,
    "architecture": hostCPU,
    "points": points,
    "measurements": measurements,
    "semantics": {
      "isolation": "Each phase runs once in a fresh process.",
      "rss": "ru_maxrss high-water mark; Linux KiB is normalized to bytes.",
      "heap": "Nim allocator high-water and live occupied-byte counters.",
      "growth": "Non-negative high-water growth beyond phase-specific setup.",
      "warning": "These counters do not measure cumulative allocated bytes."
    }
  }
  createDir("benchmarks/results")
  let destination = "benchmarks/results/memory.json"
  writeFile(destination, pretty(report) & "\n")
  echo destination
