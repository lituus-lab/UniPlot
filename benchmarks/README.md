<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPlot cross-library benchmarks

The reproducible baseline compares UniPlot with Matplotlib's non-interactive
Agg backend, Plotly/Kaleido, ggplot2 and Plots.jl when available, on the same
1,000-point line-plus-scatter plot, 800×500 canvas, three warmups and a
configurable number of measured iterations.

```bash
nimble benchmarkDeps         # explicit, isolated optional dependency setup
nimble benchmark             # 20 iterations, 1,000 points
nimble benchmark -- 50 5000  # direct runner arguments when supported
python3 benchmarks/run_benchmarks.py 50 5000
```

Results are written to `benchmarks/results/latest.json` with library versions,
machine metadata, methodology and mean/standard deviation/min/max.

`benchmarkDeps` creates `build/benchmark-python` for Matplotlib, Plotly and
Kaleido; `build/benchmark-r-library` for ggplot2 when R is installed; and uses
the dedicated `benchmarks/julia/Project.toml` for Plots.jl when Julia is
installed. It never installs R or Julia system-wide. Missing runtimes are
reported with instructions and can be enabled by rerunning the task later.

Three stages are reported:

- specification/artist construction and UniPlot scene compilation;
- SVG serialization from a retained/constructed plot;
- PNG serialization from the same plot.

UniPlot also reports `styled_construct_compile`, an internal diagnostic using
a real UniVector dot-dash stroke and categorical marker shapes. This extra
stage is excluded from cross-library ranking; it guards geometry features that
the common line-plus-scatter workload does not otherwise exercise.

These stages align user intent, not internal work. Matplotlib may defer work to
`savefig`, while UniPlot performs layout in `compileScene`; timings must not be
interpreted as identical instruction sets. Results are evidence for regression
tracking, not universal rankings.

VisPy is an interactive GPU library and requires a controlled GPU/windowing
setup, so it does not belong in this CPU off-screen baseline. Missing runtimes,
packages or static export engines are reported as unavailable and are never
installed implicitly.

The real WGPU path has a separate pure-Nim benchmark:

```bash
nimble wgpuDeps
nimble wgpuBenchmark
# Same-machine Apple M4 regression gate after the task builds the executable:
UNIPLOT_WGPU_LIBRARY="$PWD/.deps/wgpu/29.0.1.1/macos-aarch64/lib/libwgpu_native.dylib" \
  ./build/benchmark_wgpu 50 1000 build/wgpu-current.json \
  benchmarks/baselines/apple-m4-metal.json
```

It reports preparation, enqueue-only frames and publication frames separately.
Preparation shapes UniGlyph text and tessellates UniVector paths. Warm frames
reuse that geometry; publication additionally reads the 800×500 RGBA8 texture
back. Enqueue timing is CPU-side submission latency, not guaranteed GPU
completion or a universal frame-rate claim.

The optional fourth argument compares the current means with a baseline only
after adapter, backend, workload and canvas identity match. Each phase carries
its own ratio derived from repeated runs, because asynchronous submission is
materially noisier than preparation or readback. Add a separate baseline for a
different machine; never reuse these thresholds across hardware.
