# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
using Plots
using Printf
using Statistics

iterations = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 20
point_count = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1000
x = collect(0:(point_count - 1)) ./ 25
y = sin.(x) .+ 0.02 .* x

function make_plot()
  result = plot(x, y; color="#3366cc", linewidth=2, label=false,
                title="Rosetta benchmark", xlabel="x", ylabel="y",
                size=(800, 500))
  scatter!(result, x, y; color="#cc3344", markersize=1, label=false)
  result
end

function describe(values)
  @sprintf("{\"mean_ms\":%.9f,\"stdev_ms\":%.9f,\"min_ms\":%.9f,\"max_ms\":%.9f}",
           mean(values), std(values), minimum(values), maximum(values))
end

reference = make_plot()
construct = Float64[]
svg_times = Float64[]
png_times = Float64[]
guard = 0
for iteration in 1:(iterations + 3)
  construct_ms = @elapsed(make_plot()) * 1000
  svg_path = tempname() * ".svg"
  svg_ms = @elapsed(savefig(reference, svg_path)) * 1000
  png_path = tempname() * ".png"
  png_ms = @elapsed(savefig(reference, png_path)) * 1000
  guard = xor(xor(guard, filesize(svg_path)), filesize(png_path))
  rm(svg_path)
  rm(png_path)
  if iteration > 3
    push!(construct, construct_ms)
    push!(svg_times, svg_ms)
    push!(png_times, png_ms)
  end
end

@printf(paste0(
  "{\"provider\":\"Plots.jl\",\"version\":\"%s\",\"iterations\":%d,",
  "\"points\":%d,\"width\":800,\"height\":500,\"warmup_iterations\":3,",
  "\"stages\":{\"construct_compile\":%s,\"svg_from_compiled_scene\":%s,",
  "\"png_from_compiled_scene\":%s},\"guard\":%d}\n"),
  string(pkgversion(Plots)), iterations, point_count, describe(construct),
  describe(svg_times), describe(png_times), guard)
