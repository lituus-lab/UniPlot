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
                color="#3366cc", width=2.0)
          .scatter([0, 1, 2], [1, 3, 2],
                   color="#cc3344", radius=4.0)
          .title("Measurements"))

Path("plot.svg").write_bytes(figure.svg(font))
Path("plot.png").write_bytes(figure.png(font))
```

Methods return `self`, so construction can be chained. `svg()` and `png()`
return Python `bytes`; the Cython layer always frees the native buffer after
copying it.

## API and validation

- `Plot(width=800, height=500)` owns one native plot handle.
- `line(xs, ys, color="#3366cc", width=2.0)` adds a line series.
- `scatter(xs, ys, color="#3366cc", radius=4.0)` adds points.
- `title(text)` sets the plot title.
- `svg(font_path)` and `png(font_path)` render bytes.
- `version()`, `abi_version()` and `__version__` expose compatibility.

Inputs accept Python iterables and are converted to contiguous double arrays.
Length mismatches raise `ValueError` before the native call. Native argument or
render failures become Python exceptions. An explicit TrueType font path is
required for deterministic output.

## Packaging contract

The wheel carries the platform-specific shared library next to the extension.
The sdist carries the Nim sources needed to rebuild it, but excludes prebuilt
native binaries. Linux, macOS and Windows wheels use their platform loader and
ABI conventions.

The Python binding intentionally exposes the stable line/point subset. Use pure
Nim for the complete layered grammar until the foreign API grows under an
explicit ABI version.

Next: [Rosetta stone and benchmarks](rosetta_benchmarks.html).
"""

nbSave
validatePage("python_binding.html")
