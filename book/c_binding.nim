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
  (`0` or `1`) and derive common numeric domains. The original entry points
  remain ABI-compatible aliases for two false flags.
- `uplot_plot_to_json` returns the complete schema-v1 `PlotSpec`; the same
  ownership rule applies to its byte buffer. `uplot_plot_from_json` accepts
  explicit output dimensions and returns null for malformed or unsupported
  documents.
- Caller-owned input arrays only need to remain valid for the duration of the
  add call; UniPlot copies them into its specification.
- Status is `UPLOT_OK`, `UPLOT_ERR_ARGUMENT` or `UPLOT_ERR_RENDER`.
- A null pointer, zero-sized series, length mismatch, invalid colour or invalid
  dimensions is an argument error rather than undefined behaviour.
- `uplot_add_line_styled` accepts the five `UPLOT_LINE_*` values;
  `uplot_add_points_shaped` accepts the six `UPLOT_MARKER_*` values. Invalid
  enum integers are rejected before conversion to Nim enums.
- `uplot_add_line_configured` and `uplot_add_points_configured` additionally
  accept `UPLOT_MISSING_DROP`, `UPLOT_MISSING_BREAK` or
  `UPLOT_MISSING_REJECT`. Existing line entry points break at non-finite values;
  existing point entry points drop them.
- Series may have different lengths. The rectangular internal frame is padded
  with `NaN`, then each layer's missing-value policy resolves those absent rows.

## ABI compatibility

`UNIPLOT_VERSION`, `uplot_version()` and `uplot_abi_version()` expose library
compatibility. `UNIPLOT_ABI_VERSION` is 1. Adding functions may preserve this
version; changing an existing signature or ownership rule may not.

The direct C builders deliberately remain narrower than the Nim grammar: line
and point series, their UniVector styles and titles are the stable 1.0
construction primitives. The versioned JSON bridge transports the complete
valid Nim `PlotSpec`, including layers, mappings, references, scales, themes
and palettes, without duplicating the grammar in C. The original solid-line
and circle-point functions remain ABI-compatible convenience entry points.

Next: [Python binding](python_binding.html).
"""

let
  cSvg = readFile("../assets/generated/c_binding.svg")
  cPng = pngDataUri(readFile("../assets/generated/c_binding.png"))
nbRawHtml gallery([
  svgFigure(cSvg, "Two-panel SVG produced through the C grid ABI."),
  pngFigure(cPng, "The same C handles composed into a PNG grid.",
    "Two plot panels rendered through the UniPlot C ABI")
])

nbSave
validatePage("c_binding.html", minSvg = 1, requirePng = true)
