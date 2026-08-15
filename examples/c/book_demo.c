/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#include "UniPlot.h"
#include <stdio.h>
#include <stdlib.h>

static int write_bytes(const char *path, const uint8_t *data, size_t length) {
  FILE *stream = fopen(path, "wb");
  if (stream == NULL) return 0;
  const size_t written = fwrite(data, 1, length, stream);
  return fclose(stream) == 0 && written == length;
}

int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: book_demo FONT OUTPUT.svg OUTPUT.png\n");
    return EXIT_FAILURE;
  }
  const double x[] = {0, 1, 2, 3, 4, 5};
  const double y[] = {1.0, 2.8, 2.1, 4.2, 3.4, 5.0};
  uint8_t *svg = NULL;
  uint8_t *png = NULL;
  uint8_t *json = NULL;
  size_t svg_length = 0;
  size_t png_length = 0;
  size_t json_length = 0;
  int result = EXIT_FAILURE;

  if (uplot_init() != UPLOT_OK) return EXIT_FAILURE;
  uplot_plot *plot = uplot_plot_new(800, 500);
  uplot_plot *second = NULL;
  if (plot == NULL) return EXIT_FAILURE;
  if (uplot_add_line_styled(plot, x, y, 6, "#2457c5", 2.5f,
                            UPLOT_LINE_DOT_DASH) != UPLOT_OK ||
      uplot_add_points_shaped(plot, x + 1, y + 1, 4, "#d64255", 5.0f,
                              UPLOT_MARKER_DIAMOND) != UPLOT_OK ||
      uplot_set_title(plot, "Rendered through the UniPlot C ABI") != UPLOT_OK)
    goto cleanup;
  if (uplot_plot_to_json(plot, &json, &json_length) != UPLOT_OK) goto cleanup;
  uplot_plot *restored = uplot_plot_from_json(json, json_length, 800, 500);
  if (restored == NULL) goto cleanup;
  uplot_plot_free(plot);
  plot = restored;
  second = uplot_plot_new(800, 500);
  if (second == NULL ||
      uplot_add_points_shaped(second, x, y, 6, "#267a5e", 6.0f,
                              UPLOT_MARKER_CROSS) != UPLOT_OK ||
      uplot_set_title(second, "Second C ABI panel") != UPLOT_OK)
    goto cleanup;
  uplot_plot *panels[] = {plot, second};
  if (uplot_render_grid_svg_shared(panels, 2, 2, 1000, 420, 16, 1, 1,
                                   argv[1], &svg, &svg_length) != UPLOT_OK ||
      uplot_render_grid_png_shared(panels, 2, 2, 1000, 420, 16, 1, 1,
                                   argv[1], &png, &png_length) != UPLOT_OK)
    goto cleanup;
  if (!write_bytes(argv[2], svg, svg_length) ||
      !write_bytes(argv[3], png, png_length))
    goto cleanup;
  result = EXIT_SUCCESS;

cleanup:
  uplot_buffer_free(svg, svg_length);
  uplot_buffer_free(png, png_length);
  uplot_buffer_free(json, json_length);
  uplot_plot_free(second);
  uplot_plot_free(plot);
  return result;
}
