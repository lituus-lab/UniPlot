<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPlot cross-library benchmarks

The reproducible baseline compares UniPlot with Matplotlib's non-interactive
Agg backend, Plotly/Kaleido, ggplot2 and Plots.jl when available, on the same
1,000-point line-plus-scatter plot, 800×500 canvas, three warmups and a
configurable number of measured iterations.

## Retained raster and image-mark stages

Run `nimble rasterSpecBaseline` for the reproducible 3×10 Apple M4 protocol.
It separates PlotSpec construction plus the caller-buffer snapshot, scene
compilation (including the alpha-correct 512×512 to plot-area resize), and
complete 800×600 CPU publication. The same processes also measure 64
data-mapped image marks backed by four snapshotted 16×16 RGBA8 resources.
Allocation is included in every phase; setup and warmups are not.

The current Apple M4 medians are 0.3133 / 8.5059 / 8.0370 ms for the retained
raster construction / compile / publication phases, and 0.0168 / 3.0793 /
7.3001 ms for the 64-mark construction / compile / publication phases. These
are same-machine regression evidence, not cross-machine performance claims.
The exact samples are stored in
`benchmarks/baselines/apple-m4-raster-spec.json`.

```bash
nimble benchmarkDeps         # explicit, isolated optional dependency setup
nimble benchmark             # 20 iterations, 1,000 points
nimble benchmarkScales       # 10^3, 10^5 and 10^6 points, all providers
nimble benchmarkThermals     # cold process wall time + warmed stages
nimble benchmarkMemory       # isolated UniPlot RSS and heap high-water marks
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

`benchmarkMemory` writes `benchmarks/results/memory.json`. Each measured phase
runs once in a fresh release-mode ORC process so prior phases cannot inflate
its high-water marks. It reports the absolute process peak RSS, peak Nim heap
and live heap, plus growth beyond phase-specific setup. Linux `ru_maxrss` is
normalized from KiB to bytes; Darwin already reports bytes. Other platforms
report `-1` rather than assuming an undocumented unit or fabricating a value.

On the 2026-08-16 Darwin arm64 reference run at 100,000 points, constructing
and compiling the line-plus-point scene reached 140.30 MB process RSS and grew
the RSS high-water mark by 136.68 MB. Preparing the already compiled scene
reached 202.70 MB and added 62.41 MB beyond its setup. Serializing that
prepared scene to a real 51,057,593-byte SVG reached 325.52 MB and added
122.81 MB. PNG serialization reached 202.70 MB and did not exceed the
prepared-scene setup high-water mark; its live Nim heap grew by 1.61 MB while
holding the 26,844-byte encoded output. Decimal MB are used here.

These are single-run diagnostic observations, not statistical estimates or
cross-library rankings. Nim's public allocator counters expose live and peak
bytes, but not cumulative requested bytes. The harness therefore does not
rename allocation counts or heap growth as “bytes allocated per frame”; that
separate measurement remains open.

The optional hardware raster benchmark is separate from the cross-library
workload:

```bash
nimble wgpuDeps
nimble wgpuRasterBenchmark -- 20 build/wgpu-raster.json # one diagnostic run
nimble wgpuRasterBaseline                               # three-run evidence
```

It renders one retained 512×512 RGBA8 image into an 800×600 Metal target. The
submit phase excludes readback; the publication phase renders into a
premultiplied RGBA16F target before publishing straight RGBA8 pixels. On the
2026-08-16 Apple M4 reference run, the medians of three 20-iteration run means
were 0.1269 ms for a resident enqueue and 6.5775 ms for publication. The
first prepared submission uploaded 1,048,576
texture bytes exactly once and retained 1,048,832 budgeted GPU bytes including
the quad buffer. The RGBA16F target preserves low-alpha straight-color
semantics that an RGBA8 premultiplied target cannot recover. Publication is
therefore measured independently from enqueue because conversion and
GPU-to-CPU readback dominate it. The recorded three-run evidence is
`benchmarks/baselines/apple-m4-metal-raster.json`; it is hardware-specific and
not a claim about other adapters. The baseline task reproduces the complete
three-run aggregation into `build/wgpu-raster-baseline.json`.

`benchmarkDeps` creates `build/benchmark-python` for Matplotlib, Plotly and
Kaleido; `build/benchmark-r-library` for ggplot2 when R is installed; and uses
the dedicated `benchmarks/julia/Project.toml` for Plots.jl when Julia is
installed. It never installs R or Julia system-wide. Missing runtimes are
reported with instructions and can be enabled by rerunning the task later.

Three stages are reported:

- specification/artist construction and UniPlot scene compilation;
- SVG serialization from a retained/constructed plot;
- PNG serialization from the same plot.

UniPlot also reports internal diagnostics excluded from cross-library ranking:

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
- `secondary_axis_construct_compile` adds a five-tick affine right-side y guide
  to the common workload and alternates measurement order against the default
  plot. On the 2026-08-15 Darwin arm64 run, seven iterations after three
  warmups averaged 21.65 ms with the guide and 21.47 ms without it. The
  0.18 ms (0.85%) difference is smaller than the overlapping run variability;
  it is retained as regression evidence, not claimed as a measurable universal
  cost.
- `grid_construct_compile` compiles four independent panels containing a
  combined point count equal to the common workload, then composes their paths,
  text and namespaced IDs. On the 2026-08-15 Darwin arm64 run at 100,000 total
  points, it averaged 31.95 ms over three iterations after one warmup, versus
  21.55 ms for one panel in the same process. The additional 10.40 ms includes
  three extra sets of scales and guides plus scene translation; it is not a
  cross-library faceting comparison.
- `shared_grid_construct_compile` uses the same four-panel workload while
  deriving common numeric x and y domains before compilation. On the
  2026-08-15 Darwin arm64 run at 100,000 total points, it averaged 34.00 ms
  over five iterations after three warmups, versus 32.26 ms for independent
  domains in the same process. The measured 1.74 ms (5.39%) is the cost of the
  additional domain scans and contract-preserving union on this workload; it
  is neither a rendering measurement nor a cross-library comparison.
- `categorical_grid_construct_compile` and
  `categorical_shared_grid_construct_compile` compile two 100-bar panels with
  a 50-category overlap, first independently and then with a deterministic
  categorical union. On the 2026-08-15 Darwin arm64 run they averaged
  0.129 ms and 0.229 ms over five iterations after three warmups. Sharing adds
  0.100 ms (78.14% relative) on this deliberately small workload; the large
  percentage reflects a sub-millisecond baseline and must not be presented as
  a general plotting slowdown.
- `facet_construct_compile` partitions one 100,000-row, three-column
  specification into four categorical panels, copies each panel's complete
  typed frame, derives shared numeric domains and compiles the grid. On the
  2026-08-15 Darwin arm64 run it averaged 46.76 ms over five iterations after
  three warmups, versus 34.32 ms for the already separated shared grid in the
  same process. The measured 12.44 ms (36.25%) exposes the current ownership
  cost of materialising facet frames; it is recorded as optimisation work, not
  hidden as plotting overhead.
- `facet_compact_matrix_workload_compile` and
  `facet_matrix_construct_compile` use the same 100,000-row, five-column frame
  containing three observed row/column combinations. The first compacts those
  combinations into three panels; the second preserves the full 2×2 Cartesian
  matrix with one labelled empty cell. On the 2026-08-15 Darwin arm64 run they
  averaged 50.46 ms and 53.95 ms over five iterations after three warmups.
  The matrix contract added 3.49 ms (6.91%) in this paired run, covering the
  second categorical grouping scan, Cartesian bookkeeping and empty-panel
  composition; rendering is not included.
- `construct_compile` and `retained_annotation_construct_compile` are an
  alternating-order pair over the same 100,000-point line-and-point plot. The
  latter adds exactly one plain text node and one UniVector arrow. On the
  2026-08-15 Darwin arm64 run they averaged 21.64 ms and 21.88 ms over five
  iterations after three warmups: a measured difference of 0.24 ms (1.10%).
  Their observed ranges overlap, so this run does not establish a statistically
  reliable slowdown. Rendering and the cost of increasing the annotation count
  are not measured by this stage.
- `descriptive_summary` filters and sorts the 100,000 finite, oscillating y
  values from the reference workload, computes type-7 quartiles and Tukey
  whiskers, collects outliers, and obtains the normalized mean through
  UniAccurate compensated summation. On the 2026-08-15 Darwin arm64 run it
  averaged 7.55 ms over five iterations after three warmups (7.29–7.90 ms).
  Input copying, sorting and temporary normalized storage are included; this
  is not a pre-sorted or allocation-free claim.
- `grouped_box_plot_construct_compile` constructs 100,000 deterministic
  group labels and values, partitions them into eight first-seen groups,
  computes each type-7/Tukey summary, materialises explicit summary and
  outlier rows, and compiles their UniVector box/outlier scene. On the
  2026-08-15 Darwin arm64 run it averaged 14.68 ms over five iterations after
  three warmups (14.56–14.89 ms). String/value construction, grouping,
  sorting, frame allocation and scene compilation are included; SVG/PNG/GPU
  rendering is not.
- `aggregate_2d` groups prepared categorical x/y/value arrays into a complete
  32-by-24 first-seen matrix. On the 2026-08-15 Darwin arm64 run, 100,000
  observations averaged 9.89 ms over five iterations after three warmups
  (9.68–10.11 ms). It includes hashing, finite filtering, per-cell allocation
  and UniAccurate compensated means, but excludes construction of the prepared
  input arrays.
- `categorical_heatmap_construct_compile` constructs those 100,000 labels and
  values, repeats the same aggregation, materialises the retained frame, trains
  two band axes and a continuous UniColor guide, and compiles 96 observed
  UniVector tiles. The same run averaged 14.42 ms (14.32–14.59 ms). SVG, PNG
  and WGPU rendering are excluded; this stage is not compared with competitor
  heatmaps whose aggregation and missing-cell contracts may differ.
- `numeric_heatmap_construct_compile` constructs a 1,000-by-100 boundary grid
  and 100,000 finite values, materialises explicit numeric bounds, samples one
  prepared UniColor ramp and compiles 100,000 UniVector rectangles. On the
  2026-08-16 Darwin arm64 run it averaged 37.01 ms over five iterations after
  three warmups (36.58–37.55 ms). SVG, PNG and WGPU rendering are excluded;
  this measures a dense vector-cell scene, not raster texture upload.
- `aggregate_groups` groups prepared categorical labels and values into 32
  first-seen compensated means. On the 2026-08-15 Darwin arm64 reference run,
  100,000 observations averaged 3.46 ms over five iterations after three
  warmups (3.33–3.60 ms). Hashing, finite filtering, result allocation and
  UniAccurate arithmetic are included; prepared input construction is not.
- `grouped_aggregate_construct_compile` constructs the same labels and values,
  aggregates them, materialises a retained categorical frame and compiles the
  32-bar UniVector scene. The same run averaged 5.81 ms (5.75–5.95 ms). SVG,
  PNG and WGPU rendering are excluded, and this is not a cross-provider grouped
  transform comparison.
- `explicit_histogram_breaks` assigns 100,000 prepared finite samples to 64
  unequal-capable caller-defined bins using binary search. On the 2026-08-15
  Darwin arm64 run it averaged 1.11 ms over five iterations after three
  warmups (1.05–1.15 ms). Boundary validation and result allocation are
  included; input construction is excluded.
- `explicit_histogram_construct_compile` constructs the 100,000 samples and 65
  boundaries, bins them, materialises labels/counts and compiles the 64-bar
  UniVector scene. The same run averaged 1.41 ms (1.38–1.46 ms). SVG, PNG and
  WGPU rendering are excluded.
- `numeric_histogram_density_construct_compile` constructs 100,000 samples and
  65 boundaries, bins and area-normalises them, materialises explicit numeric
  bounds and compiles 64 UniVector rectangles. On the 2026-08-16 Darwin arm64
  run it averaged 1.36 ms over five iterations after three warmups
  (1.35–1.38 ms). This is a construction/scene regression baseline; SVG, PNG
  and WGPU rendering are excluded, and the small difference from the
  categorical histogram stage is within run variability.
- `json_encode` and `json_decode` measure the complete versioned PlotSpec,
  including both 100,000-value numeric columns. The decode input is prepared
  outside the timed loop; encoding and parsing are reported separately. On the
  2026-08-15 Darwin arm64 run, encoding averaged 8.04 ms and decoding averaged
  17.80 ms over five measured iterations for a 2,582,339-byte compact payload.
  These are in-memory, uncompressed schema costs; filesystem, compression and
  network I/O are not included.
- `cpu_prepare_scene` shapes text, independently copies paths and flattens
  UniVector geometry once. `svg_from_prepared_scene` and
  `png_from_prepared_scene` reuse that immutable result; the existing compiled
  scene stages remain alongside them so preparation cost is never hidden. The
  paired stages alternate direct/prepared execution order to reduce ordering
  and allocator bias. On the 2026-08-15 Darwin arm64 run at 100,000 points,
  five iterations after three warmups measured 28.73 ms preparation,
  683.52/679.79 ms direct/prepared SVG and 1047.30/1031.56 ms direct/prepared
  PNG. That is only 0.5% lower SVG time and 1.5% lower PNG time after
  preparation; including preparation, reuse breaks even after roughly eight
  SVG renders or two PNG renders on this workload. These local figures do not
  establish a universal speedup.

They isolate implementation regressions that the common end-to-end workload
could hide. They are not comparisons with similarly named operations in other
libraries.

The transformed/reversed-axis change was checked on the same 2026-08-15
100,000-point reference workload: default linear construction averaged
21.42 ms and continuous-colour construction 31.39 ms over 10 iterations,
against 21.45 ms and 31.45 ms immediately before the change. The differences
are within run-to-run noise; this records absence of a detected regression, not
a performance improvement.

Horizontal text anchoring was checked on the 100,000-point workload over three
iterations after one warmup. Immediately before/after means were 21.55/21.50
ms for construction, 31.95/32.11 ms for four-panel construction,
678.14/678.83 ms for SVG and 1176.85/1182.83 ms for PNG. The largest observed
change was +0.51% for PNG in this short run; it is retained as regression
evidence, not interpreted as a measured slowdown or speedup.

These stages align user intent, not internal work. Matplotlib may defer work to
`savefig`, while UniPlot performs layout in `compileScene`; timings must not be
interpreted as identical instruction sets. Results are evidence for regression
tracking, not universal rankings.

VisPy is an interactive GPU library and requires a controlled GPU/windowing
setup, so it does not belong in this CPU off-screen baseline. Missing runtimes,
packages or static export engines are reported as unavailable and are never
installed implicitly.

## C and Python binding bridge

After building the shared library and Cython extension, run:

```bash
nimble clib
nimble buildCython
nimble benchmarkBindings
```

`benchmarkBindings` first verifies that the C and Python builders produce
byte-identical schema-v1 JSON. It then times encoding and decoding separately
at 100,000 points. The C ABI is invoked through `ctypes`, so those stages
include the small Python-to-ctypes transition and are not labelled as a native
C executable benchmark. The Python stages include the Cython wrapper's buffer
copy, UTF-8 conversion and handle ownership.

On the 2026-08-15 Darwin arm64 reference run, five measured iterations after
three warmups produced 8.74 ms encode / 18.23 ms decode through ctypes and
8.85 ms / 18.37 ms through Cython for the same 2,582,209-byte payload. The
observed wrapper differences of 0.11 ms and 0.15 ms are machine-local and
within a very small sample; they are regression evidence, not general claims
about language overhead.

The same harness also verifies byte-identical C/Python SVG output for a
two-by-two grid containing 100,000 points in total. Five measured iterations
after three warmups averaged 217.35 ms through ctypes and 217.74 ms through
Cython on the same reference machine. The 0.39 ms difference is 0.18% of the
render time and is within this small run's variability; scene compilation,
UniGlyph path generation and SVG serialization dominate the wrapper crossing.

The real WGPU path has a separate pure-Nim benchmark:

```bash
nimble wgpuDeps
nimble wgpuBenchmark
# Same-machine Apple M4 regression gate after the task builds the executable:
UNIPLOT_WGPU_LIBRARY="$PWD/.deps/wgpu/29.0.1.1/macos-aarch64/lib/libwgpu_native.dylib" \
  ./build/benchmark_wgpu 50 1000 build/wgpu-current.json \
  benchmarks/baselines/apple-m4-metal.json
```

It reports preparation, forced-miss upload plus submission, multi-scene
resident submission and publication separately. Preparation shapes UniGlyph
text and tessellates UniVector paths. The upload stage cycles three prepared
handles through a two-entry LRU so every iteration performs a real buffer
write. Warm submission alternates two handles in those two slots, while
publication also reads the 800×500 RGBA8 texture back. Enqueue timing is
CPU-side submission latency, not guaranteed GPU completion or a universal
frame-rate claim. The harness checks uploads, hits, misses and evictions so a
cache hit cannot be mislabeled as an upload measurement.

On the 2026-08-16 Apple M4 Metal run, three alternating before/after runs of 50
iterations measured 0.9784 ms for the former upload-on-every-submit path and
0.9807 ms for the new explicit upload-plus-submit stage. Resident submission
averaged 0.0925 ms, a measured 90.5% reduction in CPU-side submission time.
Publication moved from 4.4218 ms to 3.0970 ms, a measured 30.0% reduction, as
the same buffer write was removed before readback. Preparation remained within
noise at 74.0418 ms before and 73.8936 ms after. These figures apply only to
this adapter, runtime, dependency state and 1,000-point workload.

The earlier 3.13 ms preparation entry in the checked-in baseline was stale:
the immediately preceding UniPlot revision measured 74.04 ms against the same
current local UniGlyph/UniVector dependencies.

The bounded-LRU follow-up uses the same Apple M4 Metal protocol. Across three
50-iteration runs, cycling three handles through two slots averaged 0.9807 ms
and produced exactly 53 misses, 53 uploads and 51 evictions per process.
Alternating two resident handles averaged 0.0855 ms with no additional upload,
91.3% below the forced-miss stage. Preparation averaged 73.9401 ms and
publication 3.0842 ms, both within the preceding run's variation. This proves
two-handle residency for this workload; it does not establish a universal
cache capacity or GPU frame rate. The baseline records this controlled result
and includes a residency-version field so incompatible semantics fail instead
of being compared.

The byte-budget follow-up retains the same two-entry workload while also
bounding allocated prepared vertex/index capacities. The three 50-iteration
runs held exactly 20 MiB at peak under the default 256 MiB budget. Preparation
averaged 73.7487 ms, forced-miss upload plus submission 1.0437 ms, resident
submission 0.0926 ms and publication 3.0782 ms. The 6.4% increase over the
preceding forced-miss mean includes actual buffer release and allocation on
every LRU eviction; it is not attributed to byte accounting alone. Streaming
buffers, render targets and readback storage are outside this prepared-cache
measurement, so 20 MiB is not a total GPU-memory claim.

The next run splits every vertex/index transfer at the default 4 MiB boundary.
Across three 50-iteration processes it issued exactly 159 queue writes for 53
mesh uploads, transferred 541,267,800 bytes and never exceeded 4,194,304 bytes
in one write. Preparation averaged 73.7713 ms, forced-miss upload plus
submission 1.0467 ms, resident submission 0.0935 ms and publication 3.1042 ms.
The forced-miss mean is 0.28% above the preceding byte-budget run and does not
establish a slowdown. These counters measure host-to-queue calls and payload;
they do not measure PCIe traffic, GPU completion, allocation traffic or total
resident memory.

The managed-resource follow-up adds a 512 MiB aggregate bound over prepared and
streaming buffer capacities, readback capacity and logical RGBA16F target
bytes.
Three 50-iteration runs reported an exact 24,668,672-byte current and peak sum:
20,971,520 prepared bytes, 1,600,000 target bytes and a 2,097,152-byte readback
buffer, with no direct-stream buffer retained by this prepared workload.
Preparation averaged 73.7643 ms, forced-miss upload plus submission 1.0618 ms,
resident submission 0.0922 ms and publication 3.0702 ms. The upload mean is
1.44% above the prior three-run mean while the other stages moved in both
directions; this small run does not isolate a statistically reliable policy
cost. Driver-private memory is unavailable and excluded from the byte sum.

The streaming-ring benchmark compares bursts of exactly three direct rectangle
submissions. Before every timed burst, each backend is explicitly drained;
drain time is excluded. A one-slot backend must synchronize the first two
submissions before its slot can be reused, while a three-slot backend enqueues
the whole burst without reuse. Across three 50-iteration processes, the
one-slot burst averaged 3.1346 ms and the three-slot burst 0.0987 ms, a measured
96.85% reduction in CPU-side burst enqueue time. This is not a frame-rate,
GPU-execution or sustained-throughput speedup: completion is deliberately
outside the timed boundary, both paths still upload the same geometry, and a
producer that outruns all three slots must synchronize on later reuse. The
harness verifies 106 exact slot synchronizations per one-slot process and zero
inside the drained three-slot bursts.

The optional fourth argument compares the current means with a baseline only
after adapter, backend, workload, canvas and residency semantics match. Each
phase carries its own ratio derived from repeated runs, because asynchronous
submission is materially noisier than preparation or readback. Add a separate
baseline for a different machine; never reuse these thresholds across hardware.

The semantic-key follow-up adds three CPU-side stages before submission. On
the same Apple M4 Metal setup, three independent 50-iteration processes gave
means of 0.8433 ms to hash the 1,000-point canonical scene, 0.8225 ms to hash
and hit the host preparation cache, and 0.8399 ms to hash, hit both host and GPU
caches, and enqueue. Explicit preparation averaged 73.7170 ms, so the automatic
host hit avoided 98.88% of that measured preparation time. It was nevertheless
about nine times the 0.0915 ms explicit resident-handle submission: automatic
mutation detection is not free. The automatic path remained 19.1% below the
1.0382 ms forced-upload stage on this workload. These comparisons are
CPU-side wall times, not GPU completion or frame-rate claims.

Every process recorded exactly one host-cache miss, 107 hits, no host eviction
and 10,212,600 retained logical vertex/index bytes. That byte count excludes
sequence capacity, object headers, allocator metadata and transient key/hash
state; it is a cache admission budget, not process RSS. The native prepared
cache and managed-GPU counters remain separate. The baseline's residency field
includes `scene-key-v1`, preventing comparison with the earlier protocol.
