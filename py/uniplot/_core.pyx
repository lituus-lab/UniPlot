# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from libc.stdint cimport uint8_t
from libc.stdlib cimport malloc, free
from cpython.bytes cimport PyBytes_FromStringAndSize

cdef extern from "UniPlot.h":
    ctypedef struct uplot_plot:
        pass
    int uplot_init()
    const char *uplot_version()
    int uplot_abi_version()
    uplot_plot *uplot_plot_new(int, int)
    uplot_plot *uplot_plot_from_json(const uint8_t *, size_t, int, int)
    int uplot_plot_to_json(uplot_plot *, uint8_t **, size_t *)
    int uplot_add_line(uplot_plot *, const double *, const double *, size_t,
                       const char *, float)
    int uplot_add_points(uplot_plot *, const double *, const double *, size_t,
                         const char *, float)
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
    int uplot_render_png(uplot_plot *, const char *, uint8_t **, size_t *)
    int uplot_render_svg(uplot_plot *, const char *, uint8_t **, size_t *)
    int uplot_render_grid_svg(uplot_plot **, size_t, int, int, int, int,
                               const char *, uint8_t **, size_t *)
    int uplot_render_grid_png(uplot_plot **, size_t, int, int, int, int,
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

cdef class Plot:
    cdef uplot_plot *_handle

    def __cinit__(self, int width=800, int height=500):
        self._handle = uplot_plot_new(width, height)
        if self._handle == NULL:
            raise ValueError("plot dimensions must be positive")

    def __dealloc__(self):
        if self._handle != NULL:
            uplot_plot_free(self._handle)

    @classmethod
    def from_json(cls, payload, int width=800, int height=500):
        cdef bytes encoded
        if isinstance(payload, bytes):
            encoded = payload
        elif isinstance(payload, str):
            encoded = payload.encode("utf-8")
        else:
            raise TypeError("payload must be str or bytes")
        cdef uplot_plot *parsed = uplot_plot_from_json(
            <const uint8_t *>encoded, len(encoded), width, height)
        if parsed == NULL:
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

    def title(self, value):
        cdef bytes encoded = str(value).encode("utf-8")
        if uplot_set_title(self._handle, encoded) != 0: raise ValueError("invalid title")
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
                        int gap, bint svg):
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
            status = uplot_render_grid_svg(handles, count, columns, width,
                                            height, gap, encoded, &output,
                                            &length)
        else:
            status = uplot_render_grid_png(handles, count, columns, width,
                                            height, gap, encoded, &output,
                                            &length)
        if status == 1:
            raise ValueError("invalid plot grid arguments")
        if status != 0:
            raise RuntimeError("plot grid render failed")
        return PyBytes_FromStringAndSize(<char *>output, length)
    finally:
        free(handles)
        uplot_buffer_free(output, length)

def grid_svg(plots, font, int columns, int width=1200, int height=800,
             int gap=16):
    return _render_grid(plots, font, columns, width, height, gap, True)

def grid_png(plots, font, int columns, int width=1200, int height=800,
             int gap=16):
    return _render_grid(plots, font, columns, width, height, gap, False)

def version(): return uplot_version().decode("ascii")
def abi_version(): return uplot_abi_version()
