# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, json, os, osproc, strutils, times]

proc commandValue(command: string; args: openArray[string]): string =
  try:
    execProcess(command, args = args, options = {poUsePath}).strip
  except OSError:
    "unknown"

proc median(values: seq[float64]): float64 =
  var ordered = values
  ordered.sort()
  ordered[ordered.len div 2]

proc main() =
  let params = commandLineParams()
  let
    binary = if params.len >= 1: params[0] else: "build/benchmark_raster_spec"
    output = if params.len >= 2: params[1] else:
      "build/raster-spec-baseline.json"
    runs = if params.len >= 3: parseInt(params[2]) else: 3
    iterations = if params.len >= 4: parseInt(params[3]) else: 10
  if params.len > 4 or runs < 1 or (runs and 1) == 0 or iterations < 1:
    quit("usage: runner [binary] [output] [positive odd runs] [iterations]", 2)
  if not fileExists(binary): quit("benchmark binary not found: " & binary, 2)
  var reports = newSeq[JsonNode](runs)
  for run in 0 ..< runs:
    reports[run] = parseJson(execProcess(binary, args = @[$iterations],
      options = {poStdErrToStdOut}))
    if reports[run]["provider"].getStr != "UniPlot-raster-spec" or
        reports[run]["iterations"].getInt != iterations:
      quit("benchmark report does not match the requested protocol", 1)
    if run > 0:
      for field in ["warmup_iterations", "source", "canvas", "filter",
          "semantics", "image_mark_count", "image_resource_count",
          "temporal_point_count", "histogram_point_count", "histogram_rule",
          "smoothing_point_count", "smoothing_grid_count"]:
        if reports[run][field] != reports[0][field]:
          quit("benchmark invariant changed between runs: " & field, 1)
  proc phase(field: string): JsonNode =
    var values = newSeq[float64](runs)
    for run in 0 ..< runs: values[run] = reports[run][field].getFloat
    %*{"run_mean_ms": values, "median_run_mean_ms": median(values)}
  let first = reports[0]
  let
    detectedMachine = when defined(macosx):
      commandValue("sysctl", ["-n", "machdep.cpu.brand_string"])
      else: "unspecified"
    configuredMachine = getEnv("UNIPLOT_BENCH_MACHINE")
    machine = if configuredMachine.len > 0: configuredMachine
      elif detectedMachine.len > 0: detectedMachine else: "unspecified"
  let result = %*{"date": now().format("yyyy-MM-dd"), "machine": machine,
    "architecture": hostCPU, "os": hostOS, "nim": NimVersion,
    "build": "-d:release --mm:orc", "runs": runs,
    "iterations_per_run": iterations,
    "warmup_iterations": first["warmup_iterations"],
    "source": first["source"], "canvas": first["canvas"],
    "filter": first["filter"], "semantics": first["semantics"],
    "image_mark_count": first["image_mark_count"],
    "image_resource_count": first["image_resource_count"],
    "temporal_point_count": first["temporal_point_count"],
    "histogram_point_count": first["histogram_point_count"],
    "histogram_rule": first["histogram_rule"],
    "smoothing_point_count": first["smoothing_point_count"],
    "smoothing_grid_count": first["smoothing_grid_count"],
    "construction_snapshot": phase("construction_snapshot_mean_ms"),
    "compile": phase("compile_mean_ms"),
    "publication": phase("publication_mean_ms"),
    "image_mark_construction": phase("image_mark_construction_mean_ms"),
    "image_mark_compile": phase("image_mark_compile_mean_ms"),
    "image_mark_publication": phase("image_mark_publication_mean_ms")}
  result["temporal_construction"] = phase("temporal_construction_mean_ms")
  result["temporal_compile"] = phase("temporal_compile_mean_ms")
  result["temporal_publication"] = phase("temporal_publication_mean_ms")
  result["histogram_selection"] = phase("histogram_selection_mean_ms")
  result["histogram_construction"] = phase("histogram_construction_mean_ms")
  result["histogram_compile"] = phase("histogram_compile_mean_ms")
  result["histogram_publication"] = phase("histogram_publication_mean_ms")
  result["smoothing_fit"] = phase("smoothing_fit_mean_ms")
  result["smoothing_construction"] = phase("smoothing_construction_mean_ms")
  result["smoothing_compile"] = phase("smoothing_compile_mean_ms")
  result["smoothing_publication"] = phase("smoothing_publication_mean_ms")
  let encoded = pretty(result) & "\n"
  echo encoded
  writeFile(output, encoded)

main()
