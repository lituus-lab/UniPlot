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
nimble benchmarkThermals     # cold process wall time + warmed stages
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

`benchmarkThermals` writes `benchmarks/results/thermal_suite.json`. Its cold
measurement is the wall time of a fresh provider subprocess performing one
actual SVG and PNG render; it includes language/runtime and library startup,
reference construction, serialization and shutdown. UniPlot is compiled
before its provider subprocess and compilation is therefore excluded. The
warm report is a separate process with three loop warmups and 20 measured
iterations. Cold wall time and warm stage time have different boundaries and
are never divided into a synthetic speedup ratio.

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
- `reference_construct_compile` compiles the common line-plus-point workload
  with two reference lines, two reference bands and two labels. It exercises
  scale-domain extension and UniVector annotation geometry without folding
  that UniPlot-only work into the cross-provider ranking. On the 2026-08-15
  100,000-point check it averaged 21.23 ms over five iterations versus
  21.34 ms for the unannotated construction in the same process; the apparent
  difference is noise, while the absence of material annotation overhead is
  the relevant observation.
- `uncertainty_construct_compile` compiles a line, one contiguous ribbon and
  one capped error bar per row. It includes real UniVector stroke expansion
  for every interval and is intentionally excluded from cross-provider
  rankings until all providers share the same uncertainty semantics. On the
  2026-08-15 Darwin arm64 reference run, 100,000 rows averaged 47.03 ms over
  five measured iterations, versus 21.29 ms for the common line-plus-point
  construction in the same process. The 2.21x ratio reflects 100,000 expanded
  capped intervals and is a regression baseline, not a cross-library result.
- `themed_construct_compile` applies the reusable dark preset before compiling
  the common workload. It guards against theme resolution regressions without
  treating a colour/style choice as a separate cross-provider workload. On
  the 2026-08-15 Darwin arm64 run it averaged 21.47 ms for 100,000 points over
  five measured iterations, versus 21.37 ms for the default theme in the same
  process. The 0.10 ms difference is within run-to-run noise.
- `json_encode` and `json_decode` measure the complete versioned PlotSpec,
  including both 100,000-value numeric columns. The decode input is prepared
  outside the timed loop; encoding and parsing are reported separately. On the
  2026-08-15 Darwin arm64 run, encoding averaged 8.04 ms and decoding averaged
  17.80 ms over five measured iterations for a 2,582,339-byte compact payload.
  These are in-memory, uncompressed schema costs; filesystem, compression and
  network I/O are not included.

They isolate implementation regressions that the common end-to-end workload
could hide. They are not comparisons with similarly named operations in other
libraries.

The transformed/reversed-axis change was checked on the same 2026-08-15
100,000-point reference workload: default linear construction averaged
21.42 ms and continuous-colour construction 31.39 ms over 10 iterations,
against 21.45 ms and 31.45 ms immediately before the change. The differences
are within run-to-run noise; this records absence of a detected regression, not
a performance improvement.

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
