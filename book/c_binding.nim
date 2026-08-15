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

  uplot_add_line(plot, x, y, 3, "#3366cc", 2.0f);
  uplot_add_points(plot, x, y, 3, "#cc3344", 4.0f);
  uplot_set_title(plot, "Measurements");

  int status = uplot_render_svg(
    plot, "DejaVuSans.ttf", &bytes, &length);
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
- Caller-owned input arrays only need to remain valid for the duration of the
  add call; UniPlot copies them into its specification.
- Status is `UPLOT_OK`, `UPLOT_ERR_ARGUMENT` or `UPLOT_ERR_RENDER`.
- A null pointer, zero-sized series, length mismatch, invalid colour or invalid
  dimensions is an argument error rather than undefined behaviour.

## ABI compatibility

`UNIPLOT_VERSION`, `uplot_version()` and `uplot_abi_version()` expose library
compatibility. `UNIPLOT_ABI_VERSION` is 1. Adding functions may preserve this
version; changing an existing signature or ownership rule may not.

The C surface deliberately remains narrower than the Nim grammar: lines,
points, titles and SVG/PNG are the stable 1.0 primitives.

Next: [Python binding](python_binding.html).
"""

nbSave
validatePage("c_binding.html")
