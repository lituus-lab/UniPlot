# Architecture and roadmap

UniPlot separates the meaning of a plot from the device that draws it.

```text
data -> mappings -> statistics -> scales -> guides -> scene -> backend
                                                     |-> SVG
                                                     |-> raster/PNG
                                                     `-> optional WGPU
```

The dependency direction inside the library is fixed:

```text
common < data < scales < stats < grammar < scene < guides < render < c_api
```

Backends consume scenes. They never participate in data filtering, statistics,
scale training or layout. Equal specifications, dimensions and font inputs
therefore produce equal scene ordering and deterministic vector output.

## Uni* ownership

- UniColor parses and represents colours.
- UniVector owns vector paths and fills.
- UniImage owns raster images and PNG encoding.
- UniGlyph owns font loading, text layout and glyph outlines.
- UniPlot owns plotting semantics, scales, guides and retained scenes.
- UniGeom and UniGraph may consume UniPlot through adapters; UniPlot never
  imports these higher-level domain libraries.

## CPU and GPU

SVG and PNG are the 1.0 reference backends. The WGPU module currently defines
resource identities, capabilities and frame preparation without loading a
native runtime. A later optional package can bind wgpu-native while preserving
the same compiled scene and stable mark IDs.

## Current extension points

- stable non-zero scene-node identifiers for picking;
- renderer-neutral paths and text runs;
- inspectable scale and scene values;
- direct scene construction for domain adapters;
- an optional backend module outside the default import;
- C ABI versioning for foreign consumers.

## Not yet part of the 1.0 promise

Facets, smoothing, date-aware scales, legends, 3D and volume rendering,
observables, streaming, GUI event loops and arbitrary shader injection are
future work. They should extend the retained-scene contract rather than create
parallel plotting semantics.

## Reference and contribution

The generated [API reference](api/UniPlot.html) gives symbol-level signatures.
Run `nimble testAll` for the full native suite, `nimble pyTest` for Python,
`nimble book` for this manual and `nimble docs` for the publishable site.

UniPlot is Apache-2.0 licensed. Contributions require DCO sign-off.
