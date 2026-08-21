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
enum { UPLOT_OK = 0, UPLOT_ERR_ARGUMENT = 1, UPLOT_ERR_RENDER = 2,
       UPLOT_ERR_MEMORY = 3 };
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
typedef enum {
  UPLOT_AGG_COUNT = 0,
  UPLOT_AGG_SUM = 1,
  UPLOT_AGG_MEAN = 2,
  UPLOT_AGG_MINIMUM = 3,
  UPLOT_AGG_MAXIMUM = 4
} uplot_aggregation;
typedef enum {
  UPLOT_RASTER_NEAREST = 0,
  UPLOT_RASTER_BILINEAR = 1,
  UPLOT_RASTER_BOX = 2
} uplot_raster_filter;
typedef enum {
  UPLOT_AXIS_NUMERIC = 0,
  UPLOT_AXIS_UTC_DATETIME = 1,
  UPLOT_AXIS_DURATION = 2
} uplot_axis_labels;
typedef enum {
  UPLOT_SCALE_LINEAR = 0,
  UPLOT_SCALE_LOG10 = 1,
  UPLOT_SCALE_SYMLOG10 = 2
} uplot_scale_kind;
typedef enum {
  UPLOT_HISTOGRAM_AUTO = 0,
  UPLOT_HISTOGRAM_SQUARE_ROOT = 1,
  UPLOT_HISTOGRAM_STURGES = 2,
  UPLOT_HISTOGRAM_RICE = 3,
  UPLOT_HISTOGRAM_SCOTT = 4,
  UPLOT_HISTOGRAM_FREEDMAN_DIACONIS = 5
} uplot_histogram_rule;
typedef struct uplot_plot uplot_plot;

int uplot_init(void);
const char *uplot_version(void);
int uplot_abi_version(void);
uplot_plot *uplot_plot_new(int width, int height);
uplot_plot *uplot_plot_from_json(const uint8_t *, size_t, int width,
                                 int height);
/* Status-returning variant. On every failure, *out_plot is set to NULL. */
int uplot_plot_from_json_status(const uint8_t *, size_t, int width, int height,
                                uplot_plot **out_plot);
int uplot_plot_to_json(uplot_plot *, uint8_t **, size_t *);
int uplot_add_line(uplot_plot *, const double *, const double *, size_t,
                   const char *color, float width);
int uplot_add_points(uplot_plot *, const double *, const double *, size_t,
                     const char *color, float radius);
/* Pixels are copied. channels must be 1, 3, or 4 and length must equal
 * width*height*channels. The caller retains ownership of pixels. */
int uplot_add_raster(uplot_plot *, const uint8_t *pixels, size_t length,
                     int width, int height, int channels, double x_min,
                     double x_max, double y_min, double y_max, int filter);
/* Add one data mark in layer order. Pixels are copied and remain caller-owned. */
int uplot_add_image_mark(uplot_plot *, const uint8_t *pixels, size_t length,
                         int width, int height, int channels, double x_min,
                         double x_max, double y_min, double y_max, int filter);
int uplot_add_box_plot(uplot_plot *, const char *const *groups,
                       const double *values, size_t count,
                       double whisker_length, const char *color,
                       const char *outlier_color);
int uplot_add_histogram_breaks(uplot_plot *, const double *values,
                               size_t value_count, const double *breaks,
                               size_t break_count, const char *color);
int uplot_add_numeric_histogram(uplot_plot *, const double *values,
                                size_t value_count, const double *breaks,
                                size_t break_count, int density,
                                const char *color);
int uplot_add_automatic_histogram(uplot_plot *, const double *values,
                                  size_t value_count, int rule, int density,
                                  const char *color);
/* Build a retained linear fit and optional mean-confidence ribbon. Inputs are
 * copied; the caller retains ownership of both arrays. */
int uplot_add_linear_smooth(uplot_plot *, const double *x, const double *y,
                            size_t count, int point_count,
                            double confidence_level, int show_confidence,
                            const char *line_color, const char *band_color);
/* Build a retained Gaussian density area and line. bandwidth 0 selects the
 * UniStatistics automatic rule. Samples are copied and remain caller-owned. */
int uplot_add_density(uplot_plot *, const double *values, size_t count,
                      int point_count, double bandwidth,
                      const char *fill_color, const char *line_color);
/* Build one retained mirrored Gaussian density polygon. bandwidth 0 selects
 * the UniStatistics automatic rule. Samples are copied and caller-owned. */
int uplot_add_violin(uplot_plot *, const double *values, size_t count,
                     int point_count, double bandwidth, double width,
                     const char *color);
int uplot_add_grouped_violin(uplot_plot *, const char *const *groups,
                             const double *values, size_t count,
                             int point_count, double bandwidth, double width,
                             const char *color);
/* Extract retained marching-squares contours from a row-major rectilinear
 * grid. All arrays are copied and remain caller-owned. */
int uplot_add_contours(uplot_plot *, const double *x, size_t x_count,
                       const double *y, size_t y_count,
                       const double *values, size_t value_count,
                       const double *levels, size_t level_count,
                       const char *color, double width);
int uplot_add_grouped_aggregate(uplot_plot *, const char *const *groups,
                                const double *values, size_t count,
                                int aggregation, const char *color);
int uplot_add_heatmap(uplot_plot *, const char *const *xs,
                      const char *const *ys, const double *values,
                      size_t count, int aggregation);
int uplot_add_numeric_heatmap(uplot_plot *, const double *x_breaks,
                              size_t x_break_count, const double *y_breaks,
                              size_t y_break_count, const double *values,
                              size_t value_count);
int uplot_add_categorical_column(uplot_plot *, const char *name,
                                 const char *const *values, size_t count);
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
/* Temporal values remain numeric seconds. UTC means POSIX seconds since the
 * Unix epoch; duration means signed elapsed seconds. */
int uplot_set_x_axis_labels(uplot_plot *, int labels, int reversed);
int uplot_set_y_axis_labels(uplot_plot *, int labels, int reversed);
int uplot_set_x_scale(uplot_plot *, int scale, int reversed);
int uplot_set_y_scale(uplot_plot *, int scale, int reversed);
int uplot_set_secondary_y(uplot_plot *, double scale, double offset,
                          const char *label);
int uplot_clear_secondary_y(uplot_plot *);
int uplot_annotate_text(uplot_plot *, double x, double y, const char *text,
                        const char *color, float font_size);
int uplot_annotate_arrow(uplot_plot *, double x, double y, double x_end,
                         double y_end, const char *color, float width,
                         float head_size);
int uplot_clear_annotations(uplot_plot *);
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
int uplot_render_facet_grid_svg(uplot_plot *, const char *column, int columns,
                                int width, int height, int gap, int shared_x,
                                int shared_y, const char *font_path,
                                uint8_t **, size_t *);
int uplot_render_facet_grid_png(uplot_plot *, const char *column, int columns,
                                int width, int height, int gap, int shared_x,
                                int shared_y, const char *font_path,
                                uint8_t **, size_t *);
int uplot_render_facet_matrix_svg(uplot_plot *, const char *row_column,
                                  const char *column_column, int width,
                                  int height, int gap, int shared_x,
                                  int shared_y, const char *font_path,
                                  uint8_t **, size_t *);
int uplot_render_facet_matrix_png(uplot_plot *, const char *row_column,
                                  const char *column_column, int width,
                                  int height, int gap, int shared_x,
                                  int shared_y, const char *font_path,
                                  uint8_t **, size_t *);
void uplot_buffer_free(void *, size_t);
void uplot_plot_free(uplot_plot *);

#ifdef __cplusplus
}
#endif
#endif
