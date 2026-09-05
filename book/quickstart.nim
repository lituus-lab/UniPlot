# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Installation and quick start

## Install

```bash
nimble install https://github.com/lituus-lab/UniPlot
```

In a checkout, `nimble install -y` resolves the Uni* dependencies. Rendering
requires an explicit TrueType font path so results do not depend on platform
font discovery.

## First plot
"""

nbCode:
  import UniPlot
  import UniGlyph

  let font = loadTtf("../../tests/DejaVuSans.ttf")
  var figure = linePlot([0.0, 1.0, 2.0, 3.0], [1.0, 3.0, 2.0, 4.0])
  figure.labels(title = "First UniPlot", x = "time", y = "value")
  let scene = figure.compileScene(Size(width: 720, height: 420))
  let svg = scene.toSvg(font)
  echo "UniPlot ", UniPlotVersion, " — ", scene.nodes.len, " scene nodes"

nbRawHtml svgFigure(svg,
  "A recipe becomes a retained scene, then deterministic SVG output.")

nbText: """
The stable workflow is:

1. create a `PlotSpec` with a recipe or the layered grammar;
2. compile it for a concrete `Size`;
3. render the resulting `Scene` with an explicit font.

The specification and scene are ordinary values. Layout happens once, before
the backend, so SVG, PNG and future GPU output share the same semantics.

## Build this manual

```bash
nimble docsDeps  # install nimib + nimibook once
nimble book      # executable manual -> book/__site/
nimble docs      # manual + API reference -> pages/
```

The benchmark ecosystem is separate and explicit: `nimble benchmarkDeps`
installs isolated optional dependencies, then `nimble benchmark` runs the
cross-library protocol.

Continue with [Typed data](data.html), or go directly to
[Recipes and layered grammar](grammar.html).
"""

nbSave
validatePage("quickstart.html", minSvg = 1)
