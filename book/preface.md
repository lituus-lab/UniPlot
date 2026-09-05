# UniPlot 1.0

UniPlot is the pure-Nim scientific visualisation engine of the Uni* family. It
turns typed data and plotting specifications into a renderer-neutral retained
scene, then exports that scene through deterministic CPU backends.

This manual is executable. Nimib compiles the examples, while nimibook builds
the chapters and navigation. Every displayed plot is regenerated from the
current UniPlot API. SVG is inserted inline and PNG is encoded as a Base64
`data:` URL, so the final HTML pages carry their plot images with them.

## What UniPlot 1.0 covers

- typed numeric and categorical data;
- finite-row filtering;
- linear, logarithmic and categorical scales;
- symmetric-logarithmic, signed-power, UTC, duration and polar coordinates;
- line, point, bar, area and text layers;
- concise publication recipes including histograms, density, smoothing,
  box/violin, heatmap and contour plots;
- legends, facets, subplot grids, annotations and image marks;
- axes, ticks, labels, titles and themes;
- an inspectable retained scene shared by every backend;
- deterministic SVG and PNG rendering;
- deterministic, versioned JSON plot specifications;
- a CLI, stable C ABI and Python binding;
- an optional WGPU resource boundary with no GPU dependency in the core.

## Suggested path

Start with [Installation and quick start](quickstart.html), then learn the two
construction styles in [Recipes and layered grammar](grammar.html). The later
chapters explain the lower-level components used by adapters and future
backends.

## The 1.0 boundary

Version 1.0 does not promise 3D scenes, volume rendering, rich multi-style text,
PDF export, arbitrary shader injection or a GUI event loop. Stable scene
identifiers and the WGPU boundary are designed so interactivity, picking and
streaming can grow without changing the CPU scene contract.
