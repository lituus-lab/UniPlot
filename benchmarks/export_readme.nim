# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Splice a real baseline run into `benchmarks/README.md`.
##
## Numbers typed into prose by hand cannot be told from numbers that were
## measured; this reads the JSON a run wrote and writes the table itself. Each
## machine owns a block delimited by its own slug, so re-running here replaces
## these results and leaves another machine's alone.

import std/[json, os, strformat, strutils]

const
  Anchor = "<!-- bench:insert -->"
  Readme = "benchmarks" / "README.md"

proc slugOf(baseline: JsonNode): string =
  ## `<os>-<machine>`, lowercased with every run of non-alphanumerics folded to
  ## a single dash: the same machine must always produce the same delimiter.
  let raw = baseline["os"].getStr & "-" & baseline["machine"].getStr
  var previousWasDash = false
  for character in raw:
    if character.isAlphaNumeric:
      result.add character.toLowerAscii
      previousWasDash = false
    elif not previousWasDash:
      result.add '-'
      previousWasDash = true
  result = result.strip(chars = {'-'})

proc row(baseline: JsonNode; key, label: string): string =
  let stage = baseline[key]
  let runs = stage["run_mean_ms"].getElems
  var lowest = runs[0].getFloat
  var highest = runs[0].getFloat
  for value in runs:
    lowest = min(lowest, value.getFloat)
    highest = max(highest, value.getFloat)
  &"| {label} | {stage[\"median_run_mean_ms\"].getFloat:.4f} | " &
    &"{lowest:.4f} | {highest:.4f} |\n"

proc machineBlock(baseline: JsonNode; slug: string): string =
  result = &"<!-- bench:machine={slug} -->\n"
  result.add &"**{baseline[\"machine\"].getStr}** ({baseline[\"architecture\"].getStr}, " &
    &"{baseline[\"os\"].getStr}), Nim {baseline[\"nim\"].getStr}, " &
    &"`{baseline[\"build\"].getStr}`, measured {baseline[\"date\"].getStr}: " &
    &"{baseline[\"runs\"].getInt} runs of {baseline[\"iterations_per_run\"].getInt} " &
    "iterations, the table reporting each stage's median run mean.\n\n"
  result.add "| Stage | Median (ms) | Lowest run (ms) | Highest run (ms) |\n"
  result.add "|---|---|---|---|\n"
  # Every stage the run recorded, in the order it recorded them: a table that
  # lists a chosen subset is the hand-picking this file exists to remove.
  for key, value in baseline.pairs:
    if value.kind == JObject and value.hasKey("median_run_mean_ms"):
      result.add baseline.row(key, key.replace("_", " ").capitalizeAscii)
  result.add &"\n<!-- /bench:machine={slug} -->\n"

proc main() =
  let params = commandLineParams()
  let source = if params.len >= 1: params[0]
               else: "build" / "raster-spec-baseline.json"
  if not fileExists(source):
    quit(&"no baseline at {source}: run `nimble rasterSpecBaseline` first", 2)
  let baseline = parseJson(readFile(source))
  let slug = baseline.slugOf
  let fresh = baseline.machineBlock(slug)

  var text = readFile(Readme)
  let opening = &"<!-- bench:machine={slug} -->"
  let closing = &"<!-- /bench:machine={slug} -->"
  let start = text.find(opening)
  if start >= 0:
    let stop = text.find(closing, start)
    if stop < 0: quit(&"{Readme}: {opening} has no closing marker", 1)
    text = text[0 ..< start] & fresh & text[stop + closing.len + 1 .. ^1]
  else:
    let anchor = text.find(Anchor)
    if anchor < 0: quit(&"{Readme}: no {Anchor} anchor to write under", 1)
    let after = anchor + Anchor.len
    text = text[0 .. after] & "\n" & fresh & text[after + 1 .. ^1]
  writeFile(Readme, text)
  echo &"benchmarks/README.md: wrote the {slug} block from {source}"

main()
