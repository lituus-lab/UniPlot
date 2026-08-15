<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# uniplot

Python bindings for the pure-Nim UniPlot engine.

```python
from pathlib import Path
import uniplot

font = Path("DejaVuSans.ttf")
figure = (uniplot.Plot(800, 500)
          .line([0, 1, 2], [1, 3, 2], style=uniplot.LINE_DOT_DASH)
          .scatter([0, 1, 2], [1, 3, 2], color="#cc3344",
                   shape=uniplot.MARKER_DIAMOND)
          .title("Measurements"))

Path("plot.svg").write_bytes(figure.svg(font))
Path("plot.png").write_bytes(figure.png(font))
```

The wheel bundles the native UniPlot library. Rendering requires an explicit
TrueType font path so results do not depend on host font discovery.
Line styles and marker shapes use the `LINE_*` and `MARKER_*` constants and
are rendered by the same UniVector geometry as the Nim API.
`MISSING_BREAK`, `MISSING_DROP` and `MISSING_REJECT` select explicit handling
for `NaN` and infinite mapped values. Lines break by default; points drop them.
