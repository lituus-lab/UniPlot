# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from libc.stdint cimport uint8_t
from libc.stdlib cimport malloc, free
from cpython.bytes cimport PyBytes_FromStringAndSize

cdef extern from "UniPlot.h":
    enum:
        UPLOT_OK
        UPLOT_ERR_MEMORY
    ctypedef struct uplot_plot:
        pass
    int uplot_init()
    const char *uplot_version()
    int uplot_abi_version()
    uplot_plot *uplot_plot_new(int, int)
    uplot_plot *uplot_plot_from_json(const uint8_t *, size_t, int, int)
    int uplot_plot_from_json_status(const uint8_t *, size_t, int, int,
                                    uplot_plot **)
    int uplot_plot_to_json(uplot_plot *, uint8_t **, size_t *)
    int uplot_add_line(uplot_plot *, const double *, const double *, size_t,
                       const char *, float)
    int uplot_add_points(uplot_plot *, const double *, const double *, size_t,
                         const char *, float)
    int uplot_add_raster(uplot_plot *, const uint8_t *, size_t, int, int, int,
                         double, double, double, double, int)
    int uplot_add_raster_heatmap(uplot_plot *, int, int, const double *,
                                 size_t, double, double, double, double, int)
    int uplot_add_image_mark(uplot_plot *, const uint8_t *, size_t, int, int,
                             int, double, double, double, double, int)
    int uplot_add_box_plot(uplot_plot *, const char **, const double *, size_t,
                           double, const char *, const char *)
    int uplot_add_histogram_breaks(uplot_plot *, const double *, size_t,
                                   const double *, size_t, const char *)
    int uplot_add_numeric_histogram(uplot_plot *, const double *, size_t,
                                    const double *, size_t, int,
                                    const char *)
    int uplot_add_automatic_histogram(uplot_plot *, const double *, size_t,
                                      int, int, const char *)
    int uplot_add_linear_smooth(uplot_plot *, const double *, const double *,
                                size_t, int, double, int, const char *,
                                const char *)
    int uplot_add_density(uplot_plot *, const double *, size_t, int, double,
                          const char *, const char *)
    int uplot_add_violin(uplot_plot *, const double *, size_t, int, double,
                         double, const char *)
    int uplot_add_grouped_violin(uplot_plot *, const char **, const double *,
                                 size_t, int, double, double, const char *)
    int uplot_add_contours(uplot_plot *, const double *, size_t,
                           const double *, size_t, const double *, size_t,
                           const double *, size_t, const char *, double)
    int uplot_add_grouped_aggregate(uplot_plot *, const char **,
                                    const double *, size_t, int,
                                    const char *)
    int uplot_add_heatmap(uplot_plot *, const char **, const char **,
                          const double *, size_t, int)
    int uplot_add_numeric_heatmap(uplot_plot *, const double *, size_t,
                                  const double *, size_t, const double *,
                                  size_t)
    int uplot_add_categorical_column(uplot_plot *, const char *,
                                      const char **, size_t)
    int uplot_add_line_styled(uplot_plot *, const double *, const double *,
                              size_t, const char *, float, int)
    int uplot_add_points_shaped(uplot_plot *, const double *, const double *,
                                size_t, const char *, float, int)
    int uplot_add_line_configured(uplot_plot *, const double *, const double *,
                                  size_t, const char *, float, int, int)
    int uplot_add_points_configured(uplot_plot *, const double *,
                                    const double *, size_t, const char *,
                                    float, int, int)
    int uplot_set_title(uplot_plot *, const char *)
    int uplot_set_x_axis_labels(uplot_plot *, int, int)
    int uplot_set_y_axis_labels(uplot_plot *, int, int)
    int uplot_set_x_scale(uplot_plot *, int, int)
    int uplot_set_y_scale(uplot_plot *, int, int)
    int uplot_set_secondary_y(uplot_plot *, double, double, const char *)
    int uplot_clear_secondary_y(uplot_plot *)
    int uplot_annotate_text(uplot_plot *, double, double, const char *,
                             const char *, float)
    int uplot_annotate_arrow(uplot_plot *, double, double, double, double,
                              const char *, float, float)
    int uplot_clear_annotations(uplot_plot *)
    int uplot_render_png(uplot_plot *, const char *, uint8_t **, size_t *)
    int uplot_render_svg(uplot_plot *, const char *, uint8_t **, size_t *)
    int uplot_render_grid_svg(uplot_plot **, size_t, int, int, int, int,
                               const char *, uint8_t **, size_t *)
    int uplot_render_grid_png(uplot_plot **, size_t, int, int, int, int,
                               const char *, uint8_t **, size_t *)
    int uplot_render_grid_svg_shared(uplot_plot **, size_t, int, int, int, int,
                                      int, int, const char *, uint8_t **,
                                      size_t *)
    int uplot_render_grid_png_shared(uplot_plot **, size_t, int, int, int, int,
                                      int, int, const char *, uint8_t **,
                                      size_t *)
    int uplot_render_facet_grid_svg(uplot_plot *, const char *, int, int, int,
                                     int, int, int, const char *, uint8_t **,
                                     size_t *)
    int uplot_render_facet_grid_png(uplot_plot *, const char *, int, int, int,
                                     int, int, int, const char *, uint8_t **,
                                     size_t *)
    int uplot_render_facet_matrix_svg(uplot_plot *, const char *,
                                       const char *, int, int, int, int, int,
                                       const char *, uint8_t **, size_t *)
    int uplot_render_facet_matrix_png(uplot_plot *, const char *,
                                       const char *, int, int, int, int, int,
                                       const char *, uint8_t **, size_t *)
    void uplot_buffer_free(void *, size_t)
    void uplot_plot_free(uplot_plot *)

uplot_init()

LINE_SOLID = 0
LINE_DASHED = 1
LINE_DOTTED = 2
LINE_DOT_DASH = 3
LINE_LONG_DASH = 4
MARKER_CIRCLE = 0
MARKER_SQUARE = 1
MARKER_TRIANGLE = 2
MARKER_DIAMOND = 3
MARKER_PLUS = 4
MARKER_CROSS = 5
MISSING_DROP = 0
MISSING_BREAK = 1
MISSING_REJECT = 2
AGG_COUNT = 0
AGG_SUM = 1
AGG_MEAN = 2
AGG_MINIMUM = 3
AGG_MAXIMUM = 4
RASTER_NEAREST = 0
RASTER_BILINEAR = 1
RASTER_BOX = 2
AXIS_NUMERIC = 0
AXIS_UTC_DATETIME = 1
AXIS_DURATION = 2
SCALE_LINEAR = 0
SCALE_LOG10 = 1
SCALE_SYMLOG10 = 2
HISTOGRAM_AUTO = 0
HISTOGRAM_SQUARE_ROOT = 1
HISTOGRAM_STURGES = 2
HISTOGRAM_RICE = 3
HISTOGRAM_SCOTT = 4
HISTOGRAM_FREEDMAN_DIACONIS = 5

cdef class Plot:
    cdef uplot_plot *_handle

    def __cinit__(self, int width=800, int height=500):
        self._handle = uplot_plot_new(width, height)
        if self._handle == NULL:
            raise ValueError("plot dimensions must be positive")

    def __dealloc__(self):
        if self._handle != NULL:
            uplot_plot_free(self._handle)

    cdef _add_image_pixels(self, pixels, int width, int height, int channels,
                           double x_min, double x_max, double y_min,
                           double y_max, int filter, bint mark):
        cdef bytes payload = bytes(pixels)
        cdef const uint8_t *data = payload
        if len(payload) == 0:
            raise ValueError("image pixels cannot be empty")
        cdef int status
        if mark:
            status = uplot_add_image_mark(
                self._handle, data, len(payload), width, height, channels,
                x_min, x_max, y_min, y_max, filter)
        else:
            status = uplot_add_raster(
                self._handle, data, len(payload), width, height, channels,
                x_min, x_max, y_min, y_max, filter)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != 0:
            raise ValueError(
                "invalid image pixels, dimensions, extents, or filter")
        return self

    def raster(self, pixels, int width, int height, int channels,
               double x_min, double x_max, double y_min, double y_max,
               int filter=RASTER_BILINEAR):
        return self._add_image_pixels(pixels, width, height, channels,
                                      x_min, x_max, y_min, y_max, filter,
                                      False)

    def image(self, pixels, int width, int height, int channels,
              double x_min, double x_max, double y_min, double y_max,
              int filter=RASTER_BILINEAR):
        return self._add_image_pixels(pixels, width, height, channels,
                                      x_min, x_max, y_min, y_max, filter,
                                      True)

    @classmethod
    def from_json(cls, payload, int width=800, int height=500):
        cdef bytes encoded
        if isinstance(payload, bytes):
            encoded = payload
        elif isinstance(payload, str):
            encoded = payload.encode("utf-8")
        else:
            raise TypeError("payload must be str or bytes")
        cdef uplot_plot *parsed = NULL
        cdef int status = uplot_plot_from_json_status(
            <const uint8_t *>encoded, len(encoded), width, height, &parsed)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid UniPlot JSON or plot dimensions")
        result = cls(width, height)
        uplot_plot_free((<Plot>result)._handle)
        (<Plot>result)._handle = parsed
        return result

    def to_json(self):
        cdef uint8_t *output = NULL
        cdef size_t length = 0
        if uplot_plot_to_json(self._handle, &output, &length) != 0:
            raise RuntimeError("JSON encoding failed")
        try:
            return PyBytes_FromStringAndSize(
                <char *>output, length).decode("utf-8")
        finally:
            uplot_buffer_free(output, length)

    cdef _series(self, x, y, color, float size, bint points, int style,
                 int missing):
        if len(x) != len(y) or len(x) == 0:
            raise ValueError("x and y must have equal non-zero lengths")
        cdef size_t n = len(x)
        cdef double *xs = <double *>malloc(n * sizeof(double))
        cdef double *ys = <double *>malloc(n * sizeof(double))
        cdef bytes encoded = str(color).encode("utf-8")
        cdef size_t i
        cdef int status
        if xs == NULL or ys == NULL:
            free(xs); free(ys)
            raise MemoryError()
        try:
            for i in range(n):
                xs[i] = float(x[i]); ys[i] = float(y[i])
            if points:
                status = uplot_add_points_configured(
                    self._handle, xs, ys, n, encoded, size, style, missing)
            else:
                status = uplot_add_line_configured(
                    self._handle, xs, ys, n, encoded, size, style, missing)
        finally:
            free(xs); free(ys)
        if status != 0: raise ValueError("invalid series")
        return self

    def line(self, x, y, color="#3366cc", width=2.0,
             style=LINE_SOLID, missing=MISSING_BREAK):
        return self._series(x, y, color, width, False, style, missing)

    def scatter(self, x, y, color="#3366cc", radius=4.0,
                shape=MARKER_CIRCLE, missing=MISSING_DROP):
        return self._series(x, y, color, radius, True, shape, missing)

    def boxplot(self, groups, values, double whisker_length=1.5,
                color="#3366cc", outlier_color="#cc3344"):
        groups = list(groups)
        values = list(values)
        if len(groups) != len(values) or len(groups) == 0:
            raise ValueError("groups and values must have equal non-zero lengths")
        cdef list encoded_groups = [str(group).encode("utf-8")
                                    for group in groups]
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef bytes encoded_outlier_color = str(outlier_color).encode("utf-8")
        cdef size_t count = len(values)
        cdef const char **group_items = <const char **>malloc(
            count * sizeof(const char *))
        cdef double *number_items = <double *>malloc(count * sizeof(double))
        cdef size_t index
        cdef int status
        if group_items == NULL or number_items == NULL:
            free(group_items); free(number_items)
            raise MemoryError()
        try:
            for index in range(count):
                group_items[index] = encoded_groups[index]
                number_items[index] = float(values[index])
            status = uplot_add_box_plot(self._handle, group_items,
                                        number_items, count, whisker_length,
                                        encoded_color,
                                        encoded_outlier_color)
        finally:
            free(group_items); free(number_items)
        if status != 0:
            raise ValueError("invalid box plot or non-empty plot")
        return self

    def heatmap(self, x, y, values, int aggregation=AGG_MEAN):
        x = list(x)
        y = list(y)
        values = list(values)
        if len(x) != len(y) or len(x) != len(values) or len(x) == 0:
            raise ValueError("x, y and values must have equal non-zero lengths")
        cdef list encoded_x = [str(item).encode("utf-8") for item in x]
        cdef list encoded_y = [str(item).encode("utf-8") for item in y]
        cdef size_t count = len(values)
        cdef const char **x_items = <const char **>malloc(
            count * sizeof(const char *))
        cdef const char **y_items = <const char **>malloc(
            count * sizeof(const char *))
        cdef double *number_items = <double *>malloc(count * sizeof(double))
        cdef size_t index
        cdef int status
        if x_items == NULL or y_items == NULL or number_items == NULL:
            free(x_items); free(y_items); free(number_items)
            raise MemoryError()
        try:
            for index in range(count):
                x_items[index] = encoded_x[index]
                y_items[index] = encoded_y[index]
                number_items[index] = float(values[index])
            status = uplot_add_heatmap(self._handle, x_items, y_items,
                                       number_items, count, aggregation)
        finally:
            free(x_items); free(y_items); free(number_items)
        if status != 0:
            raise ValueError("invalid heatmap or non-empty plot")
        return self

    def numeric_heatmap(self, x_breaks, y_breaks, values):
        x_breaks = list(x_breaks)
        y_breaks = list(y_breaks)
        values = list(values)
        if len(x_breaks) < 2 or len(y_breaks) < 2:
            raise ValueError("numeric heatmap axes require two boundaries")
        if len(values) != (len(x_breaks) - 1) * (len(y_breaks) - 1):
            raise ValueError("values must match the row-major cell count")
        cdef size_t x_count = len(x_breaks)
        cdef size_t y_count = len(y_breaks)
        cdef size_t value_count = len(values)
        cdef double *x_items = <double *>malloc(x_count * sizeof(double))
        cdef double *y_items = <double *>malloc(y_count * sizeof(double))
        cdef double *value_items = <double *>malloc(
            value_count * sizeof(double))
        cdef size_t index
        cdef int status
        if x_items == NULL or y_items == NULL or value_items == NULL:
            free(x_items); free(y_items); free(value_items)
            raise MemoryError()
        try:
            for index in range(x_count):
                x_items[index] = float(x_breaks[index])
            for index in range(y_count):
                y_items[index] = float(y_breaks[index])
            for index in range(value_count):
                value_items[index] = float(values[index])
            status = uplot_add_numeric_heatmap(
                self._handle, x_items, x_count, y_items, y_count,
                value_items, value_count)
        finally:
            free(x_items); free(y_items); free(value_items)
        if status != 0:
            raise ValueError("invalid numeric heatmap or non-empty plot")
        return self

    def histogram(self, values, breaks, color="#3366cc", bint density=False):
        values = list(values)
        breaks = list(breaks)
        if len(values) == 0:
            raise ValueError("histogram values cannot be empty")
        if len(breaks) < 2:
            raise ValueError("histogram breaks require at least two boundaries")
        cdef size_t value_count = len(values)
        cdef size_t break_count = len(breaks)
        cdef double *value_items = <double *>malloc(
            value_count * sizeof(double))
        cdef double *break_items = <double *>malloc(
            break_count * sizeof(double))
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef size_t index
        cdef int status
        if value_items == NULL or break_items == NULL:
            free(value_items); free(break_items)
            raise MemoryError()
        try:
            for index in range(value_count):
                value_items[index] = float(values[index])
            for index in range(break_count):
                break_items[index] = float(breaks[index])
            status = uplot_add_numeric_histogram(
                self._handle, value_items, value_count,
                break_items, break_count, density, encoded_color)
        finally:
            free(value_items); free(break_items)
        if status != 0:
            raise ValueError("invalid histogram or non-empty plot")
        return self

    def automatic_histogram(self, values, int rule=HISTOGRAM_AUTO,
                            color="#3366cc", bint density=False):
        values = list(values)
        if len(values) == 0:
            raise ValueError("histogram values cannot be empty")
        cdef size_t value_count = len(values)
        cdef double *value_items = <double *>malloc(
            value_count * sizeof(double))
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef size_t index
        cdef int status
        if value_items == NULL:
            raise MemoryError()
        try:
            for index in range(value_count):
                value_items[index] = float(values[index])
            status = uplot_add_automatic_histogram(
                self._handle, value_items, value_count, rule, density,
                encoded_color)
        finally:
            free(value_items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid automatic histogram or non-empty plot")
        return self

    def linear_smooth(self, x, y, int point_count=100,
                      double confidence_level=0.95,
                      bint show_confidence=True, line_color="#3366cc",
                      band_color="#3366cc40"):
        x = list(x)
        y = list(y)
        if len(x) != len(y) or len(x) < 3:
            raise ValueError("smoothing samples must have equal lengths >= 3")
        cdef size_t count = len(x)
        cdef double *x_items = <double *>malloc(count * sizeof(double))
        cdef double *y_items = <double *>malloc(count * sizeof(double))
        cdef bytes encoded_line = str(line_color).encode("utf-8")
        cdef bytes encoded_band = str(band_color).encode("utf-8")
        cdef size_t index
        cdef int status
        if x_items == NULL or y_items == NULL:
            free(x_items); free(y_items)
            raise MemoryError()
        try:
            for index in range(count):
                x_items[index] = float(x[index])
                y_items[index] = float(y[index])
            status = uplot_add_linear_smooth(
                self._handle, x_items, y_items, count, point_count,
                confidence_level, show_confidence, encoded_line, encoded_band)
        finally:
            free(x_items); free(y_items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid linear smoothing input or non-empty plot")
        return self

    def density(self, values, int point_count=512, double bandwidth=0.0,
                fill_color="#3366cc40", line_color="#3366cc"):
        values = list(values)
        if len(values) < 2:
            raise ValueError("density requires at least two observations")
        cdef size_t count = len(values)
        cdef double *items = <double *>malloc(count * sizeof(double))
        cdef bytes encoded_fill = str(fill_color).encode("utf-8")
        cdef bytes encoded_line = str(line_color).encode("utf-8")
        cdef size_t index
        cdef int status
        if items == NULL:
            raise MemoryError()
        try:
            for index in range(count):
                items[index] = float(values[index])
            status = uplot_add_density(self._handle, items, count,
                point_count, bandwidth, encoded_fill, encoded_line)
        finally:
            free(items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid density input or non-empty plot")
        return self

    def violin(self, values, int point_count=256, double bandwidth=0.0,
                double width=0.8, color="#3366cc80"):
        values = list(values)
        if len(values) < 2:
            raise ValueError("violin requires at least two observations")
        cdef size_t count = len(values)
        cdef double *items = <double *>malloc(count * sizeof(double))
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef size_t index
        cdef int status
        if items == NULL:
            raise MemoryError()
        try:
            for index in range(count):
                items[index] = float(values[index])
            status = uplot_add_violin(self._handle, items, count,
                point_count, bandwidth, width, encoded_color)
        finally:
            free(items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid violin input or non-empty plot")
        return self

    def grouped_violin(self, groups, values, int point_count=256,
                       double bandwidth=0.0, double width=0.8,
                       color="#3366cc80"):
        groups = list(groups)
        values = list(values)
        if len(groups) != len(values) or len(groups) < 2:
            raise ValueError("groups and values must have equal lengths")
        cdef list encoded_groups = [str(group).encode("utf-8")
                                    for group in groups]
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef size_t count = len(values)
        cdef const char **group_items = <const char **>malloc(
            count * sizeof(const char *))
        cdef double *number_items = <double *>malloc(count * sizeof(double))
        cdef size_t index
        cdef int status
        if group_items == NULL or number_items == NULL:
            free(group_items); free(number_items)
            raise MemoryError()
        try:
            for index in range(count):
                group_items[index] = encoded_groups[index]
                number_items[index] = float(values[index])
            status = uplot_add_grouped_violin(
                self._handle, group_items, number_items, count, point_count,
                bandwidth, width, encoded_color)
        finally:
            free(group_items); free(number_items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid grouped violin input or non-empty plot")
        return self

    def contour(self, x, y, values, levels, color="#3366cc",
                double width=0.0):
        x = list(x)
        y = list(y)
        values = list(values)
        levels = list(levels)
        if len(x) < 2 or len(y) < 2 or len(levels) == 0 or \
                len(values) != len(x) * len(y):
            raise ValueError("invalid rectilinear contour dimensions")
        cdef size_t x_count = len(x)
        cdef size_t y_count = len(y)
        cdef size_t value_count = len(values)
        cdef size_t level_count = len(levels)
        cdef double *x_items = <double *>malloc(x_count * sizeof(double))
        cdef double *y_items = <double *>malloc(y_count * sizeof(double))
        cdef double *value_items = <double *>malloc(
            value_count * sizeof(double))
        cdef double *level_items = <double *>malloc(
            level_count * sizeof(double))
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef size_t index
        cdef int status
        if x_items == NULL or y_items == NULL or value_items == NULL or \
                level_items == NULL:
            free(x_items); free(y_items); free(value_items); free(level_items)
            raise MemoryError()
        try:
            for index in range(x_count):
                x_items[index] = float(x[index])
            for index in range(y_count):
                y_items[index] = float(y[index])
            for index in range(value_count):
                value_items[index] = float(values[index])
            for index in range(level_count):
                level_items[index] = float(levels[index])
            status = uplot_add_contours(self._handle, x_items, x_count,
                y_items, y_count, value_items, value_count, level_items,
                level_count, encoded_color, width)
        finally:
            free(x_items); free(y_items); free(value_items); free(level_items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid contour input or non-empty plot")
        return self

    def raster_heatmap(self, int width, int height, values,
                       double x_min, double x_max,
                       double y_min, double y_max,
                       int filter=RASTER_NEAREST):
        values = list(values)
        if width <= 0 or height <= 0 or len(values) != width * height:
            raise ValueError("invalid raster heatmap dimensions")
        cdef size_t count = len(values)
        cdef double *items = <double *>malloc(count * sizeof(double))
        cdef size_t index
        cdef int status
        if items == NULL:
            raise MemoryError()
        try:
            for index in range(count):
                items[index] = float(values[index])
            status = uplot_add_raster_heatmap(self._handle, width, height,
                items, count, x_min, x_max, y_min, y_max, filter)
        finally:
            free(items)
        if status == UPLOT_ERR_MEMORY:
            raise MemoryError()
        if status != UPLOT_OK:
            raise ValueError("invalid raster heatmap input or non-empty plot")
        return self

    def aggregate(self, groups, values, int aggregation=AGG_MEAN,
                  color="#3366cc"):
        groups = list(groups)
        values = list(values)
        if len(groups) != len(values) or len(groups) == 0:
            raise ValueError("groups and values must have equal non-zero lengths")
        cdef list encoded_groups = [str(group).encode("utf-8")
                                    for group in groups]
        cdef bytes encoded_color = str(color).encode("utf-8")
        cdef size_t count = len(values)
        cdef const char **group_items = <const char **>malloc(
            count * sizeof(const char *))
        cdef double *number_items = <double *>malloc(count * sizeof(double))
        cdef size_t index
        cdef int status
        if group_items == NULL or number_items == NULL:
            free(group_items); free(number_items)
            raise MemoryError()
        try:
            for index in range(count):
                group_items[index] = encoded_groups[index]
                number_items[index] = float(values[index])
            status = uplot_add_grouped_aggregate(
                self._handle, group_items, number_items, count,
                aggregation, encoded_color)
        finally:
            free(group_items); free(number_items)
        if status != 0:
            raise ValueError("invalid grouped aggregate or non-empty plot")
        return self

    def categorical_column(self, name, values):
        values = list(values)
        if len(values) == 0:
            raise ValueError("categorical columns cannot be empty")
        cdef bytes encoded_name = str(name).encode("utf-8")
        cdef list encoded_values = [str(value).encode("utf-8")
                                    for value in values]
        cdef size_t count = len(encoded_values)
        cdef const char **items = <const char **>malloc(
            count * sizeof(const char *))
        cdef size_t index
        if items == NULL:
            raise MemoryError()
        try:
            for index in range(count):
                items[index] = encoded_values[index]
            if uplot_add_categorical_column(
                    self._handle, encoded_name, items, count) != 0:
                raise ValueError("invalid categorical column")
        finally:
            free(items)
        return self

    def title(self, value):
        cdef bytes encoded = str(value).encode("utf-8")
        if uplot_set_title(self._handle, encoded) != 0: raise ValueError("invalid title")
        return self

    def x_axis_labels(self, int labels=AXIS_NUMERIC, bint reversed=False):
        if uplot_set_x_axis_labels(self._handle, labels, int(reversed)) != 0:
            raise ValueError("invalid x axis label semantics")
        return self

    def y_axis_labels(self, int labels=AXIS_NUMERIC, bint reversed=False):
        if uplot_set_y_axis_labels(self._handle, labels, int(reversed)) != 0:
            raise ValueError("invalid y axis label semantics")
        return self

    def scale_x_utc(self, bint reversed=False):
        return self.x_axis_labels(AXIS_UTC_DATETIME, reversed)

    def scale_y_utc(self, bint reversed=False):
        return self.y_axis_labels(AXIS_UTC_DATETIME, reversed)

    def scale_x_duration(self, bint reversed=False):
        return self.x_axis_labels(AXIS_DURATION, reversed)

    def scale_y_duration(self, bint reversed=False):
        return self.y_axis_labels(AXIS_DURATION, reversed)

    def scale_x(self, int kind=SCALE_LINEAR, bint reversed=False):
        if uplot_set_x_scale(self._handle, kind, int(reversed)) != 0:
            raise ValueError("invalid x scale")
        return self

    def scale_y(self, int kind=SCALE_LINEAR, bint reversed=False):
        if uplot_set_y_scale(self._handle, kind, int(reversed)) != 0:
            raise ValueError("invalid y scale")
        return self

    def secondary_y(self, double scale=1.0, double offset=0.0, label=""):
        cdef bytes encoded = str(label).encode("utf-8")
        if uplot_set_secondary_y(
                self._handle, scale, offset, encoded) != 0:
            raise ValueError("invalid secondary y transform")
        return self

    def clear_secondary_y(self):
        if uplot_clear_secondary_y(self._handle) != 0:
            raise RuntimeError("cannot clear secondary y axis")
        return self

    def annotate_text(self, double x, double y, text, color="#202124",
                      float font_size=13.0):
        cdef bytes encoded_text = str(text).encode("utf-8")
        cdef bytes encoded_color = str(color).encode("utf-8")
        if uplot_annotate_text(self._handle, x, y, encoded_text,
                               encoded_color, font_size) != 0:
            raise ValueError("invalid text annotation")
        return self

    def annotate_arrow(self, double x, double y, double x_end, double y_end,
                       color="#202124", float width=2.0,
                       float head_size=8.0):
        cdef bytes encoded_color = str(color).encode("utf-8")
        if uplot_annotate_arrow(self._handle, x, y, x_end, y_end,
                                encoded_color, width, head_size) != 0:
            raise ValueError("invalid arrow annotation")
        return self

    def clear_annotations(self):
        if uplot_clear_annotations(self._handle) != 0:
            raise RuntimeError("cannot clear annotations")
        return self

    cdef bytes _render(self, font, bint svg):
        cdef bytes encoded = str(font).encode("utf-8")
        cdef uint8_t *output = NULL
        cdef size_t length = 0
        cdef int status
        if svg:
            status = uplot_render_svg(self._handle, encoded, &output, &length)
        else:
            status = uplot_render_png(self._handle, encoded, &output, &length)
        if status != 0: raise RuntimeError("render failed")
        try:
            return PyBytes_FromStringAndSize(<char *>output, length)
        finally:
            uplot_buffer_free(output, length)

    def svg(self, font): return self._render(font, True)
    def png(self, font): return self._render(font, False)

cdef bytes _render_grid(plots, font, int columns, int width, int height,
                        int gap, bint svg, bint shared_x, bint shared_y):
    cdef Py_ssize_t count = len(plots)
    cdef uplot_plot **handles
    cdef Py_ssize_t index
    cdef bytes encoded = str(font).encode("utf-8")
    cdef uint8_t *output = NULL
    cdef size_t length = 0
    cdef int status
    if count == 0:
        raise ValueError("plot grid requires at least one plot")
    handles = <uplot_plot **>malloc(count * sizeof(uplot_plot *))
    if handles == NULL:
        raise MemoryError()
    try:
        for index in range(count):
            if not isinstance(plots[index], Plot):
                raise TypeError("plot grid entries must be Plot instances")
            handles[index] = (<Plot>plots[index])._handle
        if svg:
            status = uplot_render_grid_svg_shared(
                handles, count, columns, width, height, gap, shared_x,
                shared_y, encoded, &output, &length)
        else:
            status = uplot_render_grid_png_shared(
                handles, count, columns, width, height, gap, shared_x,
                shared_y, encoded, &output, &length)
        if status == 1:
            raise ValueError("invalid plot grid arguments")
        if status != 0:
            raise RuntimeError("plot grid render failed")
        return PyBytes_FromStringAndSize(<char *>output, length)
    finally:
        free(handles)
        uplot_buffer_free(output, length)

def grid_svg(plots, font, int columns, int width=1200, int height=800,
             int gap=16, bint shared_x=False, bint shared_y=False):
    return _render_grid(plots, font, columns, width, height, gap, True,
                        shared_x, shared_y)

def grid_png(plots, font, int columns, int width=1200, int height=800,
             int gap=16, bint shared_x=False, bint shared_y=False):
    return _render_grid(plots, font, columns, width, height, gap, False,
                        shared_x, shared_y)

cdef bytes _render_facets(Plot plot, column, font, int columns, int width,
                          int height, int gap, bint svg, bint shared_x,
                          bint shared_y):
    cdef bytes encoded_column = str(column).encode("utf-8")
    cdef bytes encoded_font = str(font).encode("utf-8")
    cdef uint8_t *output = NULL
    cdef size_t length = 0
    cdef int status
    if svg:
        status = uplot_render_facet_grid_svg(
            plot._handle, encoded_column, columns, width, height, gap,
            shared_x, shared_y, encoded_font, &output, &length)
    else:
        status = uplot_render_facet_grid_png(
            plot._handle, encoded_column, columns, width, height, gap,
            shared_x, shared_y, encoded_font, &output, &length)
    try:
        if status == 1:
            raise ValueError("invalid facet grid arguments")
        if status != 0:
            raise RuntimeError("facet grid render failed")
        return PyBytes_FromStringAndSize(<char *>output, length)
    finally:
        uplot_buffer_free(output, length)

def facet_svg(Plot plot, column, font, int columns, int width=1200,
              int height=800, int gap=16, bint shared_x=False,
              bint shared_y=False):
    return _render_facets(plot, column, font, columns, width, height, gap,
                          True, shared_x, shared_y)

def facet_png(Plot plot, column, font, int columns, int width=1200,
              int height=800, int gap=16, bint shared_x=False,
              bint shared_y=False):
    return _render_facets(plot, column, font, columns, width, height, gap,
                          False, shared_x, shared_y)

cdef bytes _render_facet_matrix(Plot plot, row_column, column_column, font,
                                int width, int height, int gap, bint svg,
                                bint shared_x, bint shared_y):
    cdef bytes encoded_row = str(row_column).encode("utf-8")
    cdef bytes encoded_column = str(column_column).encode("utf-8")
    cdef bytes encoded_font = str(font).encode("utf-8")
    cdef uint8_t *output = NULL
    cdef size_t length = 0
    cdef int status
    if svg:
        status = uplot_render_facet_matrix_svg(
            plot._handle, encoded_row, encoded_column, width, height, gap,
            shared_x, shared_y, encoded_font, &output, &length)
    else:
        status = uplot_render_facet_matrix_png(
            plot._handle, encoded_row, encoded_column, width, height, gap,
            shared_x, shared_y, encoded_font, &output, &length)
    try:
        if status == 1:
            raise ValueError("invalid facet matrix arguments")
        if status != 0:
            raise RuntimeError("facet matrix render failed")
        return PyBytes_FromStringAndSize(<char *>output, length)
    finally:
        uplot_buffer_free(output, length)

def facet_matrix_svg(Plot plot, row_column, column_column, font,
                     int width=1200, int height=800, int gap=16,
                     bint shared_x=False, bint shared_y=False):
    return _render_facet_matrix(
        plot, row_column, column_column, font, width, height, gap, True,
        shared_x, shared_y)

def facet_matrix_png(Plot plot, row_column, column_column, font,
                     int width=1200, int height=800, int gap=16,
                     bint shared_x=False, bint shared_y=False):
    return _render_facet_matrix(
        plot, row_column, column_column, font, width, height, gap, False,
        shared_x, shared_y)

def version(): return uplot_version().decode("ascii")
def abi_version(): return uplot_abi_version()
