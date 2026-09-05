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
enum { UNIPLOT_OK = 0, UNIPLOT_ERR_ARGUMENT = 1, UNIPLOT_ERR_RENDER = 2,
       UNIPLOT_ERR_MEMORY = 3 };
typedef enum {
  UNIPLOT_LINE_SOLID = 0,
  UNIPLOT_LINE_DASHED = 1,
  UNIPLOT_LINE_DOTTED = 2,
  UNIPLOT_LINE_DOT_DASH = 3,
  UNIPLOT_LINE_LONG_DASH = 4
} uniplot_line_style;
typedef enum {
  UNIPLOT_MARKER_CIRCLE = 0,
  UNIPLOT_MARKER_SQUARE = 1,
  UNIPLOT_MARKER_TRIANGLE = 2,
  UNIPLOT_MARKER_DIAMOND = 3,
  UNIPLOT_MARKER_PLUS = 4,
  UNIPLOT_MARKER_CROSS = 5
} uniplot_marker_shape;
typedef enum {
  UNIPLOT_MISSING_DROP = 0,
  UNIPLOT_MISSING_BREAK = 1,
  UNIPLOT_MISSING_REJECT = 2
} uniplot_missing_policy;
typedef enum {
  UNIPLOT_AGG_COUNT = 0,
  UNIPLOT_AGG_SUM = 1,
  UNIPLOT_AGG_MEAN = 2,
  UNIPLOT_AGG_MINIMUM = 3,
  UNIPLOT_AGG_MAXIMUM = 4
} uniplot_aggregation;
typedef enum {
  UNIPLOT_RASTER_NEAREST = 0,
  UNIPLOT_RASTER_BILINEAR = 1,
  UNIPLOT_RASTER_BOX = 2
} uniplot_raster_filter;
typedef enum {
  UNIPLOT_AXIS_NUMERIC = 0,
  UNIPLOT_AXIS_UTC_DATETIME = 1,
  UNIPLOT_AXIS_DURATION = 2
} uniplot_axis_labels;
typedef enum {
  UNIPLOT_SCALE_LINEAR = 0,
  UNIPLOT_SCALE_LOG10 = 1,
  UNIPLOT_SCALE_SYMLOG10 = 2,
  UNIPLOT_SCALE_POWER = 3
} uniplot_scale_kind;
typedef enum {
  UNIPLOT_COORD_CARTESIAN = 0,
  UNIPLOT_COORD_POLAR = 1
} uniplot_coordinate_kind;
typedef enum {
  UNIPLOT_HISTOGRAM_AUTO = 0,
  UNIPLOT_HISTOGRAM_SQUARE_ROOT = 1,
  UNIPLOT_HISTOGRAM_STURGES = 2,
  UNIPLOT_HISTOGRAM_RICE = 3,
  UNIPLOT_HISTOGRAM_SCOTT = 4,
  UNIPLOT_HISTOGRAM_FREEDMAN_DIACONIS = 5
} uniplot_histogram_rule;
typedef struct uniplot_plot uniplot_plot;

int uniplot_init(void);
const char *uniplot_version(void);
int uniplot_abi_version(void);
uniplot_plot *uniplot_plot_new(int width, int height);
uniplot_plot *uniplot_plot_from_json(const uint8_t *, size_t, int width,
                                 int height);
/* Status-returning variant. On every failure, *out_plot is set to NULL. */
int uniplot_plot_from_json_status(const uint8_t *, size_t, int width, int height,
                                uniplot_plot **out_plot);
int uniplot_plot_to_json(uniplot_plot *, uint8_t **, size_t *);
int uniplot_add_line(uniplot_plot *, const double *, const double *, size_t,
                   const char *color, float width);
int uniplot_add_polynomial_smooth(uniplot_plot *, const double *, const double *,
                                size_t, int degree, int point_count,
                                const char *line_color);
int uniplot_add_points(uniplot_plot *, const double *, const double *, size_t,
                     const char *color, float radius);
/* Pixels are copied. channels must be 1, 3, or 4 and length must equal
 * width*height*channels. The caller retains ownership of pixels. */
int uniplot_add_raster(uniplot_plot *, const uint8_t *pixels, size_t length,
                     int width, int height, int channels, double x_min,
                     double x_max, double y_min, double y_max, int filter);
/* Map a copied row-major scalar matrix through UniPlot's ordered UniColor
 * palette and retain the resulting RGBA8 raster. */
int uniplot_add_raster_heatmap(uniplot_plot *, int width, int height,
                             const double *values, size_t value_count,
                             double x_min, double x_max, double y_min,
                             double y_max, int filter);
/* Add one data mark in layer order. Pixels are copied and remain caller-owned. */
int uniplot_add_image_mark(uniplot_plot *, const uint8_t *pixels, size_t length,
                         int width, int height, int channels, double x_min,
                         double x_max, double y_min, double y_max, int filter);
int uniplot_add_box_plot(uniplot_plot *, const char *const *groups,
                       const double *values, size_t count,
                       double whisker_length, const char *color,
                       const char *outlier_color);
int uniplot_add_histogram_breaks(uniplot_plot *, const double *values,
                               size_t value_count, const double *breaks,
                               size_t break_count, const char *color);
int uniplot_add_numeric_histogram(uniplot_plot *, const double *values,
                                size_t value_count, const double *breaks,
                                size_t break_count, int density,
                                const char *color);
int uniplot_add_automatic_histogram(uniplot_plot *, const double *values,
                                  size_t value_count, int rule, int density,
                                  const char *color);
/* Build a retained linear fit and optional mean-confidence ribbon. Inputs are
 * copied; the caller retains ownership of both arrays. */
int uniplot_add_linear_smooth(uniplot_plot *, const double *x, const double *y,
                            size_t count, int point_count,
                            double confidence_level, int show_confidence,
                            const char *line_color, const char *band_color);
/* Build a retained Gaussian density area and line. bandwidth 0 selects the
 * UniStatistics automatic rule. Samples are copied and remain caller-owned. */
int uniplot_add_density(uniplot_plot *, const double *values, size_t count,
                      int point_count, double bandwidth,
                      const char *fill_color, const char *line_color);
/* Build one retained mirrored Gaussian density polygon. bandwidth 0 selects
 * the UniStatistics automatic rule. Samples are copied and caller-owned. */
int uniplot_add_violin(uniplot_plot *, const double *values, size_t count,
                     int point_count, double bandwidth, double width,
                     const char *color);
int uniplot_add_grouped_violin(uniplot_plot *, const char *const *groups,
                             const double *values, size_t count,
                             int point_count, double bandwidth, double width,
                             const char *color);
/* Extract retained marching-squares contours from a row-major rectilinear
 * grid. All arrays are copied and remain caller-owned. */
int uniplot_add_contours(uniplot_plot *, const double *x, size_t x_count,
                       const double *y, size_t y_count,
                       const double *values, size_t value_count,
                       const double *levels, size_t level_count,
                       const char *color, double width);
int uniplot_add_grouped_aggregate(uniplot_plot *, const char *const *groups,
                                const double *values, size_t count,
                                int aggregation, const char *color);
int uniplot_add_heatmap(uniplot_plot *, const char *const *xs,
                      const char *const *ys, const double *values,
                      size_t count, int aggregation);
int uniplot_add_numeric_heatmap(uniplot_plot *, const double *x_breaks,
                              size_t x_break_count, const double *y_breaks,
                              size_t y_break_count, const double *values,
                              size_t value_count);
int uniplot_add_categorical_column(uniplot_plot *, const char *name,
                                 const char *const *values, size_t count);
int uniplot_add_line_styled(uniplot_plot *, const double *, const double *, size_t,
                          const char *color, float width, int line_style);
int uniplot_add_points_shaped(uniplot_plot *, const double *, const double *,
                            size_t, const char *color, float radius, int shape);
int uniplot_add_line_configured(uniplot_plot *, const double *, const double *,
                              size_t, const char *color, float width,
                              int line_style, int missing_policy);
int uniplot_add_points_configured(uniplot_plot *, const double *, const double *,
                                size_t, const char *color, float radius,
                                int shape, int missing_policy);
int uniplot_set_title(uniplot_plot *, const char *title);
/* Temporal values remain numeric seconds. UTC means POSIX seconds since the
 * Unix epoch; duration means signed elapsed seconds. */
int uniplot_set_x_axis_labels(uniplot_plot *, int labels, int reversed);
int uniplot_set_y_axis_labels(uniplot_plot *, int labels, int reversed);
int uniplot_set_x_scale(uniplot_plot *, int scale, int reversed);
int uniplot_set_y_scale(uniplot_plot *, int scale, int reversed);
int uniplot_set_x_power_scale(uniplot_plot *, double exponent, int reversed);
int uniplot_set_y_power_scale(uniplot_plot *, double exponent, int reversed);
/* Polar x values are radians in [0, 2*pi]; y values are non-negative radii. */
int uniplot_set_coordinates(uniplot_plot *, int coordinates);
int uniplot_set_secondary_y(uniplot_plot *, double scale, double offset,
                          const char *label);
int uniplot_clear_secondary_y(uniplot_plot *);
int uniplot_annotate_text(uniplot_plot *, double x, double y, const char *text,
                        const char *color, float font_size);
int uniplot_annotate_arrow(uniplot_plot *, double x, double y, double x_end,
                         double y_end, const char *color, float width,
                         float head_size);
int uniplot_clear_annotations(uniplot_plot *);
int uniplot_render_png(uniplot_plot *, const char *font_path, uint8_t **, size_t *);
int uniplot_render_svg(uniplot_plot *, const char *font_path, uint8_t **, size_t *);
int uniplot_render_grid_svg(uniplot_plot *const *, size_t count, int columns,
                          int width, int height, int gap,
                          const char *font_path, uint8_t **, size_t *);
int uniplot_render_grid_png(uniplot_plot *const *, size_t count, int columns,
                          int width, int height, int gap,
                          const char *font_path, uint8_t **, size_t *);
int uniplot_render_grid_svg_shared(uniplot_plot *const *, size_t count, int columns,
                                 int width, int height, int gap, int shared_x,
                                 int shared_y, const char *font_path,
                                 uint8_t **, size_t *);
int uniplot_render_grid_png_shared(uniplot_plot *const *, size_t count, int columns,
                                 int width, int height, int gap, int shared_x,
                                 int shared_y, const char *font_path,
                                 uint8_t **, size_t *);
int uniplot_render_facet_grid_svg(uniplot_plot *, const char *column, int columns,
                                int width, int height, int gap, int shared_x,
                                int shared_y, const char *font_path,
                                uint8_t **, size_t *);
int uniplot_render_facet_grid_png(uniplot_plot *, const char *column, int columns,
                                int width, int height, int gap, int shared_x,
                                int shared_y, const char *font_path,
                                uint8_t **, size_t *);
int uniplot_render_facet_matrix_svg(uniplot_plot *, const char *row_column,
                                  const char *column_column, int width,
                                  int height, int gap, int shared_x,
                                  int shared_y, const char *font_path,
                                  uint8_t **, size_t *);
int uniplot_render_facet_matrix_png(uniplot_plot *, const char *row_column,
                                  const char *column_column, int width,
                                  int height, int gap, int shared_x,
                                  int shared_y, const char *font_path,
                                  uint8_t **, size_t *);
void uniplot_buffer_free(void *, size_t);
void uniplot_plot_free(uniplot_plot *);

#ifdef __cplusplus
}
#endif
#endif
