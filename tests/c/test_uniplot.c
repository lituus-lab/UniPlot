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
  assert(uplot_init() == UPLOT_OK);
  assert(strcmp(uplot_version(), UNIPLOT_VERSION) == 0);
  assert(uplot_abi_version() == UNIPLOT_ABI_VERSION);
  assert(uplot_plot_new(0, 240) == NULL);
  assert(uplot_add_line(NULL, x, y, 3, "#3366cc", 2.0f) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_points(NULL, x, y, 3, "#cc3333", 4.0f) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_line_styled(NULL, x, y, 3, "#3366cc", 2.0f,
                               UPLOT_LINE_DASHED) == UPLOT_ERR_ARGUMENT);
  assert(uplot_set_title(NULL, "title") == UPLOT_ERR_ARGUMENT);
  assert(uplot_render_svg(NULL, TEST_FONT, &svg, &svg_len) ==
         UPLOT_ERR_ARGUMENT);
  uplot_buffer_free(NULL, 0);
  uplot_plot_free(NULL);
  uplot_plot *plot = uplot_plot_new(320, 240);
  assert(plot != NULL);
  assert(uplot_add_line(plot, x, y, 0, "#3366cc", 2.0f) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_line(plot, x, y, SIZE_MAX, "#3366cc", 2.0f) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_line(plot, x, y, 3, "invalid", 2.0f) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_line(plot, x, y, 3, "#3366cc", -1.0f) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_line(plot, x, y, 3, "#3366cc", 2.0f) == UPLOT_OK);
  uint8_t raster_pixels[] = {255, 0, 0, 255, 0, 0, 255, 128};
  assert(uplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          0.0, 2.0, 1.0, 3.0,
                          UPLOT_RASTER_NEAREST) == UPLOT_OK);
  raster_pixels[0] = 0; /* The plot owns a copy. */
  uint8_t *raster_json = NULL;
  size_t raster_json_len = 0;
  assert(uplot_plot_to_json(plot, &raster_json, &raster_json_len) == UPLOT_OK);
  assert(contains_bytes(raster_json, raster_json_len, "/wAA/wAA/4A="));
  uplot_buffer_free(raster_json, raster_json_len);
  assert(uplot_add_raster(plot, raster_pixels, 7, 2, 1, 4, 0.0, 2.0, 1.0,
                          3.0, UPLOT_RASTER_NEAREST) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_raster(NULL, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          0.0, 2.0, 1.0, 3.0,
                          UPLOT_RASTER_NEAREST) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_raster(plot, NULL, sizeof(raster_pixels), 2, 1, 4, 0.0,
                          2.0, 1.0, 3.0, UPLOT_RASTER_NEAREST) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 0, 1, 4,
                          0.0, 2.0, 1.0, 3.0,
                          UPLOT_RASTER_NEAREST) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 2,
                          0.0, 2.0, 1.0, 3.0,
                          UPLOT_RASTER_NEAREST) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          NAN, 2.0, 1.0, 3.0,
                          UPLOT_RASTER_NEAREST) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_raster(plot, raster_pixels, sizeof(raster_pixels), 2, 1, 4,
                          0.0, 2.0, 1.0, 3.0, 99) == UPLOT_ERR_ARGUMENT);
  uint8_t mark_pixels[] = {12, 34, 56, 255};
  assert(uplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_OK);
  mark_pixels[0] = 0;
  raster_json = NULL;
  raster_json_len = 0;
  assert(uplot_plot_to_json(plot, &raster_json, &raster_json_len) == UPLOT_OK);
  assert(contains_bytes(raster_json, raster_json_len, "DCI4/w=="));
  assert(contains_bytes(raster_json, raster_json_len, "mkImage"));
  uplot_buffer_free(raster_json, raster_json_len);
  assert(uplot_add_image_mark(NULL, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, NULL, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, mark_pixels, 3, 1, 1, 4, 0.5, 1.5, 0.5,
                              1.5, UPLOT_RASTER_BILINEAR) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 0, 1, 4,
                              0.5, 1.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 2,
                              0.5, 1.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              NAN, 1.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              1.5, 0.5, 0.5, 1.5,
                              UPLOT_RASTER_BILINEAR) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_image_mark(plot, mark_pixels, sizeof(mark_pixels), 1, 1, 4,
                              0.5, 1.5, 0.5, 1.5, 99) ==
         UPLOT_ERR_ARGUMENT);
  const double gap_y[] = {1.0, NAN, 2.0};
  assert(uplot_add_line(plot, x, gap_y, 3, "#3366cc", 2.0f) == UPLOT_OK);
  assert(uplot_add_points(plot, x, y, 3, "#cc3333", 4.0f) == UPLOT_OK);
  assert(uplot_add_points(plot, x, y, 2, "#cc3333", 4.0f) == UPLOT_OK);
  assert(uplot_add_line_styled(plot, x, y, 3, "#3366cc", 2.0f,
                               UPLOT_LINE_DOT_DASH) == UPLOT_OK);
  assert(uplot_add_points_shaped(plot, x, y, 3, "#cc3333", 4.0f,
                                 UPLOT_MARKER_DIAMOND) == UPLOT_OK);
  assert(uplot_add_line_styled(plot, x, y, 3, "#3366cc", 2.0f, 999) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_points_shaped(plot, x, y, 3, "#cc3333", 4.0f, 999) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_line_configured(plot, x, y, 3, "#3366cc", 2.0f,
                                   UPLOT_LINE_SOLID, 999) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_points_configured(plot, x, y, 3, "#cc3333", 4.0f,
                                     UPLOT_MARKER_CIRCLE, 999) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_set_title(plot, "C plot") == UPLOT_OK);
  assert(uplot_set_secondary_y(plot, 1.8, 32.0, "fahrenheit") == UPLOT_OK);
  assert(uplot_set_secondary_y(plot, 0.0, 0.0, "invalid") ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_set_secondary_y(plot, 1.0, 0.0, NULL) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_annotate_text(plot, 1.0, 3.0, "peak", "#7a3db8", 14.0f) ==
         UPLOT_OK);
  assert(uplot_annotate_arrow(plot, 0.5, 1.5, 1.0, 3.0, "#d65f2d", 2.0f,
                              8.0f) == UPLOT_OK);
  assert(uplot_annotate_arrow(plot, 1.0, 1.0, 1.0, 1.0, "#d65f2d", 2.0f,
                              8.0f) == UPLOT_ERR_ARGUMENT);
  assert(uplot_render_svg(plot, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  assert(uplot_render_png(plot, TEST_FONT, &png, &png_len) == UPLOT_OK);
  assert(png_len > 8 && png[0] == 137 && png[1] == 'P');
  uplot_buffer_free(svg, svg_len);
  uplot_buffer_free(png, png_len);
  assert(uplot_clear_secondary_y(plot) == UPLOT_OK);
  assert(uplot_clear_secondary_y(NULL) == UPLOT_ERR_ARGUMENT);
  assert(uplot_set_x_axis_labels(plot, UPLOT_AXIS_UTC_DATETIME, 0) ==
         UPLOT_OK);
  assert(uplot_set_y_axis_labels(plot, UPLOT_AXIS_DURATION, 1) == UPLOT_OK);
  assert(uplot_set_x_axis_labels(NULL, UPLOT_AXIS_NUMERIC, 0) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_set_x_axis_labels(plot, 99, 0) == UPLOT_ERR_ARGUMENT);
  assert(uplot_set_y_axis_labels(plot, UPLOT_AXIS_NUMERIC, 2) ==
         UPLOT_ERR_ARGUMENT);
  uint8_t *temporal_json = NULL;
  size_t temporal_json_len = 0;
  assert(uplot_plot_to_json(plot, &temporal_json, &temporal_json_len) ==
         UPLOT_OK);
  assert(contains_bytes(temporal_json, temporal_json_len, "alkUtcDateTime"));
  assert(contains_bytes(temporal_json, temporal_json_len, "alkDuration"));
  uplot_buffer_free(temporal_json, temporal_json_len);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(plot, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  assert(uplot_set_x_axis_labels(plot, UPLOT_AXIS_NUMERIC, 0) == UPLOT_OK);
  assert(uplot_set_y_axis_labels(plot, UPLOT_AXIS_NUMERIC, 0) == UPLOT_OK);
  assert(uplot_clear_annotations(plot) == UPLOT_OK);
  assert(uplot_clear_annotations(NULL) == UPLOT_ERR_ARGUMENT);

  const char *groups[] = {"west", "east", "west"};
  const char *sides[] = {"left", "right", "right"};
  assert(uplot_add_categorical_column(plot, "group", groups, 3) == UPLOT_OK);
  assert(uplot_add_categorical_column(plot, "side", sides, 3) == UPLOT_OK);
  assert(uplot_add_categorical_column(plot, "bad", groups, 2) ==
         UPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_facet_grid_svg(plot, "group", 2, 656, 240, 16, 1, 1,
                                     TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  svg = (uint8_t *)1;
  svg_len = 1;
  assert(uplot_render_facet_grid_svg(plot, "missing", 2, 656, 240, 16, 0, 0,
                                     TEST_FONT, &svg, &svg_len) ==
         UPLOT_ERR_RENDER);
  assert(svg == NULL && svg_len == 0);
  assert(uplot_render_facet_matrix_png(plot, "group", "side", 656, 480, 16,
                                       1, 1, TEST_FONT, &png, &png_len) ==
         UPLOT_OK);
  assert(png_len > 8 && png[0] == 137 && png[1] == 'P');
  uplot_buffer_free(png, png_len);

  uplot_plot *panels[] = {plot, plot};
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_grid_svg(panels, 2, 2, 656, 240, 16, TEST_FONT,
                               &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_grid_svg_shared(panels, 2, 2, 656, 240, 16, 1, 1,
                                      TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  svg = (uint8_t *)1;
  svg_len = 1;
  assert(uplot_render_grid_svg_shared(panels, 2, 2, 656, 240, 16, 2, 0,
                                      TEST_FONT, &svg, &svg_len) ==
         UPLOT_ERR_ARGUMENT);
  assert(svg == NULL && svg_len == 0);
  svg = (uint8_t *)1;
  svg_len = 1;
  assert(uplot_render_grid_svg(NULL, 2, 2, 656, 240, 16, TEST_FONT,
                               &svg, &svg_len) == UPLOT_ERR_ARGUMENT);
  assert(svg == NULL && svg_len == 0);
  panels[1] = NULL;
  assert(uplot_render_grid_png(panels, 2, 2, 656, 240, 16, TEST_FONT,
                               &png, &png_len) == UPLOT_ERR_ARGUMENT);
  assert(png == NULL && png_len == 0);
  uplot_plot_free(plot);

  const char *json_source =
      "{\"schema\":\"org.lituus-lab.uniplot.plot-spec\",\"version\":2}";
  assert(uplot_plot_from_json(NULL, 0, 320, 240) == NULL);
  assert(uplot_plot_from_json((const uint8_t *)json_source,
                              strlen(json_source), 320, 240) == NULL);
  uplot_plot *status_plot = (uplot_plot *)1;
  assert(uplot_plot_from_json_status(NULL, 0, 320, 240, &status_plot) ==
         UPLOT_ERR_ARGUMENT);
  assert(status_plot == NULL);
  assert(uplot_plot_from_json_status((const uint8_t *)json_source,
                                     strlen(json_source), 320, 240,
                                     &status_plot) == UPLOT_ERR_ARGUMENT);
  assert(status_plot == NULL);
  assert(uplot_plot_from_json_status((const uint8_t *)json_source,
                                     strlen(json_source), 320, 240,
                                     NULL) == UPLOT_ERR_ARGUMENT);

  plot = uplot_plot_new(320, 240);
  assert(plot != NULL);
  assert(uplot_add_line(plot, x, y, 3, "#3366cc", 2.0f) == UPLOT_OK);
  uint8_t *json = NULL;
  size_t json_len = 0;
  assert(uplot_plot_to_json(NULL, &json, &json_len) == UPLOT_ERR_ARGUMENT);
  assert(uplot_plot_to_json(plot, &json, &json_len) == UPLOT_OK);
  assert(json != NULL && json_len > 0);
  uplot_plot *restored = NULL;
  assert(uplot_plot_from_json_status(json, json_len, 320, 240, &restored) ==
         UPLOT_OK);
  assert(restored != NULL);
  uint8_t *roundtrip = NULL;
  size_t roundtrip_len = 0;
  assert(uplot_plot_to_json(restored, &roundtrip, &roundtrip_len) == UPLOT_OK);
  assert(roundtrip_len == json_len);
  assert(memcmp(roundtrip, json, json_len) == 0);
  assert(uplot_add_image_mark(restored, mark_pixels, sizeof(mark_pixels),
                              1, 1, 4, 1.5, 2.5, 0.5, 1.5,
                              UPLOT_RASTER_NEAREST) == UPLOT_OK);
  assert(uplot_add_image_mark(restored, mark_pixels, sizeof(mark_pixels),
                              1, 1, 4, 2.5, 3.5, 0.5, 1.5,
                              UPLOT_RASTER_NEAREST) == UPLOT_OK);
  assert(uplot_add_line(restored, x, y, 3, "#3366cc", 2.0f) == UPLOT_OK);
  uint8_t *restored_png = NULL;
  size_t restored_png_len = 0;
  assert(uplot_render_png(restored, TEST_FONT, &restored_png,
                          &restored_png_len) == UPLOT_OK);
  assert(restored_png != NULL && restored_png_len > 8);
  uplot_buffer_free(restored_png, restored_png_len);
  uplot_buffer_free(json, json_len);
  uplot_buffer_free(roundtrip, roundtrip_len);
  uplot_plot_free(restored);
  uplot_plot_free(plot);

  uplot_plot *rejecting_plot = uplot_plot_new(320, 240);
  assert(rejecting_plot != NULL);
  assert(uplot_add_line_configured(
             rejecting_plot, x, gap_y, 3, "#3366cc", 2.0f,
             UPLOT_LINE_SOLID, UPLOT_MISSING_REJECT) == UPLOT_OK);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(rejecting_plot, TEST_FONT, &svg, &svg_len) ==
         UPLOT_ERR_RENDER);
  assert(svg == NULL && svg_len == 0);
  uplot_plot_free(rejecting_plot);

  uplot_plot *box_plot = uplot_plot_new(320, 240);
  assert(box_plot != NULL);
  const char *box_groups[] = {"a", "a", "a", "a", "a", "b", "b"};
  const char *bad_box_groups[] = {"a", NULL};
  const double box_values[] = {1, 2, 3, 4, 100, 8, 9};
  assert(uplot_add_box_plot(box_plot, bad_box_groups, box_values, 2, 1.5,
                            "#3366cc", "#cc3344") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_box_plot(box_plot, box_groups, box_values, 7, -1.0,
                            "#3366cc", "#cc3344") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_box_plot(box_plot, box_groups, box_values, 7, 1.5,
                            "invalid", "#cc3344") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_box_plot(box_plot, box_groups, box_values, 7, 1.5,
                            "#3366cc", "#cc3344") == UPLOT_OK);
  assert(uplot_add_box_plot(box_plot, box_groups, box_values, 7, 1.5,
                            "#3366cc", "#cc3344") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_box_plot(NULL, box_groups, box_values, 7, 1.5,
                            "#3366cc", "#cc3344") == UPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(box_plot, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(box_plot);

  uplot_plot *histogram = uplot_plot_new(320, 240);
  assert(histogram != NULL);
  const double histogram_values[] = {-1, 0, 0.5, 1, 2, 3, NAN};
  const double histogram_breaks[] = {0, 1, 2};
  assert(uplot_add_histogram_breaks(histogram, histogram_values, 7,
                                    histogram_breaks, 3, "#267a5e") ==
         UPLOT_OK);
  assert(uplot_add_histogram_breaks(histogram, histogram_values, 7,
                                    histogram_breaks, 3, "#267a5e") ==
         UPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(histogram, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(histogram);
  uplot_plot *invalid_histogram = uplot_plot_new(320, 240);
  assert(invalid_histogram != NULL);
  const double invalid_breaks[] = {0, 0};
  assert(uplot_add_histogram_breaks(invalid_histogram, histogram_values, 7,
                                    invalid_breaks, 2, "#267a5e") ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_histogram_breaks(NULL, histogram_values, 7,
                                    histogram_breaks, 3, "#267a5e") ==
         UPLOT_ERR_ARGUMENT);
  uplot_plot_free(invalid_histogram);

  uplot_plot *numeric_histogram = uplot_plot_new(320, 240);
  assert(numeric_histogram != NULL);
  assert(uplot_add_numeric_histogram(
           numeric_histogram, histogram_values, 7, histogram_breaks, 3, 1,
           "#267a5e") == UPLOT_OK);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(numeric_histogram, TEST_FONT, &svg, &svg_len) ==
         UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(numeric_histogram);
  uplot_plot *automatic_histogram = uplot_plot_new(320, 240);
  assert(automatic_histogram != NULL);
  assert(uplot_add_automatic_histogram(
           automatic_histogram, histogram_values, 7,
           UPLOT_HISTOGRAM_FREEDMAN_DIACONIS, 1, "#267a5e") == UPLOT_OK);
  assert(uplot_render_svg(automatic_histogram, TEST_FONT, &svg, &svg_len) ==
         UPLOT_OK);
  assert(svg_len > 100);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(automatic_histogram);

  {
    const double smooth_x[] = {1, 2, 3, 4, 5};
    const double smooth_y[] = {1.2, 1.9, 3.2, 3.9, 5.1};
    uplot_plot *smooth = uplot_plot_new(320, 240);
    assert(smooth != NULL);
    assert(uplot_add_linear_smooth(smooth, smooth_x, smooth_y, 5, 32, 0.95,
      1, "#3366cc", "#3366cc40") == UPLOT_OK);
    assert(uplot_render_svg(smooth, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
    assert(svg_len > 100);
    uplot_buffer_free(svg, svg_len);
    svg = NULL;
    uplot_plot_free(smooth);
    assert(uplot_add_linear_smooth(NULL, smooth_x, smooth_y, 5, 32, 0.95,
      1, "#3366cc", "#3366cc40") == UPLOT_ERR_ARGUMENT);
    smooth = uplot_plot_new(320, 240);
    assert(smooth != NULL);
    assert(uplot_add_linear_smooth(smooth, smooth_x, smooth_y, 5, 1, 0.95,
      1, "#3366cc", "#3366cc40") == UPLOT_ERR_ARGUMENT);
    uplot_plot_free(smooth);
  }
  {
    const double density_values[] = {-2, -1, 0, 1, 2};
    uplot_plot *density = uplot_plot_new(320, 240);
    assert(density != NULL);
    assert(uplot_add_density(density, density_values, 5, 65, 0.0,
      "#3366cc40", "#3366cc") == UPLOT_OK);
    assert(uplot_render_svg(density, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
    assert(svg_len > 100);
    uplot_buffer_free(svg, svg_len);
    svg = NULL;
    uplot_plot_free(density);
    assert(uplot_add_density(NULL, density_values, 5, 65, 0.0,
      "#3366cc40", "#3366cc") == UPLOT_ERR_ARGUMENT);
  }
  {
    const double violin_values[] = {-2, -1, 0, 1, 2};
    uplot_plot *violin = uplot_plot_new(320, 240);
    assert(violin != NULL);
    assert(uplot_add_violin(violin, violin_values, 5, 65, 0.0, 0.8,
      "#3366cc80") == UPLOT_OK);
    assert(uplot_render_svg(violin, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
    assert(svg_len > 100);
    uplot_buffer_free(svg, svg_len);
    svg = NULL;
    assert(uplot_add_violin(violin, violin_values, 5, 65, 0.0, 0.8,
      "#3366cc80") == UPLOT_ERR_ARGUMENT);
    uplot_plot_free(violin);
    assert(uplot_add_violin(NULL, violin_values, 5, 65, 0.0, 0.8,
      "#3366cc80") == UPLOT_ERR_ARGUMENT);
    violin = uplot_plot_new(320, 240);
    assert(violin != NULL);
    assert(uplot_add_violin(violin, NULL, 5, 65, 0.0, 0.8,
      "#3366cc80") == UPLOT_ERR_ARGUMENT);
    assert(uplot_add_violin(violin, violin_values, 5, 65, 0.0, 0.0,
      "#3366cc80") == UPLOT_ERR_ARGUMENT);
    uplot_plot_free(violin);
  }

  uplot_plot *invalid_automatic = uplot_plot_new(320, 240);
  assert(invalid_automatic != NULL);
  assert(uplot_add_automatic_histogram(
           invalid_automatic, histogram_values, 7, -1, 0, "#267a5e") ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_automatic_histogram(
           invalid_automatic, histogram_values, 7,
           UPLOT_HISTOGRAM_AUTO, 2, "#267a5e") == UPLOT_ERR_ARGUMENT);
  const double nonfinite_histogram[] = {NAN, INFINITY};
  assert(uplot_add_automatic_histogram(
           invalid_automatic, nonfinite_histogram, 2,
           UPLOT_HISTOGRAM_AUTO, 0, "#267a5e") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_automatic_histogram(
           invalid_automatic, NULL, 7, UPLOT_HISTOGRAM_AUTO, 0,
           "#267a5e") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_automatic_histogram(
           NULL, histogram_values, 7, UPLOT_HISTOGRAM_AUTO, 0,
           "#267a5e") == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(invalid_automatic);
  uplot_plot *configured_automatic = uplot_plot_new(320, 240);
  assert(configured_automatic != NULL);
  assert(uplot_set_title(configured_automatic, "keep") == UPLOT_OK);
  assert(uplot_add_automatic_histogram(
           configured_automatic, histogram_values, 7,
           UPLOT_HISTOGRAM_AUTO, 0, "#267a5e") == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(configured_automatic);
  uplot_plot *raster_automatic = uplot_plot_new(320, 240);
  assert(raster_automatic != NULL);
  const uint8_t recipe_raster[] = {31, 127, 223, 255};
  assert(uplot_add_raster(raster_automatic, recipe_raster,
                          sizeof(recipe_raster), 1, 1, 4, 0.0, 1.0, 0.0,
                          1.0, UPLOT_RASTER_NEAREST) == UPLOT_OK);
  assert(uplot_add_automatic_histogram(
           raster_automatic, histogram_values, 7,
           UPLOT_HISTOGRAM_AUTO, 0, "#267a5e") == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(raster_automatic);
  uplot_plot *invalid_numeric_histogram = uplot_plot_new(320, 240);
  assert(invalid_numeric_histogram != NULL);
  assert(uplot_add_numeric_histogram(
           invalid_numeric_histogram, histogram_values, 7, histogram_breaks,
           3, 2, "#267a5e") == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(invalid_numeric_histogram);

  uplot_plot *grouped = uplot_plot_new(320, 240);
  assert(grouped != NULL);
  const char *aggregate_groups[] = {"beta", "alpha", "beta", "empty"};
  const double aggregate_values[] = {1, 4, 3, NAN};
  assert(uplot_add_grouped_aggregate(grouped, aggregate_groups,
                                     aggregate_values, 4, UPLOT_AGG_MEAN,
                                     "#7a3db8") == UPLOT_OK);
  assert(uplot_add_grouped_aggregate(grouped, aggregate_groups,
                                     aggregate_values, 4, UPLOT_AGG_MEAN,
                                     "#7a3db8") == UPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(grouped, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(grouped);
  uplot_plot *invalid_grouped = uplot_plot_new(320, 240);
  assert(invalid_grouped != NULL);
  const char *invalid_groups[] = {"beta", NULL};
  const char *empty_group[] = {""};
  assert(uplot_add_grouped_aggregate(invalid_grouped, invalid_groups,
                                     aggregate_values, 2, UPLOT_AGG_MEAN,
                                     "#7a3db8") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_grouped_aggregate(invalid_grouped, aggregate_groups,
                                     aggregate_values, 4, 999,
                                     "#7a3db8") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_grouped_aggregate(invalid_grouped, empty_group,
                                     aggregate_values, 1, UPLOT_AGG_MEAN,
                                     "#7a3db8") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_grouped_aggregate(invalid_grouped, aggregate_groups,
                                     aggregate_values, 4, UPLOT_AGG_MEAN,
                                     "not-a-color") == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_grouped_aggregate(NULL, aggregate_groups, aggregate_values,
                                     4, UPLOT_AGG_MEAN,
                                     "#7a3db8") == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(invalid_grouped);

  uplot_plot *heatmap = uplot_plot_new(320, 360);
  assert(heatmap != NULL);
  const char *heat_x[] = {"left", "right", "left", "left"};
  const char *heat_y[] = {"north", "north", "south", "north"};
  const double heat_values[] = {1, 4, NAN, 3};
  assert(uplot_add_heatmap(heatmap, heat_x, heat_y, heat_values, 4,
                           UPLOT_AGG_MEAN) == UPLOT_OK);
  assert(uplot_add_heatmap(heatmap, heat_x, heat_y, heat_values, 4,
                           UPLOT_AGG_MEAN) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_heatmap(NULL, heat_x, heat_y, heat_values, 4,
                           UPLOT_AGG_MEAN) == UPLOT_ERR_ARGUMENT);
  uplot_plot *invalid_heatmap = uplot_plot_new(320, 240);
  assert(invalid_heatmap != NULL);
  const char *invalid_heat_x[] = {"left", NULL};
  assert(uplot_add_heatmap(invalid_heatmap, invalid_heat_x, heat_y,
                           heat_values, 2, UPLOT_AGG_MEAN) ==
         UPLOT_ERR_ARGUMENT);
  assert(uplot_add_heatmap(invalid_heatmap, heat_x, heat_y, heat_values, 4,
                           999) == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(invalid_heatmap);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(heatmap, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(heatmap);

  const double numeric_heat_x[] = {0, 1, 3};
  const double numeric_heat_y[] = {10, 20, 40};
  const double numeric_heat_values[] = {1, 2, 3, NAN};
  uplot_plot *numeric_heatmap = uplot_plot_new(320, 360);
  assert(numeric_heatmap != NULL);
  assert(uplot_add_numeric_heatmap(
           numeric_heatmap, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 4) == UPLOT_OK);
  assert(uplot_add_numeric_heatmap(
           numeric_heatmap, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 4) == UPLOT_ERR_ARGUMENT);
  svg = NULL;
  svg_len = 0;
  assert(uplot_render_svg(numeric_heatmap, TEST_FONT, &svg, &svg_len) ==
         UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  uplot_buffer_free(svg, svg_len);
  uplot_plot_free(numeric_heatmap);
  uplot_plot *invalid_numeric_heatmap = uplot_plot_new(320, 360);
  assert(invalid_numeric_heatmap != NULL);
  assert(uplot_add_numeric_heatmap(
           invalid_numeric_heatmap, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 3) == UPLOT_ERR_ARGUMENT);
  assert(uplot_add_numeric_heatmap(
           NULL, numeric_heat_x, 3, numeric_heat_y, 3,
           numeric_heat_values, 4) == UPLOT_ERR_ARGUMENT);
  uplot_plot_free(invalid_numeric_heatmap);
  puts("All UniPlot C ABI tests passed.");
  return 0;
}
