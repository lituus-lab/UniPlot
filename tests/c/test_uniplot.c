/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#include "UniPlot.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#ifndef TEST_FONT
#define TEST_FONT "../DejaVuSans.ttf"
#endif
static int contains_bytes(const uint8_t *haystack, size_t haystack_len,
                          const char *needle) {
  const size_t needle_len = strlen(needle);
  if (needle_len > haystack_len) return 0;
  for (size_t i = 0; i <= haystack_len - needle_len; ++i) {
    if (memcmp(haystack + i, needle, needle_len) == 0) return 1;
  }
  return 0;
}
int main(void) {
  const double x[] = {0.0, 1.0, 2.0}, y[] = {1.0, 3.0, 2.0};
  uint8_t *svg = NULL, *png = NULL;
  size_t svg_len = 0, png_len = 0;
  assert(uniplot_init() == UNIPLOT_OK);
  assert(strcmp(uniplot_version(), UNIPLOT_VERSION) == 0);
  assert(uniplot_abi_version() == UNIPLOT_ABI_VERSION);
  assert(uniplot_plot_new(0, 240) == NULL);
  assert(uniplot_add_line(NULL, x, y, 3, "#3366cc", 2.0f) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_points(NULL, x, y, 3, "#cc3333", 4.0f) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_line_styled(NULL, x, y, 3, "#3366cc", 2.0f,
                               UNIPLOT_LINE_DASHED) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_title(NULL, "title") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_render_svg(NULL, TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_ERR_ARGUMENT);
  uniplot_buffer_free(NULL, 0);
  uniplot_plot_free(NULL);
  uniplot_plot *plot = uniplot_plot_new(320, 240);
  assert(plot != NULL);
  assert(uniplot_add_line(plot, x, y, 0, "#3366cc", 2.0f) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_line(plot, x, y, SIZE_MAX, "#3366cc", 2.0f) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_line(plot, x, y, 3, "invalid", 2.0f) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_line(plot, x, y, 3, "#3366cc", -1.0f) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_line(plot, x, y, 3, "#3366cc", 2.0f) == UNIPLOT_OK);
  uint8_t raster_pixels[] = {255, 0, 0, 255, 0, 0, 255, 128};
  assert(uniplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          0.0, 2.0, 1.0, 3.0,
                          UNIPLOT_RASTER_NEAREST) == UNIPLOT_OK);
  raster_pixels[0] = 0; /* The plot owns a copy. */
  uint8_t *raster_json = NULL;
  size_t raster_json_len = 0;
  assert(uniplot_plot_to_json(plot, &raster_json, &raster_json_len) == UNIPLOT_OK);
  assert(contains_bytes(raster_json, raster_json_len, "/wAA/wAA/4A="));
  uniplot_buffer_free(raster_json, raster_json_len);
  assert(uniplot_add_raster(plot, raster_pixels, 7, 2, 1, 4, 0.0, 2.0, 1.0,
                          3.0, UNIPLOT_RASTER_NEAREST) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_raster(NULL, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          0.0, 2.0, 1.0, 3.0,
                          UNIPLOT_RASTER_NEAREST) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_raster(plot, NULL, sizeof(raster_pixels), 2, 1, 4, 0.0,
                          2.0, 1.0, 3.0, UNIPLOT_RASTER_NEAREST) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 0, 1, 4,
                          0.0, 2.0, 1.0, 3.0,
                          UNIPLOT_RASTER_NEAREST) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 2,
                          0.0, 2.0, 1.0, 3.0,
                          UNIPLOT_RASTER_NEAREST) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          NAN, 2.0, 1.0, 3.0,
                          UNIPLOT_RASTER_NEAREST) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          0.0, 2.0, 1.0, 3.0, 99) == UNIPLOT_ERR_ARGUMENT);
  uint8_t mark_pixels[] = {12, 34, 56, 255};
  assert(uniplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_OK);
  mark_pixels[0] = 0;
  raster_json = NULL;
  raster_json_len = 0;
  assert(uniplot_plot_to_json(plot, &raster_json, &raster_json_len) == UNIPLOT_OK);
  assert(contains_bytes(raster_json, raster_json_len, "DCI4/w=="));
  assert(contains_bytes(raster_json, raster_json_len, "mkImage"));
  uniplot_buffer_free(raster_json, raster_json_len);
  assert(uniplot_add_image_mark(NULL, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, NULL, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, mark_pixels, 3, 1, 1, 4, 0.5, 1.5, 0.5,
                              1.5, UNIPLOT_RASTER_BILINEAR) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 0, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 2,
                              0.5, 1.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              NAN, 1.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              1.5, 0.5, 0.5, 1.5,
                              UNIPLOT_RASTER_BILINEAR) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5, 99) ==
         UNIPLOT_ERR_ARGUMENT);
  const double gap_y[] = {1.0, NAN, 2.0};
  assert(uniplot_add_line(plot, x, gap_y, 3, "#3366cc", 2.0f) == UNIPLOT_OK);
  assert(uniplot_add_points(plot, x, y, 3, "#cc3333", 4.0f) == UNIPLOT_OK);
  assert(uniplot_add_points(plot, x, y, 2, "#cc3333", 4.0f) == UNIPLOT_OK);
  assert(uniplot_add_line_styled(plot, x, y, 3, "#3366cc", 2.0f,
                               UNIPLOT_LINE_DOT_DASH) == UNIPLOT_OK);
  assert(uniplot_add_points_shaped(plot, x, y, 3, "#cc3333", 4.0f,
                                 UNIPLOT_MARKER_DIAMOND) == UNIPLOT_OK);
  assert(uniplot_add_line_styled(plot, x, y, 3, "#3366cc", 2.0f, 999) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_points_shaped(plot, x, y, 3, "#cc3333", 4.0f, 999) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_line_configured(plot, x, y, 3, "#3366cc", 2.0f,
                                   UNIPLOT_LINE_SOLID, 999) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_points_configured(plot, x, y, 3, "#cc3333", 4.0f,
                                     UNIPLOT_MARKER_CIRCLE, 999) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_title(plot, "C plot") == UNIPLOT_OK);
  assert(uniplot_set_secondary_y(plot, 1.8, 32.0, "fahrenheit") == UNIPLOT_OK);
  assert(uniplot_set_secondary_y(plot, 0.0, 0.0, "invalid") ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_secondary_y(plot, 1.0, 0.0, NULL) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_annotate_text(plot, 1.0, 3.0, "peak", "#7a3db8", 14.0f) ==
         UNIPLOT_OK);
  assert(uniplot_annotate_arrow(plot, 0.5, 1.5, 1.0, 3.0, "#d65f2d", 2.0f,
                              8.0f) == UNIPLOT_OK);
  assert(uniplot_annotate_arrow(plot, 1.0, 1.0, 1.0, 1.0, "#d65f2d", 2.0f,
                              8.0f) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_render_svg(plot, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  assert(uniplot_render_png(plot, TEST_FONT, &png, &png_len) == UNIPLOT_OK);
  assert(png_len > 8 && png[0] == 137 && png[1] == 'P');
  uniplot_buffer_free(svg, svg_len);
  uniplot_buffer_free(png, png_len);
  assert(uniplot_clear_secondary_y(plot) == UNIPLOT_OK);
  assert(uniplot_clear_secondary_y(NULL) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_x_axis_labels(plot, UNIPLOT_AXIS_UTC_DATETIME, 0) ==
         UNIPLOT_OK);
  assert(uniplot_set_y_axis_labels(plot, UNIPLOT_AXIS_DURATION, 1) == UNIPLOT_OK);
  assert(uniplot_set_x_axis_labels(NULL, UNIPLOT_AXIS_NUMERIC, 0) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_x_axis_labels(plot, 99, 0) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_y_axis_labels(plot, UNIPLOT_AXIS_NUMERIC, 2) ==
         UNIPLOT_ERR_ARGUMENT);
  uint8_t *temporal_json = NULL;
  size_t temporal_json_len = 0;
  assert(uniplot_plot_to_json(plot, &temporal_json, &temporal_json_len) ==
         UNIPLOT_OK);
  assert(contains_bytes(temporal_json, temporal_json_len, "alkUtcDateTime"));
  assert(contains_bytes(temporal_json, temporal_json_len, "alkDuration"));
  uniplot_buffer_free(temporal_json, temporal_json_len);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(plot, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  assert(uniplot_set_x_axis_labels(plot, UNIPLOT_AXIS_NUMERIC, 0) == UNIPLOT_OK);
  assert(uniplot_set_y_axis_labels(plot, UNIPLOT_AXIS_NUMERIC, 0) == UNIPLOT_OK);
  assert(uniplot_set_x_scale(plot, UNIPLOT_SCALE_SYMLOG10, 0) == UNIPLOT_OK);
  assert(uniplot_set_y_scale(plot, UNIPLOT_SCALE_SYMLOG10, 1) == UNIPLOT_OK);
  assert(uniplot_set_x_power_scale(plot, 0.5, 1) == UNIPLOT_OK);
  assert(uniplot_set_y_power_scale(plot, 2.0, 0) == UNIPLOT_OK);
  assert(uniplot_set_x_power_scale(plot, 0.0, 0) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_y_power_scale(NULL, 2.0, 0) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_x_scale(NULL, UNIPLOT_SCALE_LINEAR, 0) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_x_scale(plot, 99, 0) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_y_scale(plot, UNIPLOT_SCALE_LINEAR, 2) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_x_scale(plot, UNIPLOT_SCALE_LINEAR, 0) == UNIPLOT_OK);
  assert(uniplot_set_y_scale(plot, UNIPLOT_SCALE_LINEAR, 0) == UNIPLOT_OK);
  assert(uniplot_set_coordinates(plot, UNIPLOT_COORD_POLAR) == UNIPLOT_OK);
  uint8_t *polar_json = NULL;
  size_t polar_json_len = 0;
  assert(uniplot_plot_to_json(plot, &polar_json, &polar_json_len) == UNIPLOT_OK);
  assert(contains_bytes(polar_json, polar_json_len, "PolarCoordinates"));
  uniplot_buffer_free(polar_json, polar_json_len);
  assert(uniplot_set_coordinates(plot, 99) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_coordinates(NULL, UNIPLOT_COORD_POLAR) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_set_coordinates(plot, UNIPLOT_COORD_CARTESIAN) == UNIPLOT_OK);
  assert(uniplot_clear_annotations(plot) == UNIPLOT_OK);
  assert(uniplot_clear_annotations(NULL) == UNIPLOT_ERR_ARGUMENT);

  const char *groups[] = {"west", "east", "west"};
  const char *sides[] = {"left", "right", "right"};
  assert(uniplot_add_categorical_column(plot, "group", groups, 3) == UNIPLOT_OK);
  assert(uniplot_add_categorical_column(plot, "side", sides, 3) == UNIPLOT_OK);
  assert(uniplot_add_categorical_column(plot, "bad", groups, 2) ==
         UNIPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_facet_grid_svg(plot, "group", 2, 656, 240, 16, 1, 1,
                                     TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  svg = (uint8_t *)1;
  svg_len = 1;
  assert(uniplot_render_facet_grid_svg(plot, "missing", 2, 656, 240, 16, 0, 0,
                                     TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_ERR_RENDER);
  assert(svg == NULL && svg_len == 0);
  assert(uniplot_render_facet_matrix_png(plot, "group", "side", 656, 480, 16,
                                       1, 1, TEST_FONT, &png, &png_len) ==
         UNIPLOT_OK);
  assert(png_len > 8 && png[0] == 137 && png[1] == 'P');
  uniplot_buffer_free(png, png_len);

  uniplot_plot *panels[] = {plot, plot};
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_grid_svg(panels, 2, 2, 656, 240, 16, TEST_FONT,
                               &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_grid_svg_shared(panels, 2, 2, 656, 240, 16, 1, 1,
                                      TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  svg = (uint8_t *)1;
  svg_len = 1;
  assert(uniplot_render_grid_svg_shared(panels, 2, 2, 656, 240, 16, 2, 0,
                                      TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(svg == NULL && svg_len == 0);
  svg = (uint8_t *)1;
  svg_len = 1;
  assert(uniplot_render_grid_svg(NULL, 2, 2, 656, 240, 16, TEST_FONT,
                               &svg, &svg_len) == UNIPLOT_ERR_ARGUMENT);
  assert(svg == NULL && svg_len == 0);
  panels[1] = NULL;
  assert(uniplot_render_grid_png(panels, 2, 2, 656, 240, 16, TEST_FONT,
                               &png, &png_len) == UNIPLOT_ERR_ARGUMENT);
  assert(png == NULL && png_len == 0);
  uniplot_plot_free(plot);

  const char *json_source =
      "{\"schema\":\"org.lituus-lab.uniplot.plot-spec\",\"version\":2}";
  assert(uniplot_plot_from_json(NULL, 0, 320, 240) == NULL);
  assert(uniplot_plot_from_json((const uint8_t *)json_source,
                              strlen(json_source), 320, 240) == NULL);
  uniplot_plot *status_plot = (uniplot_plot *)1;
  assert(uniplot_plot_from_json_status(NULL, 0, 320, 240, &status_plot) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(status_plot == NULL);
  assert(uniplot_plot_from_json_status((const uint8_t *)json_source,
                                     strlen(json_source), 320, 240,
                                     &status_plot) == UNIPLOT_ERR_ARGUMENT);
  assert(status_plot == NULL);
  assert(uniplot_plot_from_json_status((const uint8_t *)json_source,
                                     strlen(json_source), 320, 240,
                                     NULL) == UNIPLOT_ERR_ARGUMENT);

  plot = uniplot_plot_new(320, 240);
  assert(plot != NULL);
  assert(uniplot_add_line(plot, x, y, 3, "#3366cc", 2.0f) == UNIPLOT_OK);
  uint8_t *json = NULL;
  size_t json_len = 0;
  assert(uniplot_plot_to_json(NULL, &json, &json_len) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_plot_to_json(plot, &json, &json_len) == UNIPLOT_OK);
  assert(json != NULL && json_len > 0);
  uniplot_plot *restored = NULL;
  assert(uniplot_plot_from_json_status(json, json_len, 320, 240, &restored) ==
         UNIPLOT_OK);
  assert(restored != NULL);
  uint8_t *roundtrip = NULL;
  size_t roundtrip_len = 0;
  assert(uniplot_plot_to_json(restored, &roundtrip, &roundtrip_len) == UNIPLOT_OK);
  assert(roundtrip_len == json_len);
  assert(memcmp(roundtrip, json, json_len) == 0);
  assert(uniplot_add_image_mark(restored, mark_pixels, sizeof(mark_pixels),
                              1, 1, 4, 1.5, 2.5, 0.5, 1.5,
                              UNIPLOT_RASTER_NEAREST) == UNIPLOT_OK);
  assert(uniplot_add_image_mark(restored, mark_pixels, sizeof(mark_pixels),
                              1, 1, 4, 2.5, 3.5, 0.5, 1.5,
                              UNIPLOT_RASTER_NEAREST) == UNIPLOT_OK);
  assert(uniplot_add_line(restored, x, y, 3, "#3366cc", 2.0f) == UNIPLOT_OK);
  uint8_t *restored_png = NULL;
  size_t restored_png_len = 0;
  assert(uniplot_render_png(restored, TEST_FONT, &restored_png,
                          &restored_png_len) == UNIPLOT_OK);
  assert(restored_png != NULL && restored_png_len > 8);
  uniplot_buffer_free(restored_png, restored_png_len);
  uniplot_buffer_free(json, json_len);
  uniplot_buffer_free(roundtrip, roundtrip_len);
  uniplot_plot_free(restored);
  uniplot_plot_free(plot);

  uniplot_plot *rejecting_plot = uniplot_plot_new(320, 240);
  assert(rejecting_plot != NULL);
  assert(uniplot_add_line_configured(
             rejecting_plot, x, gap_y, 3, "#3366cc", 2.0f,
             UNIPLOT_LINE_SOLID, UNIPLOT_MISSING_REJECT) == UNIPLOT_OK);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(rejecting_plot, TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_ERR_RENDER);
  assert(svg == NULL && svg_len == 0);
  uniplot_plot_free(rejecting_plot);

  uniplot_plot *box_plot = uniplot_plot_new(320, 240);
  assert(box_plot != NULL);
  const char *box_groups[] = {"a", "a", "a", "a", "a", "b", "b"};
  const char *bad_box_groups[] = {"a", NULL};
  const double box_values[] = {1, 2, 3, 4, 100, 8, 9};
  assert(uniplot_add_box_plot(box_plot, bad_box_groups, box_values, 2, 1.5,
                            "#3366cc", "#cc3344") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_box_plot(box_plot, box_groups, box_values, 7, -1.0,
                            "#3366cc", "#cc3344") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_box_plot(box_plot, box_groups, box_values, 7, 1.5,
                            "invalid", "#cc3344") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_box_plot(box_plot, box_groups, box_values, 7, 1.5,
                            "#3366cc", "#cc3344") == UNIPLOT_OK);
  assert(uniplot_add_box_plot(box_plot, box_groups, box_values, 7, 1.5,
                            "#3366cc", "#cc3344") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_box_plot(NULL, box_groups, box_values, 7, 1.5,
                            "#3366cc", "#cc3344") == UNIPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(box_plot, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(box_plot);

  uniplot_plot *histogram = uniplot_plot_new(320, 240);
  assert(histogram != NULL);
  const double histogram_values[] = {-1, 0, 0.5, 1, 2, 3, NAN};
  const double histogram_breaks[] = {0, 1, 2};
  assert(uniplot_add_histogram_breaks(histogram, histogram_values, 7,
                                    histogram_breaks, 3, "#267a5e") ==
         UNIPLOT_OK);
  assert(uniplot_add_histogram_breaks(histogram, histogram_values, 7,
                                    histogram_breaks, 3, "#267a5e") ==
         UNIPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(histogram, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(histogram);
  uniplot_plot *invalid_histogram = uniplot_plot_new(320, 240);
  assert(invalid_histogram != NULL);
  const double invalid_breaks[] = {0, 0};
  assert(uniplot_add_histogram_breaks(invalid_histogram, histogram_values, 7,
                                    invalid_breaks, 2, "#267a5e") ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_histogram_breaks(NULL, histogram_values, 7,
                                    histogram_breaks, 3, "#267a5e") ==
         UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(invalid_histogram);

  uniplot_plot *numeric_histogram = uniplot_plot_new(320, 240);
  assert(numeric_histogram != NULL);
  assert(uniplot_add_numeric_histogram(
           numeric_histogram, histogram_values, 7, histogram_breaks, 3, 1,
           "#267a5e") == UNIPLOT_OK);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(numeric_histogram, TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(numeric_histogram);
  uniplot_plot *automatic_histogram = uniplot_plot_new(320, 240);
  assert(automatic_histogram != NULL);
  assert(uniplot_add_automatic_histogram(
           automatic_histogram, histogram_values, 7,
           UNIPLOT_HISTOGRAM_FREEDMAN_DIACONIS, 1, "#267a5e") == UNIPLOT_OK);
  assert(uniplot_render_svg(automatic_histogram, TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_OK);
  assert(svg_len > 100);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(automatic_histogram);

  {
    const double smooth_x[] = {1, 2, 3, 4, 5};
    const double smooth_y[] = {1.2, 1.9, 3.2, 3.9, 5.1};
    uniplot_plot *smooth = uniplot_plot_new(320, 240);
    assert(smooth != NULL);
    assert(uniplot_add_linear_smooth(smooth, smooth_x, smooth_y, 5, 32, 0.95,
      1, "#3366cc", "#3366cc40") == UNIPLOT_OK);
    assert(uniplot_render_svg(smooth, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    uniplot_plot_free(smooth);
    assert(uniplot_add_linear_smooth(NULL, smooth_x, smooth_y, 5, 32, 0.95,
      1, "#3366cc", "#3366cc40") == UNIPLOT_ERR_ARGUMENT);
    smooth = uniplot_plot_new(320, 240);
    assert(smooth != NULL);
    assert(uniplot_add_linear_smooth(smooth, smooth_x, smooth_y, 5, 1, 0.95,
      1, "#3366cc", "#3366cc40") == UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(smooth);

    const double nonlinear_y[] = {9, 2, 1, 6, 17};
    const double nonlinear_x[] = {-2, -1, 0, 1, 2};
    smooth = uniplot_plot_new(320, 240);
    assert(smooth != NULL);
    assert(uniplot_add_polynomial_smooth(smooth, nonlinear_x, nonlinear_y, 5,
      2, 32, "#3366cc") == UNIPLOT_OK);
    assert(uniplot_render_svg(smooth, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    uniplot_plot_free(smooth);
    assert(uniplot_add_polynomial_smooth(NULL, nonlinear_x, nonlinear_y, 5,
      2, 32, "#3366cc") == UNIPLOT_ERR_ARGUMENT);
  }
  {
    const double density_values[] = {-2, -1, 0, 1, 2};
    uniplot_plot *density = uniplot_plot_new(320, 240);
    assert(density != NULL);
    assert(uniplot_add_density(density, density_values, 5, 65, 0.0,
      "#3366cc40", "#3366cc") == UNIPLOT_OK);
    assert(uniplot_render_svg(density, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    uniplot_plot_free(density);
    assert(uniplot_add_density(NULL, density_values, 5, 65, 0.0,
      "#3366cc40", "#3366cc") == UNIPLOT_ERR_ARGUMENT);
  }
  {
    const double violin_values[] = {-2, -1, 0, 1, 2};
    uniplot_plot *violin = uniplot_plot_new(320, 240);
    assert(violin != NULL);
    assert(uniplot_add_violin(violin, violin_values, 5, 65, 0.0, 0.8,
      "#3366cc80") == UNIPLOT_OK);
    assert(uniplot_render_svg(violin, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    assert(uniplot_add_violin(violin, violin_values, 5, 65, 0.0, 0.8,
      "#3366cc80") == UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(violin);
    assert(uniplot_add_violin(NULL, violin_values, 5, 65, 0.0, 0.8,
      "#3366cc80") == UNIPLOT_ERR_ARGUMENT);
    violin = uniplot_plot_new(320, 240);
    assert(violin != NULL);
    assert(uniplot_add_violin(violin, NULL, 5, 65, 0.0, 0.8,
      "#3366cc80") == UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_violin(violin, violin_values, 5, 65, 0.0, 0.0,
      "#3366cc80") == UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(violin);
  }
  {
    const char *violin_groups[] = {"beta", "alpha", "beta", "alpha",
                                    "beta", "alpha"};
    const double violin_values[] = {-1, 2, 0, 3, 1, 4};
    uniplot_plot *violin = uniplot_plot_new(320, 240);
    assert(violin != NULL);
    assert(uniplot_add_grouped_violin(violin, violin_groups, violin_values, 6,
      33, 0.0, 0.8, "#3366cc80") == UNIPLOT_OK);
    assert(uniplot_render_svg(violin, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    uniplot_plot_free(violin);
    assert(uniplot_add_grouped_violin(NULL, violin_groups, violin_values, 6,
      33, 0.0, 0.8, "#3366cc80") == UNIPLOT_ERR_ARGUMENT);
    violin = uniplot_plot_new(320, 240);
    assert(violin != NULL);
    assert(uniplot_add_grouped_violin(violin, violin_groups, violin_values, 6,
      33, 0.0, 1.1, "#3366cc80") == UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(violin);
  }
  {
    const double contour_x[] = {0, 1};
    const double contour_y[] = {0, 1};
    const double contour_values[] = {0, 1, 1, 2};
    const double contour_levels[] = {0.5, 1.5};
    const double unordered_x[] = {1, 0};
    const double outside_level[] = {3};
    uniplot_plot *contour = uniplot_plot_new(320, 240);
    assert(contour != NULL);
    assert(uniplot_add_contours(contour, contour_x, 2, contour_y, 2,
      contour_values, 4, contour_levels, 2, "#3366cc", 2.0) == UNIPLOT_OK);
    assert(uniplot_render_svg(contour, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    assert(uniplot_add_contours(contour, contour_x, 2, contour_y, 2,
      contour_values, 4, contour_levels, 2, "#3366cc", 2.0) ==
      UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(contour);
    contour = uniplot_plot_new(320, 240);
    assert(contour != NULL);
    assert(uniplot_add_contours(contour, NULL, 2, contour_y, 2,
      contour_values, 4, contour_levels, 2, "#3366cc", 2.0) ==
      UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_contours(contour, contour_x, 2, contour_y, 2,
      contour_values, 3, contour_levels, 2, "#3366cc", 2.0) ==
      UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_contours(contour, unordered_x, 2, contour_y, 2,
      contour_values, 4, contour_levels, 2, "#3366cc", 2.0) ==
      UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_contours(contour, contour_x, 2, contour_y, 2,
      contour_values, 4, outside_level, 1, "#3366cc", 2.0) ==
      UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(contour);
  }
  {
    const double heat_values[] = {-1, 0, 1, NAN};
    const double missing_heat[] = {NAN};
    uniplot_plot *heat = uniplot_plot_new(320, 240);
    assert(heat != NULL);
    assert(uniplot_add_raster_heatmap(heat, 2, 2, heat_values, 4,
      0.0, 2.0, 10.0, 20.0, UNIPLOT_RASTER_NEAREST) == UNIPLOT_OK);
    assert(uniplot_render_svg(heat, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
    assert(svg_len > 100);
    uniplot_buffer_free(svg, svg_len);
    svg = NULL;
    assert(uniplot_add_raster_heatmap(heat, 2, 2, heat_values, 4,
      0.0, 2.0, 10.0, 20.0, UNIPLOT_RASTER_NEAREST) ==
      UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(heat);
    heat = uniplot_plot_new(320, 240);
    assert(heat != NULL);
    assert(uniplot_add_raster_heatmap(heat, 2, 2, NULL, 4,
      0.0, 2.0, 10.0, 20.0, UNIPLOT_RASTER_NEAREST) ==
      UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_raster_heatmap(heat, 2, 2, heat_values, 3,
      0.0, 2.0, 10.0, 20.0, UNIPLOT_RASTER_NEAREST) ==
      UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_raster_heatmap(heat, 1, 1, missing_heat, 1,
      0.0, 1.0, 0.0, 1.0, UNIPLOT_RASTER_NEAREST) ==
      UNIPLOT_ERR_ARGUMENT);
    assert(uniplot_add_raster_heatmap(heat, 2, 2, heat_values, 4,
      0.0, 2.0, 10.0, 20.0, 99) == UNIPLOT_ERR_ARGUMENT);
    uniplot_plot_free(heat);
  }

  uniplot_plot *invalid_automatic = uniplot_plot_new(320, 240);
  assert(invalid_automatic != NULL);
  assert(uniplot_add_automatic_histogram(
           invalid_automatic, histogram_values, 7, -1, 0, "#267a5e") ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_automatic_histogram(
           invalid_automatic, histogram_values, 7,
           UNIPLOT_HISTOGRAM_AUTO, 2, "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  const double nonfinite_histogram[] = {NAN, INFINITY};
  assert(uniplot_add_automatic_histogram(
           invalid_automatic, nonfinite_histogram, 2,
           UNIPLOT_HISTOGRAM_AUTO, 0, "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_automatic_histogram(
           invalid_automatic, NULL, 7, UNIPLOT_HISTOGRAM_AUTO, 0,
           "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_automatic_histogram(
           NULL, histogram_values, 7, UNIPLOT_HISTOGRAM_AUTO, 0,
           "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(invalid_automatic);
  uniplot_plot *configured_automatic = uniplot_plot_new(320, 240);
  assert(configured_automatic != NULL);
  assert(uniplot_set_title(configured_automatic, "keep") == UNIPLOT_OK);
  assert(uniplot_add_automatic_histogram(
           configured_automatic, histogram_values, 7,
           UNIPLOT_HISTOGRAM_AUTO, 0, "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(configured_automatic);
  uniplot_plot *raster_automatic = uniplot_plot_new(320, 240);
  assert(raster_automatic != NULL);
  const uint8_t recipe_raster[] = {31, 127, 223, 255};
  assert(uniplot_add_raster(raster_automatic, recipe_raster,
                          sizeof(recipe_raster), 1, 1, 4, 0.0, 1.0, 0.0,
                          1.0, UNIPLOT_RASTER_NEAREST) == UNIPLOT_OK);
  assert(uniplot_add_automatic_histogram(
           raster_automatic, histogram_values, 7,
           UNIPLOT_HISTOGRAM_AUTO, 0, "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(raster_automatic);
  uniplot_plot *invalid_numeric_histogram = uniplot_plot_new(320, 240);
  assert(invalid_numeric_histogram != NULL);
  assert(uniplot_add_numeric_histogram(
           invalid_numeric_histogram, histogram_values, 7, histogram_breaks,
           3, 2, "#267a5e") == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(invalid_numeric_histogram);

  uniplot_plot *grouped = uniplot_plot_new(320, 240);
  assert(grouped != NULL);
  const char *aggregate_groups[] = {"beta", "alpha", "beta", "empty"};
  const double aggregate_values[] = {1, 4, 3, NAN};
  assert(uniplot_add_grouped_aggregate(grouped, aggregate_groups,
                                     aggregate_values, 4, UNIPLOT_AGG_MEAN,
                                     "#7a3db8") == UNIPLOT_OK);
  assert(uniplot_add_grouped_aggregate(grouped, aggregate_groups,
                                     aggregate_values, 4, UNIPLOT_AGG_MEAN,
                                     "#7a3db8") == UNIPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(grouped, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(grouped);
  uniplot_plot *invalid_grouped = uniplot_plot_new(320, 240);
  assert(invalid_grouped != NULL);
  const char *invalid_groups[] = {"beta", NULL};
  const char *empty_group[] = {""};
  assert(uniplot_add_grouped_aggregate(invalid_grouped, invalid_groups,
                                     aggregate_values, 2, UNIPLOT_AGG_MEAN,
                                     "#7a3db8") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_grouped_aggregate(invalid_grouped, aggregate_groups,
                                     aggregate_values, 4, 999,
                                     "#7a3db8") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_grouped_aggregate(invalid_grouped, empty_group,
                                     aggregate_values, 1, UNIPLOT_AGG_MEAN,
                                     "#7a3db8") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_grouped_aggregate(invalid_grouped, aggregate_groups,
                                     aggregate_values, 4, UNIPLOT_AGG_MEAN,
                                     "not-a-color") == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_grouped_aggregate(NULL, aggregate_groups, aggregate_values,
                                     4, UNIPLOT_AGG_MEAN,
                                     "#7a3db8") == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(invalid_grouped);

  uniplot_plot *heatmap = uniplot_plot_new(320, 360);
  assert(heatmap != NULL);
  const char *heat_x[] = {"left", "right", "left", "left"};
  const char *heat_y[] = {"north", "north", "south", "north"};
  const double heat_values[] = {1, 4, NAN, 3};
  assert(uniplot_add_heatmap(heatmap, heat_x, heat_y, heat_values, 4,
                           UNIPLOT_AGG_MEAN) == UNIPLOT_OK);
  assert(uniplot_add_heatmap(heatmap, heat_x, heat_y, heat_values, 4,
                           UNIPLOT_AGG_MEAN) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_heatmap(NULL, heat_x, heat_y, heat_values, 4,
                           UNIPLOT_AGG_MEAN) == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot *invalid_heatmap = uniplot_plot_new(320, 240);
  assert(invalid_heatmap != NULL);
  const char *invalid_heat_x[] = {"left", NULL};
  assert(uniplot_add_heatmap(invalid_heatmap, invalid_heat_x, heat_y,
                           heat_values, 2, UNIPLOT_AGG_MEAN) ==
         UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_heatmap(invalid_heatmap, heat_x, heat_y, heat_values, 4,
                           999) == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(invalid_heatmap);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(heatmap, TEST_FONT, &svg, &svg_len) == UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(heatmap);

  const double numeric_heat_x[] = {0, 1, 3};
  const double numeric_heat_y[] = {10, 20, 40};
  const double numeric_heat_values[] = {1, 2, 3, NAN};
  uniplot_plot *numeric_heatmap = uniplot_plot_new(320, 360);
  assert(numeric_heatmap != NULL);
  assert(uniplot_add_numeric_heatmap(
           numeric_heatmap, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 4) == UNIPLOT_OK);
  assert(uniplot_add_numeric_heatmap(
           numeric_heatmap, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 4) == UNIPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uniplot_render_svg(numeric_heatmap, TEST_FONT, &svg, &svg_len) ==
         UNIPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uniplot_buffer_free(svg, svg_len);
  uniplot_plot_free(numeric_heatmap);
  uniplot_plot *invalid_numeric_heatmap = uniplot_plot_new(320, 360);
  assert(invalid_numeric_heatmap != NULL);
  assert(uniplot_add_numeric_heatmap(
           invalid_numeric_heatmap, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 3) == UNIPLOT_ERR_ARGUMENT);
  assert(uniplot_add_numeric_heatmap(
           NULL, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 4) == UNIPLOT_ERR_ARGUMENT);
  uniplot_plot_free(invalid_numeric_heatmap);
  puts("All UniPlot C ABI tests passed.");
  return 0;
}
