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
  import UniGlyph
  import UniPlot
  import UniPlot/render/wgpu

  var spec = scatterPlot([0.0, 1.0, 2.0], [1.0, 3.0, 2.0])
  spec.labels(title = "GPU-ready semantics")
  let scene = spec.compileScene(Size(width: 640, height: 400))
  let frame = prepareWgpuFrame(scene)
  let prepared = prepareWgpuScene(scene, loadTtf("../../tests/DejaVuSans.ttf"))
  let capabilities = wgpuCapabilities()

  echo "target wgpu-native: ", WgpuNativeTargetVersion
  echo "frame size: ", frame.size.width, " × ", frame.size.height
  echo "scene nodes: ", frame.nodeCount
  echo "semantic resources: ", frame.resources.len
  echo "prepared target: ", prepared.size.width, " × ", prepared.size.height
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

`prepareWgpuScene(scene, font)` uses the same UniGlyph layouts and UniVector
tessellation as the CPU backends. Its first submission uploads and enqueues the
retained indexed geometry. Reusing that exact prepared handle keeps its
vertex/index pair resident. A backend retains at most four prepared handles and
256 MiB of their allocated vertex/index capacities by default. Configure the
contractual limits with `preparedCacheCapacity` (1 through 64) and
`preparedCacheByteBudget` (at least 512 bytes). Eviction is least-recently-used
until both limits hold; a single scene exceeding the byte budget is rejected.
Direct streaming buffers, render targets and readback storage are outside that
prepared-cache budget. `renderWgpuPrepared` additionally returns unpadded RGBA8
pixels. The convenience scene overloads prepare on every call. The headless
validation task checks individual pixels, exact CPU/GPU parity, direct uploads,
cache hits and LRU eviction. Run `nimble wgpuBenchmark` to measure preparation,
forced misses, alternating resident submission and publication separately.

Vertex and index transfers are issued in aligned chunks no larger than 4 MiB
by default. Pass `uploadChunkBytes` to choose a multiple of four bytes from 4
bytes through 64 MiB. `WgpuDiagnostics` reports queue-write calls, exact bytes
submitted and the largest individual write. This is a per-call transfer bound;
it is not a ring buffer or a bound on total backend memory.

`managedGpuByteBudget` defaults to 512 MiB and must be at least as large as the
prepared-cache budget. UniPlot accounts allocated prepared and direct buffer
capacities, readback capacity and the logical RGBA8 target payload together.
Resource growth first evicts unprotected LRU entries and otherwise fails before
allocation. Current, component and peak values are available in diagnostics.
This is a hard bound for those UniPlot-managed quantities, not a measurement of
opaque driver padding, metadata, command storage or internal allocations.

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
