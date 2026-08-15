# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# WGPU and validation

## Optional WGPU boundary

Importing `UniPlot` never loads WGPU. The optional module extracts semantic
resources from a scene before any native device exists. When explicitly opened,
the backend dynamically loads the pinned wgpu-native runtime and creates a real
adapter, device and queue without changing plot layout.
"""

nbCode:
  import UniPlot
  import UniPlot/render/wgpu

  var spec = scatterPlot([0.0, 1.0, 2.0], [1.0, 3.0, 2.0])
  spec.labels(title = "GPU-ready semantics")
  let scene = spec.compileScene(Size(width: 640, height: 400))
  let frame = prepareWgpuFrame(scene)
  let capabilities = wgpuCapabilities()

  echo "target wgpu-native: ", WgpuNativeTargetVersion
  echo "frame size: ", frame.size.width, " × ", frame.size.height
  echo "scene nodes: ", frame.nodeCount
  echo "semantic resources: ", frame.resources.len
  echo "native backend linked: ", capabilities.available

nbText: """
`WgpuBackendState` models unavailable, ready and device-lost states.
`WgpuCapabilities` advertises picking, storage buffers and timestamp queries.
`WgpuResourceKind` distinguishes path meshes, glyph atlases and image textures;
`WgpuFrame` carries size, resources and node count. Calling
`openWgpuBackend(path)` makes capabilities reflect the live native device;
without that explicit call they remain unavailable and no library is loaded.

Install and validate the optional runtime from the repository root:

```text
nimble wgpuDeps
nimble wgpuTest
```

The installer and tasks are written in Nim. Native artifacts are pinned to
wgpu-native 29.0.1.1 and stored under the ignored `.deps` directory.

## Typed failures

Plotting-domain and user-input failures raise `PlotError`. UniPlot rejects
invalid state before rendering rather than repairing it per backend.
"""

nbCode:
  proc explainFailure(label: string; body: proc()) =
    try:
      body()
    except PlotError as error:
      echo label, ": ", error.msg

  explainFailure("invalid dimensions"):
    Size(width: 0, height: 200).validate()
  explainFailure("invalid log domain"):
    discard continuousScale(0, 10, 0, 100, skLog10)
  explainFailure("mismatched columns"):
    var bad = initDataFrame()
    bad.addColumn("x", [1.0, 2.0])
    bad.addColumn("y", [1.0])
  explainFailure("empty plot"):
    var empty = initDataFrame()
    empty.addColumn("x", [1.0])
    discard plot(empty).compileScene()

nbText: """
Validation also covers missing or wrongly typed columns, empty scale training,
non-positive logarithmic values, invalid tick counts and band padding, invalid
CSS colours, absent text labels, degenerate margins, invalid mark sizes and nil
fonts.

## Shared geometry checks

`Size.validate` requires positive dimensions. `Bounds.width` and
`Bounds.height` expose extents, while `isFinite` is shared by data, scale and
layout validation.
"""

nbCode:
  let bounds = Bounds(xMin: 10, yMin: 20, xMax: 110, yMax: 70)
  echo "bounds: ", bounds.width, " × ", bounds.height
  echo "42 is finite: ", isFinite(42.0)

nbText: """
Next: [Command-line interface](cli.html).
"""

nbSave
validatePage("wgpu_errors.html")
