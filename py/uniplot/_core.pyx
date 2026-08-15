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
    int uplot_add_line(uplot_plot *, const double *, const double *, size_t,
                       const char *, float)
    int uplot_add_points(uplot_plot *, const double *, const double *, size_t,
                         const char *, float)
    int uplot_set_title(uplot_plot *, const char *)
    int uplot_render_png(uplot_plot *, const char *, uint8_t **, size_t *)
    int uplot_render_svg(uplot_plot *, const char *, uint8_t **, size_t *)
    void uplot_buffer_free(void *, size_t)
    void uplot_plot_free(uplot_plot *)

uplot_init()

cdef class Plot:
    cdef uplot_plot *_handle

    def __cinit__(self, int width=800, int height=500):
        self._handle = uplot_plot_new(width, height)
        if self._handle == NULL:
            raise ValueError("plot dimensions must be positive")

    def __dealloc__(self):
        if self._handle != NULL:
            uplot_plot_free(self._handle)

    cdef _series(self, x, y, color, float size, bint points):
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
                status = uplot_add_points(self._handle, xs, ys, n, encoded, size)
            else:
                status = uplot_add_line(self._handle, xs, ys, n, encoded, size)
        finally:
            free(xs); free(ys)
        if status != 0: raise ValueError("invalid series")
        return self

    def line(self, x, y, color="#3366cc", width=2.0):
        return self._series(x, y, color, width, False)

    def scatter(self, x, y, color="#3366cc", radius=4.0):
        return self._series(x, y, color, radius, True)

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

def version(): return uplot_version().decode("ascii")
def abi_version(): return uplot_abi_version()
