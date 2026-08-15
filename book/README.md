<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPlot Book

Multipage executable nimib/nimibook user manual for UniPlot. It covers installation, typed data,
recipes, the layered grammar, every 1.0 geometry, themes, scales, statistics,
the retained scene, SVG/PNG output, WGPU preparation, error handling, dedicated
CLI/C/Python chapters, and a cross-language Rosetta/benchmark chapter. `nimble
book` compiles and runs every Nim code block
before writing the navigable site under `book/__site/`; `nimble docs` publishes
it alongside the generated API reference.

The generated plots are self-contained in their final HTML pages. SVG output
is inserted inline and PNG output is encoded as a Base64 `data:` URL. Visual
chapters assert their expected render count and reject plot images that depend
on relative external files.
