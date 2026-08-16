# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, json, os, osproc, strutils, times]

const
  DefaultRuns = 3
  DefaultIterations = 20

proc median(values: seq[float64]): float64 =
  var ordered = values
  ordered.sort()
  ordered[ordered.len div 2]

proc commandValue(command: string; args: openArray[string]): string =
  try:
    execProcess(command, args = args, options = {poUsePath}).strip
  except OSError:
    "unknown"

proc phaseSummary(reports: seq[JsonNode]; phase: string): JsonNode =
  var means = newSeq[float64](reports.len)
  for index, report in reports:
    means[index] = report[phase]["mean_ms"].getFloat
  %*{
    "run_mean_ms": means,
    "median_run_mean_ms": median(means)
  }

proc validateInvariant(reference, report: JsonNode; field: string) =
  if report[field] != reference[field]:
    quit("benchmark invariant changed between runs: " & field, 1)

proc main() =
  let params = commandLineParams()
  if params.len > 4:
    quit("usage: run_wgpu_raster_baseline [binary] [output] [runs] [iterations]", 2)
  let
    binary = if params.len >= 1: params[0] else:
      "build/benchmark_wgpu_raster"
    output = if params.len >= 2: params[1] else:
      "build/wgpu-raster-baseline.json"
    runs = if params.len >= 3: parseInt(params[2]) else: DefaultRuns
    iterations = if params.len >= 4: parseInt(params[3]) else:
      DefaultIterations
  if runs < 1 or (runs and 1) == 0 or iterations < 1:
    quit("runs must be positive and odd; iterations must be positive", 2)
  if not fileExists(binary):
    quit("benchmark binary not found: " & binary, 2)

  var reports = newSeq[JsonNode](runs)
  for run in 0 ..< runs:
    reports[run] = parseJson(execProcess(binary, args = @[$iterations],
      options = {poStdErrToStdOut}))
    if reports[run]["provider"].getStr != "UniPlot-WGPU-raster" or
        reports[run]["iterations"].getInt != iterations or
        reports[run]["texture_uploads"].getInt != 1:
      quit("benchmark report does not match the requested protocol", 1)
    if run > 0:
      for field in ["wgpu_native", "adapter", "backend", "warmup_iterations",
          "canvas", "image", "semantics", "texture_upload_bytes",
          "prepared_cache_bytes", "managed_gpu_bytes",
          "managed_gpu_peak_bytes", "managed_gpu_byte_budget"]:
        validateInvariant(reports[0], reports[run], field)

  let
    detectedMachine = when defined(macosx): commandValue("sysctl", ["-n",
      "machdep.cpu.brand_string"])
      else: "unspecified"
    configuredMachine = getEnv("UNIPLOT_BENCH_MACHINE")
    machine = if configuredMachine.len > 0: configuredMachine
      elif detectedMachine.len > 0: detectedMachine
      else: "unspecified"
    first = reports[0]
  let report = %*{
    "date": now().format("yyyy-MM-dd"),
    "machine": machine,
    "architecture": hostCPU,
    "os": hostOS,
    "os_version": when defined(macosx): commandValue("sw_vers",
      ["-productVersion"])
      else: "unspecified",
    "nim": NimVersion,
    "wgpu_native": first["wgpu_native"],
    "backend": first["backend"],
    "build": "-d:release --mm:orc",
    "runs": runs,
    "iterations_per_run": iterations,
    "warmup_iterations": first["warmup_iterations"],
    "canvas": first["canvas"],
    "image": first["image"],
    "semantics": first["semantics"],
    "submit": phaseSummary(reports, "submit"),
    "publication_frame": phaseSummary(reports, "publication_frame"),
    "texture_uploads_per_prepared_identity": first["texture_uploads"],
    "texture_upload_bytes": first["texture_upload_bytes"],
    "prepared_cache_bytes": first["prepared_cache_bytes"],
    "managed_gpu_bytes": first["managed_gpu_bytes"],
    "managed_gpu_peak_bytes": first["managed_gpu_peak_bytes"],
    "managed_gpu_byte_budget": first["managed_gpu_byte_budget"]
  }
  let encoded = pretty(report)
  echo encoded
  writeFile(output, encoded & "\n")

main()
