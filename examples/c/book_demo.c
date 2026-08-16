/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#include "UniPlot.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static int write_bytes(const char *path, const uint8_t *data, size_t length) {
  FILE *stream = fopen(path, "wb");
  if (stream == NULL) return 0;
  const size_t written = fwrite(data, 1, length, stream);
  return fclose(stream) == 0 && written == length;
}

int main(int argc, char **argv) {
  if (argc != 18) {
    fprintf(stderr, "usage: book_demo FONT MATRIX.svg MATRIX.png BOX.svg "
                    "BOX.png HEAT.svg HEAT.png HIST.svg HIST.png "
                    "GROUPED.svg GROUPED.png NUMHEAT.svg NUMHEAT.png "
                    "IMAGE.svg IMAGE.png TIME.svg TIME.png\n");
    return EXIT_FAILURE;
  }
  const double x[] = {0, 1, 2, 3, 4, 5};
  const double y[] = {1.0, 2.8, 2.1, 4.2, 3.4, 5.0};
  const char *groups[] = {"west", "west", "west", "east", "east", "east"};
  const char *phases[] = {"early", "late", "late", "late", "late", "late"};
  uint8_t *svg = NULL;
  uint8_t *png = NULL;
  uint8_t *json = NULL;
  uint8_t *box_svg = NULL;
  uint8_t *box_png = NULL;
  uint8_t *heat_svg = NULL;
  uint8_t *heat_png = NULL;
  uint8_t *histogram_svg = NULL;
  uint8_t *histogram_png = NULL;
  uint8_t *grouped_svg = NULL;
  uint8_t *grouped_png = NULL;
  uint8_t *numeric_heat_svg = NULL;
  uint8_t *numeric_heat_png = NULL;
  uint8_t *image_svg = NULL;
  uint8_t *image_png = NULL;
  uint8_t *temporal_svg = NULL;
  uint8_t *temporal_png = NULL;
  size_t svg_length = 0;
  size_t png_length = 0;
  size_t json_length = 0;
  size_t box_svg_length = 0;
  size_t box_png_length = 0;
  size_t heat_svg_length = 0;
  size_t heat_png_length = 0;
  size_t histogram_svg_length = 0;
  size_t histogram_png_length = 0;
  size_t grouped_svg_length = 0;
  size_t grouped_png_length = 0;
  size_t numeric_heat_svg_length = 0;
  size_t numeric_heat_png_length = 0;
  size_t image_svg_length = 0;
  size_t image_png_length = 0;
  size_t temporal_svg_length = 0;
  size_t temporal_png_length = 0;
  uplot_plot *heatmap = NULL;
  uplot_plot *histogram = NULL;
  uplot_plot *grouped = NULL;
  uplot_plot *numeric_heatmap = NULL;
  uplot_plot *image_plot = NULL;
  uplot_plot *temporal_plot = NULL;
  int result = EXIT_FAILURE;

  if (uplot_init() != UPLOT_OK) return EXIT_FAILURE;
  uplot_plot *plot = uplot_plot_new(800, 500);
  if (plot == NULL) return EXIT_FAILURE;
  if (uplot_add_line_styled(plot, x, y, 6, "#2457c5", 2.5f,
                            UPLOT_LINE_DOT_DASH) != UPLOT_OK ||
      uplot_add_points_shaped(plot, x + 1, y + 1, 4, "#d64255", 5.0f,
                              UPLOT_MARKER_DIAMOND) != UPLOT_OK ||
      uplot_set_title(plot, "C") != UPLOT_OK ||
      uplot_set_secondary_y(plot, 1.8, 32.0, "F") != UPLOT_OK ||
      uplot_annotate_text(plot, 3.15, 4.65, "peak", "#7a3db8", 13.0f) !=
        UPLOT_OK ||
      uplot_annotate_arrow(plot, 3.75, 4.55, 3.0, 4.2, "#7a3db8", 2.0f,
                           8.0f) != UPLOT_OK)
    goto cleanup;
  if (uplot_plot_to_json(plot, &json, &json_length) != UPLOT_OK) goto cleanup;
  uplot_plot *restored = uplot_plot_from_json(json, json_length, 800, 500);
  if (restored == NULL) goto cleanup;
  uplot_plot_free(plot);
  plot = restored;
  if (uplot_add_categorical_column(plot, "region", groups, 6) != UPLOT_OK)
    goto cleanup;
  if (uplot_add_categorical_column(plot, "phase", phases, 6) != UPLOT_OK)
    goto cleanup;
  if (uplot_render_facet_matrix_svg(plot, "region", "phase", 1000, 700, 16,
                                    1, 1, argv[1], &svg,
                                    &svg_length) != UPLOT_OK ||
      uplot_render_facet_matrix_png(plot, "region", "phase", 1000, 700, 16,
                                    1, 1, argv[1], &png,
                                    &png_length) != UPLOT_OK)
    goto cleanup;
  if (!write_bytes(argv[2], svg, svg_length) ||
      !write_bytes(argv[3], png, png_length))
    goto cleanup;
  const char *box_groups[] = {"control", "control", "control", "control",
                              "control", "treated", "treated", "treated",
                              "treated", "treated"};
  const double box_values[] = {1.0, 1.4, 1.8, 2.1, 5.2,
                               2.0, 2.4, 2.7, 3.0, 3.3};
  uplot_plot *boxes = uplot_plot_new(760, 440);
  if (boxes == NULL ||
      uplot_add_box_plot(boxes, box_groups, box_values, 10, 1.5,
                         "#267a5e", "#d64255") != UPLOT_OK ||
      uplot_set_title(boxes, "C grouped boxplot") != UPLOT_OK ||
      uplot_render_svg(boxes, argv[1], &box_svg, &box_svg_length) != UPLOT_OK ||
      uplot_render_png(boxes, argv[1], &box_png, &box_png_length) != UPLOT_OK ||
      !write_bytes(argv[4], box_svg, box_svg_length) ||
      !write_bytes(argv[5], box_png, box_png_length)) {
    uplot_plot_free(boxes);
    goto cleanup;
  }
  uplot_plot_free(boxes);
  const char *heat_x[] = {"morning", "morning", "afternoon", "evening",
                          "evening"};
  const char *heat_y[] = {"north", "north", "north", "north", "south"};
  const double heat_values[] = {2.0, 4.0, 7.0, 5.0, 9.0};
  heatmap = uplot_plot_new(760, 440);
  if (heatmap == NULL ||
      uplot_add_heatmap(heatmap, heat_x, heat_y, heat_values, 5,
                        UPLOT_AGG_MEAN) != UPLOT_OK ||
      uplot_set_title(heatmap, "C categorical heatmap") != UPLOT_OK ||
      uplot_render_svg(heatmap, argv[1], &heat_svg, &heat_svg_length) !=
        UPLOT_OK ||
      uplot_render_png(heatmap, argv[1], &heat_png, &heat_png_length) !=
        UPLOT_OK ||
      !write_bytes(argv[6], heat_svg, heat_svg_length) ||
      !write_bytes(argv[7], heat_png, heat_png_length))
    goto cleanup;
  const double histogram_values[] = {-1.0, 0.0, 0.3, 0.9, 1.0,
                                     1.4, 2.0, 3.0};
  histogram = uplot_plot_new(760, 440);
  if (histogram == NULL ||
      uplot_add_automatic_histogram(
        histogram, histogram_values, 8,
        UPLOT_HISTOGRAM_FREEDMAN_DIACONIS, 1, "#267a5e") != UPLOT_OK ||
      uplot_set_title(histogram, "C automatic FD density") != UPLOT_OK ||
      uplot_render_svg(histogram, argv[1], &histogram_svg,
                       &histogram_svg_length) != UPLOT_OK ||
      uplot_render_png(histogram, argv[1], &histogram_png,
                       &histogram_png_length) != UPLOT_OK ||
      !write_bytes(argv[8], histogram_svg, histogram_svg_length) ||
      !write_bytes(argv[9], histogram_png, histogram_png_length))
    goto cleanup;
  const char *aggregate_groups[] = {"beta", "alpha", "beta", "empty",
                                    "alpha"};
  const double aggregate_values[] = {1.0, 4.0, 3.0, NAN, 8.0};
  grouped = uplot_plot_new(760, 440);
  if (grouped == NULL ||
      uplot_add_grouped_aggregate(grouped, aggregate_groups,
                                  aggregate_values, 5, UPLOT_AGG_MEAN,
                                  "#9b4d96") != UPLOT_OK ||
      uplot_set_title(grouped, "C grouped mean") != UPLOT_OK ||
      uplot_render_svg(grouped, argv[1], &grouped_svg,
                       &grouped_svg_length) != UPLOT_OK ||
      uplot_render_png(grouped, argv[1], &grouped_png,
                       &grouped_png_length) != UPLOT_OK ||
      !write_bytes(argv[10], grouped_svg, grouped_svg_length) ||
      !write_bytes(argv[11], grouped_png, grouped_png_length))
    goto cleanup;
  const double numeric_heat_x[] = {0.0, 1.0, 3.0, 6.0};
  const double numeric_heat_y[] = {10.0, 20.0, 40.0};
  const double numeric_heat_values[] = {1.0, 4.0, 2.0, 6.0, NAN, 9.0};
  numeric_heatmap = uplot_plot_new(760, 440);
  if (numeric_heatmap == NULL ||
      uplot_add_numeric_heatmap(numeric_heatmap, numeric_heat_x, 4,
                                numeric_heat_y, 3, numeric_heat_values, 6) !=
        UPLOT_OK ||
      uplot_set_title(numeric_heatmap, "C numeric cell grid") != UPLOT_OK ||
      uplot_render_svg(numeric_heatmap, argv[1], &numeric_heat_svg,
                       &numeric_heat_svg_length) != UPLOT_OK ||
      uplot_render_png(numeric_heatmap, argv[1], &numeric_heat_png,
                       &numeric_heat_png_length) != UPLOT_OK ||
      !write_bytes(argv[12], numeric_heat_svg, numeric_heat_svg_length) ||
      !write_bytes(argv[13], numeric_heat_png, numeric_heat_png_length))
    goto cleanup;
  const uint8_t image_pixels[] = {
      245, 100, 70, 255, 255, 190, 70, 220,
      190, 45, 80, 220, 255, 235, 150, 255};
  image_plot = uplot_plot_new(760, 440);
  if (image_plot == NULL ||
      uplot_add_image_mark(image_plot, image_pixels, sizeof(image_pixels),
                           2, 2, 4, 0.5, 2.5, 0.5, 2.5,
                           UPLOT_RASTER_NEAREST) != UPLOT_OK ||
      uplot_set_title(image_plot, "C data-mapped image mark") != UPLOT_OK ||
      uplot_render_svg(image_plot, argv[1], &image_svg,
                       &image_svg_length) != UPLOT_OK ||
      uplot_render_png(image_plot, argv[1], &image_png,
                       &image_png_length) != UPLOT_OK ||
      !write_bytes(argv[14], image_svg, image_svg_length) ||
      !write_bytes(argv[15], image_png, image_png_length))
    goto cleanup;
  const double temporal_x[] = {1704067200.0, 1704067260.0, 1704067320.0,
                               1704067380.0, 1704067440.0};
  const double temporal_y[] = {0.0, 42.0, 75.0, 130.0, 190.0};
  temporal_plot = uplot_plot_new(760, 440);
  if (temporal_plot == NULL ||
      uplot_add_line(temporal_plot, temporal_x, temporal_y, 5, "#2457c5",
                     2.5f) != UPLOT_OK ||
      uplot_set_x_axis_labels(temporal_plot, UPLOT_AXIS_UTC_DATETIME, 0) !=
        UPLOT_OK ||
      uplot_set_y_axis_labels(temporal_plot, UPLOT_AXIS_DURATION, 0) !=
        UPLOT_OK ||
      uplot_set_title(temporal_plot, "C UTC and duration axes") != UPLOT_OK ||
      uplot_render_svg(temporal_plot, argv[1], &temporal_svg,
                       &temporal_svg_length) != UPLOT_OK ||
      uplot_render_png(temporal_plot, argv[1], &temporal_png,
                       &temporal_png_length) != UPLOT_OK ||
      !write_bytes(argv[16], temporal_svg, temporal_svg_length) ||
      !write_bytes(argv[17], temporal_png, temporal_png_length))
    goto cleanup;
  result = EXIT_SUCCESS;

cleanup:
  uplot_buffer_free(svg, svg_length);
  uplot_buffer_free(png, png_length);
  uplot_buffer_free(json, json_length);
  uplot_buffer_free(box_svg, box_svg_length);
  uplot_buffer_free(box_png, box_png_length);
  uplot_buffer_free(heat_svg, heat_svg_length);
  uplot_buffer_free(heat_png, heat_png_length);
  uplot_buffer_free(histogram_svg, histogram_svg_length);
  uplot_buffer_free(histogram_png, histogram_png_length);
  uplot_buffer_free(grouped_svg, grouped_svg_length);
  uplot_buffer_free(grouped_png, grouped_png_length);
  uplot_buffer_free(numeric_heat_svg, numeric_heat_svg_length);
  uplot_buffer_free(numeric_heat_png, numeric_heat_png_length);
  uplot_buffer_free(image_svg, image_svg_length);
  uplot_buffer_free(image_png, image_png_length);
  uplot_buffer_free(temporal_svg, temporal_svg_length);
  uplot_buffer_free(temporal_png, temporal_png_length);
  uplot_plot_free(heatmap);
  uplot_plot_free(histogram);
  uplot_plot_free(grouped);
  uplot_plot_free(numeric_heatmap);
  uplot_plot_free(image_plot);
  uplot_plot_free(temporal_plot);
  uplot_plot_free(plot);
  return result;
}
