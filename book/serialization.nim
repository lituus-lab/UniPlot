# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Versioned JSON

`PlotSpec` has a declarative JSON representation for reproducible storage,
process boundaries and future remote rendering. The root identifier is
`org.lituus-lab.uniplot.plot-spec`; `version` is currently `1`. A decoder never
guesses how to interpret another identifier or a future version.

## Deterministic round trip

`toJson` preserves data-column order, layer order, references, mappings,
scales, legends, themes and compatible UniColor palettes. `fromJson` rebuilds
the typed values. The following example renders the original and decoded
specifications through the ordinary retained-scene path.
"""

nbCode:
  import UniPlot
  import UniPlot/serialization as plotSerialization
  import UniGlyph

  var frame = initDataFrame()
  frame.addColumn("x", [1.0, 2.0, 3.0, 4.0, 5.0])
  frame.addColumn("estimate", [1.4, 2.0, 2.7, 3.1, 4.0])
  frame.addColumn("lower", [0.9, 1.4, 2.0, 2.3, 3.1])
  frame.addColumn("upper", [2.0, 2.7, 3.5, 4.0, 4.9])

  var original = plot(frame)
  let bounds = aes("x", "", yMin = "lower", yMax = "upper")
  original.geomRibbon(bounds, color = "#6f8fd955")
  original.geomErrorBar(bounds, color = "#294f9a", capWidth = 9)
  original.geomLine(aes("x", "estimate"), color = "#c23b4a", width = 3)
  original.geomPoint(aes("x", "estimate"), color = "#c23b4a", radius = 4)
  original.referenceY(3.0, label = "target")
  original.labels(title = "Before JSON", x = "sample", y = "value")
  original.applyTheme(minimalTheme())

  let payload = original.toJson(pretty = true)
  var restored = plotSerialization.fromJson(payload)
  restored.labels(title = "After JSON", x = "sample", y = "value")

  let font = loadTtf("../../tests/DejaVuSans.ttf")
  let roundTripSvgs = [
    original.compileScene(Size(width: 500, height: 320)).toSvg(font),
    restored.compileScene(Size(width: 500, height: 320)).toSvg(font)
  ]

  doAssert plotSerialization.fromJson(original.toJson).toJson == original.toJson
  echo "schema version: ", PlotSpecSchemaVersion
  echo "encoded bytes: ", payload.len

nbRawHtml gallery([
  svgFigure(roundTripSvgs[0], "Original typed PlotSpec."),
  svgFigure(roundTripSvgs[1], "Decoded schema-v1 PlotSpec.")
])

nbText: """
The changed title demonstrates that the decoded value is independent. Before
that change, encoding it again is byte-for-byte identical to the compact
original JSON.

## Data and colour fidelity

JSON has no standard spelling for IEEE NaN or infinity. Numeric columns encode
them as the explicit strings `"nan"`, `"inf"` and `"-inf"`; finite numbers
remain JSON numbers. Missing-value policies therefore behave identically after
decoding.

Colours retain their three native components, alpha and UniColor's ABI-stable
32-bit space identifier. They are not silently converted to sRGB. Ordered and
categorical palettes retain tag, intent, seed and colours. Schema v1 rejects a
semantic palette explicitly because UniColor's role map is not part of the
PlotSpec palette contract; silently dropping those roles would be data loss.

## Validation boundary

Malformed JSON, missing fields, unknown enum values, duplicate columns and
unsupported versions raise `PlotError`. Decoding reconstructs public values;
`compileScene` then performs the same semantic validation as a specification
built in Nim, including ranges, mappings, logarithmic domains and layout.

The serializer performs no file I/O. Use `writeFile(path, spec.toJson(pretty =
true))` and `fromJson(readFile(path))` when filesystem persistence is desired.
Keeping bytes separate makes the API usable in memory, over an ABI adapter or
through a future remote-rendering transport.

Next: [WGPU and validation](wgpu_errors.html).
"""

nbSave
validatePage("serialization.html", minSvg = 2)
