# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# C binding

UniPlot exposes a versioned C ABI for native consumers. The stable public
header is `include/UniPlot.h`; no Nim runtime types cross the boundary.

The figures below are committed outputs of `examples/c/book_demo.c`, rendered
through that ABI. Regenerate both C and Python evidence with
`nimble bindingBookDemos`.

## Build

```bash
nimble clib        # libUniPlot.so / libUniPlot.dylib / libUniPlot.dll
nimble clibStatic  # libUniPlot.a
nimble ctest       # compile and run the ABI tests
nimble cexample    # compile the C consumer example
```

Windows CPython builds use the dedicated MSVC task and `UniPlot.lib`.

## Complete line-and-point example

```c
#include "UniPlot.h"
#include <stdio.h>

int main(void) {
  double x[] = {0, 1, 2};
  double y[] = {1, 3, 2};
  uint8_t *bytes = NULL;
  size_t length = 0;

  if (uplot_init() != UPLOT_OK) return 1;
  uplot_plot *plot = uplot_plot_new(800, 500);
  if (plot == NULL) return 1;

  uplot_add_line_styled(plot, x, y, 3, "#3366cc", 2.0f,
                        UPLOT_LINE_DOT_DASH);
  uplot_add_points_shaped(plot, x, y, 3, "#cc3344", 4.0f,
                          UPLOT_MARKER_DIAMOND);
  uplot_set_title(plot, "Measurements");

  uint8_t *json = NULL;
  size_t json_length = 0;
  uplot_plot_to_json(plot, &json, &json_length);
  uplot_plot *restored = uplot_plot_from_json(
    json, json_length, 800, 500);
  uplot_buffer_free(json, json_length);
  uplot_plot_free(plot);
  plot = restored;

  uplot_plot *panels[] = {plot, restored};
  int status = uplot_render_grid_svg_shared(
    panels, 2, 2, 1000, 420, 16, 1, 1,
    "DejaVuSans.ttf", &bytes, &length);
  if (status == UPLOT_OK) {
    fwrite(bytes, 1, length, stdout);
    uplot_buffer_free(bytes, length);
  }
  uplot_plot_free(plot);
  return status;
}
```

## Ownership and errors

- `uplot_plot_new` returns an opaque owned handle; release it with
  `uplot_plot_free`.
- SVG and PNG renderers allocate byte buffers; release them with
  `uplot_buffer_free` using the returned length.
- `uplot_render_grid_svg` and `uplot_render_grid_png` accept a borrowed array
  of non-null plot handles, an explicit row-major column count, canvas size
  and pixel gap. They do not take ownership of the handles.
- The additive `_shared` variants take `shared_x` and `shared_y` integer flags
  (`0` or `1`) and derive common numeric domains or categorical x order. The
  original entry points
  remain ABI-compatible aliases for two false flags.
- `uplot_add_categorical_column` copies a complete string column into the
  retained frame. `uplot_render_facet_grid_svg` and its PNG counterpart split
  one handle by that column; their flags follow the same shared-domain
  contract as plot grids.
- `uplot_render_facet_matrix_svg` and its PNG counterpart take distinct row
  and column fields. They retain the full Cartesian layout and render absent
  combinations as labelled empty panels.
- `uplot_plot_to_json` returns the complete schema-v1 `PlotSpec`; the same
  ownership rule applies to its byte buffer. `uplot_plot_from_json` accepts
  explicit output dimensions and returns null for malformed or unsupported
  documents.
- Caller-owned input arrays only need to remain valid for the duration of the
  add call; UniPlot copies them into its specification.
- Status is `UPLOT_OK`, `UPLOT_ERR_ARGUMENT`, `UPLOT_ERR_RENDER` or
  `UPLOT_ERR_MEMORY`.
- A null pointer, zero-sized series, length mismatch, invalid colour or invalid
  dimensions is an argument error rather than undefined behaviour.
- `uplot_add_line_styled` accepts the five `UPLOT_LINE_*` values;
  `uplot_add_points_shaped` accepts the six `UPLOT_MARKER_*` values. Invalid
  enum integers are rejected before conversion to Nim enums.
- `uplot_add_line_configured` and `uplot_add_points_configured` additionally
  accept `UPLOT_MISSING_DROP`, `UPLOT_MISSING_BREAK` or
  `UPLOT_MISSING_REJECT`. Existing line entry points break at non-finite values;
  existing point entry points drop them.
- `uplot_set_secondary_y(scale, offset, label)` adds the same affine right-side
  guide as Nim; `uplot_clear_secondary_y` removes it.
- `uplot_annotate_text` and `uplot_annotate_arrow` retain plain annotations in
  numeric data coordinates; `uplot_clear_annotations` removes them. They are
  included in schema-v1 JSON and therefore survive the C round trip shown
  above.
- `uplot_add_box_plot` computes type-7 quartiles and Tukey whiskers from copied
  grouped samples. It requires an otherwise empty handle, making replacement
  semantics explicit; malformed groups, colours or whisker lengths are
  argument errors.
- `uplot_add_heatmap` copies aligned categorical x/y/value arrays and accepts
  `UPLOT_AGG_COUNT`, `SUM`, `MEAN`, `MINIMUM` or `MAXIMUM`. It also requires an
  otherwise empty handle. First-seen axis order and missing Cartesian cells
  follow the Nim `aggregate2D` contract.
- `uplot_add_numeric_heatmap` copies explicit x/y boundary arrays and a
  row-major value matrix. The value count must equal the Cartesian cell count;
  finite values become variable-size numeric UniVector rectangles.
- `uplot_add_histogram_breaks` copies samples and finite, strictly increasing
  boundaries into a categorical histogram on an empty handle. Values outside
  the supplied domain are excluded and the final boundary is included. Bars
  have equal screen width even when numeric intervals differ.
- `uplot_add_numeric_histogram` uses the same validated breaks as numeric
  data-coordinate rectangles. Its `density` flag is exactly `0` or `1`; the
  latter normalises rectangle area to one for a non-empty in-domain sample.
- `uplot_add_automatic_histogram` selects equal-width numeric bins with one of
  the `UPLOT_HISTOGRAM_*` rules. The generated C figure uses
  Freedman–Diaconis density and therefore exercises the real ABI entry point.
- `uplot_add_linear_smooth` copies aligned x/y arrays and materialises a
  UniStatistics linear fit plus an optional mean-confidence ribbon on an empty
  handle. Point count, confidence level, flags and colours are validated before
  publication.
- `uplot_add_density` copies samples and materialises a Gaussian density area
  plus outline. Bandwidth zero selects the UniStatistics automatic rule.
- `uplot_add_violin` copies samples and materialises the same estimate as one
  mirrored retained polygon with an explicit positive width.
- `uplot_add_grouped_aggregate` copies aligned group/value arrays, preserves
  first-seen groups and supports the five `UPLOT_AGG_*` operations. Non-finite
  observations are excluded and the builder requires an empty handle.
- Series may have different lengths. The rectangular internal frame is padded
  with `NaN`, then each layer's missing-value policy resolves those absent rows.

## ABI compatibility

`UNIPLOT_VERSION`, `uplot_version()` and `uplot_abi_version()` expose library
compatibility. `UNIPLOT_ABI_VERSION` is 1. Adding functions may preserve this
version; changing an existing signature or ownership rule may not.

The direct C builders include numeric/categorical plots and retained rasters.
`uplot_add_raster` copies a caller-owned packed Gray/RGB/RGBA8 buffer and
positions it with numeric extents; `UPLOT_RASTER_NEAREST`, `BILINEAR` and `BOX`
select UniImage filtering. `uplot_add_image_mark` uses the same copied input
contract but inserts the image in ordinary data-layer order rather than behind
the guides. The versioned JSON bridge transports the complete
valid Nim `PlotSpec`, including layers, mappings, references, scales, themes
palettes, rasters and image resources, without duplicating the grammar in C.
The original solid-line and circle-point functions remain ABI-compatible
convenience entry points.

`uplot_set_x_axis_labels` and `uplot_set_y_axis_labels` accept
`UPLOT_AXIS_NUMERIC`, `UPLOT_AXIS_UTC_DATETIME` or `UPLOT_AXIS_DURATION`, plus
an exact `0`/`1` reversal flag. Temporal inputs remain ordinary `double`
seconds, so the ABI owns no calendar structure and never uses the host locale.

Next: [Python binding](python_binding.html).
"""

let
  cSvg = readFile("../assets/generated/c_binding.svg")
  cPng = pngDataUri(readFile("../assets/generated/c_binding.png"))
  cBoxSvg = readFile("../assets/generated/c_boxplot.svg")
  cBoxPng = pngDataUri(readFile("../assets/generated/c_boxplot.png"))
  cHeatSvg = readFile("../assets/generated/c_heatmap.svg")
  cHeatPng = pngDataUri(readFile("../assets/generated/c_heatmap.png"))
  cHistogramSvg = readFile("../assets/generated/c_histogram.svg")
  cHistogramPng = pngDataUri(readFile("../assets/generated/c_histogram.png"))
  cGroupedSvg = readFile("../assets/generated/c_grouped.svg")
  cGroupedPng = pngDataUri(readFile("../assets/generated/c_grouped.png"))
  cNumericHeatSvg = readFile("../assets/generated/c_numeric_heatmap.svg")
  cNumericHeatPng = pngDataUri(
    readFile("../assets/generated/c_numeric_heatmap.png"))
  cImageSvg = readFile("../assets/generated/c_image_mark.svg")
  cImagePng = pngDataUri(readFile("../assets/generated/c_image_mark.png"))
  cTemporalSvg = readFile("../assets/generated/c_temporal.svg")
  cTemporalPng = pngDataUri(readFile("../assets/generated/c_temporal.png"))
nbRawHtml gallery([
  svgFigure(cSvg, "An annotated two-dimensional facet matrix produced through the C ABI."),
  pngFigure(cPng, "The same matrix, including its empty cell, as PNG.",
    "A categorical facet matrix rendered through the UniPlot C ABI"),
  svgFigure(cBoxSvg, "A grouped boxplot built and rendered through the C ABI."),
  pngFigure(cBoxPng, "The same C boxplot as an embedded PNG.",
    "A grouped boxplot rendered through the UniPlot C ABI"),
  svgFigure(cHeatSvg, "A categorical heatmap built through `uplot_add_heatmap`."),
  pngFigure(cHeatPng, "The same C heatmap as an embedded PNG.",
    "A categorical heatmap rendered through the UniPlot C ABI"),
  svgFigure(cHistogramSvg,
    "A variable-width probability density built through the C ABI."),
  pngFigure(cHistogramPng, "The same C density as an embedded PNG.",
    "A numeric histogram density rendered through the UniPlot C ABI"),
  svgFigure(cGroupedSvg,
    "First-seen grouped means built through `uplot_add_grouped_aggregate`."),
  pngFigure(cGroupedPng, "The same grouped aggregate as an embedded PNG.",
    "Grouped means rendered through the UniPlot C ABI"),
  svgFigure(cNumericHeatSvg,
    "A variable-size numeric cell grid built through the C ABI."),
  pngFigure(cNumericHeatPng,
    "The same C numeric heatmap as an embedded PNG.",
    "A numeric heatmap rendered through the UniPlot C ABI"),
  svgFigure(cImageSvg,
    "A copied RGBA resource inserted with `uplot_add_image_mark`."),
  pngFigure(cImagePng, "The same C image mark as an embedded PNG.",
    "A data-mapped image mark rendered through the UniPlot C ABI"),
  svgFigure(cTemporalSvg,
    "UTC and duration guides configured through the additive C ABI."),
  pngFigure(cTemporalPng, "The same temporal C plot as an embedded PNG.",
    "UTC and duration axes rendered through the UniPlot C ABI")
])

nbSave
validatePage("c_binding.html", minSvg = 6, requirePng = true)
