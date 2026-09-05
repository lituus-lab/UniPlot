# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Rosetta stone and benchmarks

This chapter translates one line-plus-point plot across plotting ecosystems.
The goal is conceptual equivalence, not identical defaults: each library owns
different font metrics, colour models, layout policies and renderer lifecycles.

## Reference result in UniPlot
"""

nbCode:
  import UniPlot
  import UniGlyph

  let x = [0.0, 1.0, 2.0, 3.0]
  let y = [1.0, 3.0, 2.0, 4.0]
  var reference = linePlot(x, y, color = "#3366cc")
  reference.geomPoint(aes("x", "y"), color = "#cc3344", radius = 5)
  reference.labels(title = "Measurements", x = "time", y = "value")
  let font = loadTtf("../../tests/DejaVuSans.ttf")
  let referenceSvg = reference.compileScene(
    Size(width: 720, height: 420)).toSvg(font)

nbRawHtml svgFigure(referenceSvg,
  "The semantic target used by every Rosetta example below.")

nbText: """
## Pure Nim — UniPlot

```nim
var figure = linePlot(x, y, color = "#3366cc")
figure.geomPoint(aes("x", "y"), color = "#cc3344", radius = 5)
figure.labels(title = "Measurements", x = "time", y = "value")
let scene = figure.compileScene(Size(width: 720, height: 420))
scene.saveSvg(loadTtf("DejaVuSans.ttf"), "plot.svg")
```

## Python — Matplotlib

```python
from matplotlib import pyplot as plt

fig, ax = plt.subplots(figsize=(7.2, 4.2), dpi=100)
ax.plot(x, y, color="#3366cc", linewidth=2)
ax.scatter(x, y, color="#cc3344", s=25)
ax.set(title="Measurements", xlabel="time", ylabel="value")
fig.savefig("plot.svg")
```

Matplotlib's axes retain artists and usually perform final layout during draw
or `savefig`. UniPlot compiles a backend-neutral scene explicitly first.

## R — ggplot2

```r
library(ggplot2)
data <- data.frame(time=c(0, 1, 2, 3), value=c(1, 3, 2, 4))

plot <- ggplot(data, aes(time, value)) +
  geom_line(colour="#3366cc", linewidth=0.8) +
  geom_point(colour="#cc3344", size=3) +
  labs(title="Measurements", x="time", y="value")
ggsave("plot.svg", plot, width=7.2, height=4.2)
```

Both ggplot2 and UniPlot express data, aesthetics and geometries separately.
ggplot2 offers a much broader statistical and faceting ecosystem; UniPlot 1.0
keeps a smaller typed core and deterministic scene boundary.

## Julia — Plots.jl

```julia
using Plots
x = [0.0, 1.0, 2.0, 3.0]
y = [1.0, 3.0, 2.0, 4.0]

p = plot(x, y; color="#3366cc", linewidth=2, label=false,
         title="Measurements", xlabel="time", ylabel="value")
scatter!(p, x, y; color="#cc3344", markersize=5, label=false)
savefig(p, "plot.svg")
```

Plots.jl routes one high-level API to several backends. UniPlot instead fixes
one retained scene contract and asks each backend to consume that scene.

## Python/OpenGL — VisPy

```python
from vispy import plot as vp

figure = vp.Fig(size=(720, 420), show=False)
axes = figure[0, 0]
axes.plot((x, y), color="#3366cc", symbol="o",
          marker_face_color="#cc3344", marker_size=5)
image = figure.render()
```

VisPy targets interactive GPU visualisation and very large datasets. Its window,
canvas and GPU lifecycle are not equivalent to UniPlot's CPU publication
pipeline; it belongs in the capability comparison but not an uncontrolled
headless CPU timing table.

## Python/WebGL — Plotly

```python
import plotly.graph_objects as go

figure = go.Figure(go.Scatter(
    x=x, y=y, mode="lines+markers",
    line={"color": "#3366cc", "width": 2},
    marker={"color": "#cc3344", "size": 5}))
figure.update_layout(title="Measurements",
                     xaxis_title="time", yaxis_title="value")
figure.write_html("plot.html")
figure.write_image("plot.svg")  # requires the Kaleido image engine
```

Plotly targets interactive browser graphics and serialises a declarative JSON
figure. Static SVG/PNG export goes through Kaleido. UniPlot's core output is
static and deterministic; browser interaction belongs to a future backend.

## Feature correspondence

| Concept | UniPlot | Matplotlib | ggplot2 | Plots.jl | VisPy | Plotly |
|---|---|---|---|---|---|---|
| input | typed `DataFrame` | arrays/artists | data frame | arrays/recipes | arrays/visuals | arrays/data frame |
| mapping | `aes` | call arguments | `aes` | series arguments | visual arguments | trace properties |
| composition | typed layers | axes artists | grammar layers | `plot!` recipes | scene visuals | figure traces |
| retained boundary | `Scene` | figure/artist tree | plot build | backend plot | GPU scene graph | JSON figure |
| SVG/PNG | reference CPU backend | `savefig` | graphics device | backend-dependent | not primary | Kaleido |
| interaction | future backend | backend-dependent | usually extension | backend-dependent | GPU-native | browser-native |

## Reproducible benchmark

```bash
nimble benchmarkDeps
nimble benchmark
nimble benchmarkScales
nimble benchmarkThermals
nimble benchmarkMemory
python3 benchmarks/run_benchmarks.py 50 5000
```

The baseline uses a 1,000-point line-plus-scatter plot, 800×500 canvas, three
warmups and 20 measured iterations. It records mean, sample standard deviation,
minimum and maximum for:

1. specification/artist construction plus UniPlot scene compilation;
2. SVG serialization from the retained plot;
3. PNG serialization from the retained plot.

Results are written to `benchmarks/results/latest.json` with versions and
machine metadata. Matplotlib's Agg backend and Plotly/Kaleido are measured when
installed. The runner records missing providers instead of installing packages
or silently dropping them.

`benchmarkScales` runs the same output semantics at 10³, 10⁵ and 10⁶ points
and records all three reports in `benchmarks/results/workload_suite.json`.
The largest case still serializes actual SVG and PNG output; it is not a
construction-only substitute presented as an end-to-end result.

`benchmarkThermals` records fresh-process wall time separately from warmed
per-stage measurements. The cold boundary includes runtime and library startup,
reference construction, one real SVG and PNG render, serialization and
shutdown; UniPlot compilation happens before its measured provider process.
The book does not derive a misleading ratio between that boundary and a warm
individual stage.

The stages align user intent, not implementation internals: Matplotlib can
defer layout to `savefig`, whereas UniPlot performs it in `compileScene`.
Numbers are suitable for regression tracking on the same machine, not for a
universal “fastest library” claim.

The separate `benchmarkMemory` task runs construction, CPU preparation, SVG
serialization and PNG serialization in fresh release-mode ORC processes. It
records process RSS and Nim heap high-water marks in
`benchmarks/results/memory.json`; it does not pretend that retained heap growth
equals cumulative allocated bytes. At 100,000 points on the 2026-08-16 Darwin
arm64 reference machine, construction/compilation peaked at 140.30 MB RSS,
prepared-scene creation at 202.70 MB, and real 51.06 MB SVG serialization at
325.52 MB. PNG serialization did not exceed the 202.70 MB high-water mark of
its prepared-scene setup. These single-run values are regression observations,
not cross-library memory rankings.

UniPlot additionally reports an `uncertainty_construct_compile` diagnostic:
one line, one contiguous ribbon and one capped error bar per row. A 100,000-row
Darwin arm64 run on 2026-08-15 averaged 47.03 ms over five measured iterations,
versus 21.29 ms for the common line-plus-point construction in the same
process. This 2.21x ratio includes actual UniVector stroke expansion for all
100,000 intervals. It is an internal regression baseline, not a comparison
with differently specified uncertainty marks in other libraries.

The reusable-theme diagnostic averaged 21.47 ms for the dark preset versus
21.37 ms for the default theme at 100,000 points in the same five-iteration
run. The 0.10 ms difference is within run-to-run noise; it records that preset
application introduced no detected construction regression.

Categorical heatmaps have two explicit stages. On the same 2026-08-15 Darwin
arm64 protocol, aggregating 100,000 prepared observations into the complete
32-by-24 matrix averaged 9.89 ms over five iterations (9.68–10.11 ms). Full
input construction, aggregation, retained-frame creation, two band axes, a
continuous UniColor guide and compilation of the 96 observed UniVector tiles
averaged 14.42 ms (14.32–14.59 ms). Neither stage includes SVG, PNG or WGPU
rendering, and neither is ranked against competitor heatmaps with different
aggregation and missing-cell semantics.

The numeric grid diagnostic constructs 1,000 x intervals by 100 y intervals,
materialises 100,000 explicit cell bounds, samples one prepared UniColor ramp
and compiles 100,000 UniVector rectangles. On the 2026-08-16 Darwin arm64 run
it averaged 37.01 ms over five iterations after three warmups
(36.58–37.55 ms). SVG, PNG and WGPU rendering are excluded. This is a dense
vector-cell benchmark, not a raster texture-upload measurement.

One-dimensional grouped aggregation is measured separately. Grouping 100,000
prepared observations into 32 first-seen compensated means averaged 3.46 ms
over five iterations after three warmups (3.33–3.60 ms). Constructing those
labels and values, repeating the aggregation, materialising the retained frame
and compiling its 32 UniVector bars averaged 5.81 ms (5.75–5.95 ms). SVG, PNG
and WGPU rendering are excluded, as is prepared input construction from the
first stage; these internal timings are not ranked against competitors with
different grouping contracts.

Explicit histogram boundaries are also isolated. Assigning 100,000 prepared
samples to 64 caller-defined bins averaged 1.11 ms over five iterations after
three warmups (1.05–1.15 ms), including boundary validation and result
allocation. Constructing the samples and 65 boundaries, binning, materialising
labels/counts and compiling the 64-bar UniVector scene averaged 1.41 ms
(1.38–1.46 ms). Rendering is excluded from both stages.

The numeric density variant constructs the same 100,000 samples and 65
boundaries, bins and area-normalises them, materialises numeric rectangle
bounds and compiles 64 UniVector rectangles. A 2026-08-16 Darwin arm64 run
averaged 1.36 ms over five iterations after three warmups (1.35–1.38 ms).
SVG, PNG and WGPU rendering are excluded; the small difference from the
categorical construction stage is within ordinary run variability.

Versioned PlotSpec JSON is measured in two stages. For 100,000 rows on the
same 2026-08-15 Darwin arm64 run, in-memory encoding averaged 8.04 ms and
decoding averaged 17.80 ms over five measured iterations. The input JSON is
prepared before the timed decode loop and contains 2,582,339 uncompressed
bytes. Neither stage includes filesystem, compression or network I/O.

The binding harness additionally requires byte-identical C and Python JSON.
For a 2,582,209-byte, 100,000-point payload it measured 8.74/18.23 ms
encode/decode through the C ABI via ctypes and 8.85/18.37 ms through Cython.
These five-iteration Darwin arm64 measurements include the respective foreign
call transitions; the ctypes result is not misrepresented as a native C
executable benchmark.

`benchmarkDeps` is deliberately explicit. It creates isolated environments
under `build/`, installs Python plotting dependencies there, and only installs
ggplot2/Plots.jl when their R/Julia runtimes already exist. The normal library
and documentation builds never fetch benchmark ecosystems.

See `benchmarks/README.md` for the complete protocol and
[Architecture and roadmap](architecture.html) for UniPlot's design boundary.
"""

nbSave
validatePage("rosetta_benchmarks.html", minSvg = 1)
