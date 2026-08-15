# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Python binding

The Python package wraps the stable C ABI with Cython and bundles the native
UniPlot library in its wheel.

The figures below are committed outputs of `py/examples/book_demo.py`, using
the public `uniplot.Plot` class. Regenerate both binding demonstrations with
`nimble bindingBookDemos`.

## Build and test from a checkout

```bash
nimble buildCython  # native library + in-place Cython extension
nimble pyTest       # build then run pytest
nimble pyWheel      # wheel under py/dist/
nimble pySdist      # source distribution under py/dist/
```

## Complete example

```python
from pathlib import Path
import uniplot

font = Path("DejaVuSans.ttf")
figure = (uniplot.Plot(800, 500)
          .line([0, 1, 2], [1, 3, 2],
                color="#3366cc", width=2.0,
                style=uniplot.LINE_DOT_DASH)
          .scatter([0, 1, 2], [1, 3, 2],
                   color="#cc3344", radius=4.0,
                   shape=uniplot.MARKER_DIAMOND)
          .title("Measurements"))

payload = figure.to_json()
figure = uniplot.Plot.from_json(payload, width=800, height=500)

Path("plot.svg").write_bytes(figure.svg(font))
Path("plot.png").write_bytes(figure.png(font))

other = uniplot.Plot().scatter([0, 1, 2], [2, 1, 3])
Path("grid.svg").write_bytes(
    uniplot.grid_svg([figure, other], font, columns=2,
                     shared_x=True, shared_y=True))
Path("grid.png").write_bytes(
    uniplot.grid_png([figure, other], font, columns=2,
                     shared_x=True, shared_y=True))
```

Methods return `self`, so construction can be chained. `svg()` and `png()`
return Python `bytes`; the Cython layer always frees the native buffer after
copying it.

## API and validation

- `Plot(width=800, height=500)` owns one native plot handle.
- `line(xs, ys, color="#3366cc", width=2.0, style=LINE_SOLID)` adds a line
  series; five `LINE_*` constants select the UniVector stroke style. Its
  `missing` argument defaults to `MISSING_BREAK`.
- `scatter(xs, ys, color="#3366cc", radius=4.0, shape=MARKER_CIRCLE)` adds
  points; six `MARKER_*` constants select the UniVector marker path. Its
  `missing` argument defaults to `MISSING_DROP`.
- `MISSING_DROP`, `MISSING_BREAK` and `MISSING_REJECT` control `NaN` and
  infinite values explicitly; rejection is reported when rendering compiles
  the retained specification.
- `title(text)` sets the plot title.
- `secondary_y(scale=1.0, offset=0.0, label="")` adds an affine right-side
  guide; `clear_secondary_y()` removes it.
- `annotate_text(x, y, text, color="#202124", font_size=13)` and
  `annotate_arrow(x, y, x_end, y_end, color="#202124", width=2,
  head_size=8)` retain numeric data-coordinate annotations;
  `clear_annotations()` removes them.
- `boxplot(groups, values, whisker_length=1.5, ...)` builds grouped type-7
  summaries on an empty `Plot`. Calling it after another mark is rejected
  instead of silently replacing or combining incompatible retained data.
- `heatmap(x, y, values, aggregation=AGG_MEAN)` builds a complete categorical
  matrix on an empty `Plot`. `AGG_COUNT`, `AGG_SUM`, `AGG_MEAN`,
  `AGG_MINIMUM` and `AGG_MAXIMUM` expose the native aggregation choices.
- `svg(font_path)` and `png(font_path)` render bytes.
- `grid_svg(plots, font_path, columns, width=1200, height=800, gap=16,
  shared_x=False, shared_y=False)` and `grid_png(...)` compose borrowed `Plot`
  instances without transferring ownership. Shared flags derive common
  numeric domains or categorical x order and reject incompatible coordinate
  kinds, transforms or directions.
- `categorical_column(name, values)` copies a string iterable into the retained
  frame. `facet_svg(plot, column, font_path, columns, ...)` and `facet_png`
  partition that plot in first-seen category order and accept the same shared
  domain flags.
- `facet_matrix_svg(plot, row_column, column_column, font_path, ...)` and its
  PNG counterpart preserve the Cartesian row-by-column matrix, including
  labelled empty combinations.
- `to_json()` returns the complete schema-v1 specification as `str`;
  `Plot.from_json(payload, width, height)` accepts `str` or UTF-8 `bytes` and
  restores a full Nim grammar specification.
- `version()`, `abi_version()` and `__version__` expose compatibility.

Inputs accept Python iterables and are converted to contiguous double arrays.
An x/y length mismatch within one call raises `ValueError` before the native
call. Different series lengths are supported and resolved through their
missing-value policies. Native argument or render failures become Python
exceptions. An explicit TrueType font path is required for deterministic
output.

## Packaging contract

The wheel carries the platform-specific shared library next to the extension.
The sdist carries the Nim sources needed to rebuild it, but excludes prebuilt
native binaries. Linux, macOS and Windows wheels use their platform loader and
ABI conventions.

The direct Python builders intentionally expose the stable styled line/point
subset. The JSON bridge gives Python lossless transport of every valid Nim
grammar feature without reimplementing its validation or rendering semantics
in Cython. More ergonomic builders can grow additively over that foundation.

Next: [Rosetta stone and benchmarks](rosetta_benchmarks.html).
"""

let
  pythonSvg = readFile("../assets/generated/python_binding.svg")
  pythonPng = pngDataUri(readFile("../assets/generated/python_binding.png"))
  pythonBoxSvg = readFile("../assets/generated/python_boxplot.svg")
  pythonBoxPng = pngDataUri(readFile("../assets/generated/python_boxplot.png"))
  pythonHeatSvg = readFile("../assets/generated/python_heatmap.svg")
  pythonHeatPng = pngDataUri(readFile("../assets/generated/python_heatmap.png"))
nbRawHtml gallery([
  svgFigure(pythonSvg, "An annotated matrix returned by Python `facet_matrix_svg`."),
  pngFigure(pythonPng, "The same matrix, including its empty cell, as PNG.",
    "A categorical facet matrix rendered through the UniPlot Python binding"),
  svgFigure(pythonBoxSvg, "A grouped boxplot built through `Plot.boxplot`."),
  pngFigure(pythonBoxPng, "The same Python boxplot as an embedded PNG.",
    "A grouped boxplot rendered through the UniPlot Python binding"),
  svgFigure(pythonHeatSvg, "A categorical heatmap built through `Plot.heatmap`."),
  pngFigure(pythonHeatPng, "The same Python heatmap as an embedded PNG.",
    "A categorical heatmap rendered through the UniPlot Python binding")
])

nbSave
validatePage("python_binding.html", minSvg = 3, requirePng = true)
