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
nimble benchmarkScales       # 10^3, 10^5 and 10^6 points, all providers
nimble benchmark -- 50 5000  # direct runner arguments when supported
python3 benchmarks/run_benchmarks.py 50 5000
```

Results are written to `benchmarks/results/latest.json` with library versions,
machine metadata, methodology and mean/standard deviation/min/max.
`benchmarkScales` writes `benchmarks/results/workload_suite.json`. It uses
20/3, 5/1 and 1/0 measured/warm-up iterations respectively. SVG and PNG output
at one million points is intentionally real rather than replaced by a
no-output shortcut, so the largest workload is expensive in both time and
memory. Passing a third argument to `run_benchmarks.py` overrides the normal
three loop warm-ups. Zero disables those warm-ups; provider-specific
availability checks and runtime initialization remain disclosed implementation
work rather than being mislabeled as process-start timing.

`benchmarkDeps` creates `build/benchmark-python` for Matplotlib, Plotly and
Kaleido; `build/benchmark-r-library` for ggplot2 when R is installed; and uses
the dedicated `benchmarks/julia/Project.toml` for Plots.jl when Julia is
installed. It never installs R or Julia system-wide. Missing runtimes are
reported with instructions and can be enabled by rerunning the task later.

Three stages are reported:

- specification/artist construction and UniPlot scene compilation;
- SVG serialization from a retained/constructed plot;
- PNG serialization from the same plot.

UniPlot also reports three internal diagnostics excluded from cross-library
ranking:

- `continuous_scale_train` measures one-pass numeric-domain training;
- `row_filter_scan` measures allocation-light numeric-column validation and
  row filtering;
- `styled_construct_compile` uses a real UniVector dot-dash stroke and
  categorical marker shapes.
- `continuous_color_construct_compile` samples the configured UniColor ramp
  through one prepared sampler per scene, then compiles the resulting marker
  paths. On the 2026-08-15 Darwin arm64 reference run, 100,000 points averaged
  31.45 ms over 10 measured iterations, down from 74.18 ms for the immediately
  preceding prepared-stop-only run. UniColor now also converts palette stops
  into the interpolation space once. This is a measured 57.6% reduction for
  this internal stage, not a claim about complete render throughput or other
  machines; the sampler remains serial rather than SIMD or parallel.

They isolate implementation regressions that the common end-to-end workload
could hide. They are not comparisons with similarly named operations in other
libraries.

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
