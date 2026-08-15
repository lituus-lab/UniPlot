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
  assert(uplot_render_svg(plot, TEST_FONT, &svg, &svg_len) == UPLOT_OK);
  assert(svg_len > 4 && memcmp(svg, "<svg", 4) == 0);
  assert(uplot_render_png(plot, TEST_FONT, &png, &png_len) == UPLOT_OK);
  assert(png_len > 8 && png[0] == 137 && png[1] == 'P');
  uplot_buffer_free(svg, svg_len);
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

  plot = uplot_plot_new(320, 240);
  assert(plot != NULL);
  assert(uplot_add_line(plot, x, y, 3, "#3366cc", 2.0f) == UPLOT_OK);
  uint8_t *json = NULL;
  size_t json_len = 0;
  assert(uplot_plot_to_json(NULL, &json, &json_len) == UPLOT_ERR_ARGUMENT);
  assert(uplot_plot_to_json(plot, &json, &json_len) == UPLOT_OK);
  assert(json != NULL && json_len > 0);
  uplot_plot *restored = uplot_plot_from_json(json, json_len, 320, 240);
  assert(restored != NULL);
  uint8_t *roundtrip = NULL;
  size_t roundtrip_len = 0;
  assert(uplot_plot_to_json(restored, &roundtrip, &roundtrip_len) == UPLOT_OK);
  assert(roundtrip_len == json_len);
  assert(memcmp(roundtrip, json, json_len) == 0);
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
  puts("All UniPlot C ABI tests passed.");
  return 0;
}
