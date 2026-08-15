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

The stages align user intent, not implementation internals: Matplotlib can
defer layout to `savefig`, whereas UniPlot performs it in `compileScene`.
Numbers are suitable for regression tracking on the same machine, not for a
universal “fastest library” claim.

`benchmarkDeps` is deliberately explicit. It creates isolated environments
under `build/`, installs Python plotting dependencies there, and only installs
ggplot2/Plots.jl when their R/Julia runtimes already exist. The normal library
and documentation builds never fetch benchmark ecosystems.

See `benchmarks/README.md` for the complete protocol and
[Architecture and roadmap](architecture.html) for UniPlot's design boundary.
"""

nbSave
validatePage("rosetta_benchmarks.html", minSvg = 1)
