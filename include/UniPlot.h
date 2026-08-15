/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#ifndef UNIPLOT_H
#define UNIPLOT_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

#define UNIPLOT_VERSION "1.0.0"
#define UNIPLOT_ABI_VERSION 1
enum { UPLOT_OK = 0, UPLOT_ERR_ARGUMENT = 1, UPLOT_ERR_RENDER = 2 };
typedef enum {
  UPLOT_LINE_SOLID = 0,
  UPLOT_LINE_DASHED = 1,
  UPLOT_LINE_DOTTED = 2,
  UPLOT_LINE_DOT_DASH = 3,
  UPLOT_LINE_LONG_DASH = 4
} uplot_line_style;
typedef enum {
  UPLOT_MARKER_CIRCLE = 0,
  UPLOT_MARKER_SQUARE = 1,
  UPLOT_MARKER_TRIANGLE = 2,
  UPLOT_MARKER_DIAMOND = 3,
  UPLOT_MARKER_PLUS = 4,
  UPLOT_MARKER_CROSS = 5
} uplot_marker_shape;
typedef enum {
  UPLOT_MISSING_DROP = 0,
  UPLOT_MISSING_BREAK = 1,
  UPLOT_MISSING_REJECT = 2
} uplot_missing_policy;
typedef struct uplot_plot uplot_plot;

int uplot_init(void);
const char *uplot_version(void);
int uplot_abi_version(void);
uplot_plot *uplot_plot_new(int width, int height);
uplot_plot *uplot_plot_from_json(const uint8_t *, size_t, int width,
                                 int height);
int uplot_plot_to_json(uplot_plot *, uint8_t **, size_t *);
int uplot_add_line(uplot_plot *, const double *, const double *, size_t,
                   const char *color, float width);
int uplot_add_points(uplot_plot *, const double *, const double *, size_t,
                     const char *color, float radius);
int uplot_add_line_styled(uplot_plot *, const double *, const double *, size_t,
                          const char *color, float width, int line_style);
int uplot_add_points_shaped(uplot_plot *, const double *, const double *,
                            size_t, const char *color, float radius, int shape);
int uplot_add_line_configured(uplot_plot *, const double *, const double *,
                              size_t, const char *color, float width,
                              int line_style, int missing_policy);
int uplot_add_points_configured(uplot_plot *, const double *, const double *,
                                size_t, const char *color, float radius,
                                int shape, int missing_policy);
int uplot_set_title(uplot_plot *, const char *title);
int uplot_render_png(uplot_plot *, const char *font_path, uint8_t **, size_t *);
int uplot_render_svg(uplot_plot *, const char *font_path, uint8_t **, size_t *);
int uplot_render_grid_svg(uplot_plot *const *, size_t count, int columns,
                          int width, int height, int gap,
                          const char *font_path, uint8_t **, size_t *);
int uplot_render_grid_png(uplot_plot *const *, size_t count, int columns,
                          int width, int height, int gap,
                          const char *font_path, uint8_t **, size_t *);
int uplot_render_grid_svg_shared(uplot_plot *const *, size_t count, int columns,
                                 int width, int height, int gap, int shared_x,
                                 int shared_y, const char *font_path,
                                 uint8_t **, size_t *);
int uplot_render_grid_png_shared(uplot_plot *const *, size_t count, int columns,
                                 int width, int height, int gap, int shared_x,
                                 int shared_y, const char *font_path,
                                 uint8_t **, size_t *);
void uplot_buffer_free(void *, size_t);
void uplot_plot_free(uplot_plot *);

#ifdef __cplusplus
}
#endif
#endif
