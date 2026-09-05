# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Command-line interface

The `uniplot` executable provides a small native smoke-test and export surface
without requiring a Nim application.

## Build and inspect

```bash
nimble uniplot
bin/uniplot inspect
```

`inspect` prints `version=<version>` and the retained node count of the built-in
demonstration specification.

## Render

```bash
bin/uniplot render \
  --font tests/DejaVuSans.ttf \
  --output plot.svg \
  --width 1200 \
  --height 700

bin/uniplot render --font tests/DejaVuSans.ttf --output plot.png
```

The output suffix selects SVG or PNG. Width and height default to 800 × 500.
The font and output options are mandatory, invalid dimensions fail through the
same `PlotError` checks as the Nim API, and an unsupported suffix raises
`ValueError`.

## Current scope

The 1.0 CLI renders its built-in line-and-point specification. It is intended
for installation checks and direct backend verification; data ingestion and
the full grammar remain in the Nim API.

Next: [C binding](c_binding.html).
"""

nbSave
validatePage("cli.html")
