# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import ctypes
import json
import math
from pathlib import Path
import statistics
import sys
import time

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "py"))
import uniplot


def summary(values):
    return {
        "mean_ms": statistics.fmean(values),
        "stdev_ms": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min_ms": min(values),
        "max_ms": max(values),
    }


def library_path():
    if sys.platform == "darwin":
        return ROOT / "libUniPlot.dylib"
    if sys.platform == "win32":
        return ROOT / "libUniPlot.dll"
    return ROOT / "libUniPlot.so"


def configure_c_api():
    library = ctypes.CDLL(str(library_path()))
    double_pointer = ctypes.POINTER(ctypes.c_double)
    library.uplot_init.restype = ctypes.c_int
    library.uplot_plot_new.argtypes = [ctypes.c_int, ctypes.c_int]
    library.uplot_plot_new.restype = ctypes.c_void_p
    library.uplot_add_line.argtypes = [ctypes.c_void_p, double_pointer,
                                       double_pointer, ctypes.c_size_t,
                                       ctypes.c_char_p, ctypes.c_float]
    library.uplot_add_line.restype = ctypes.c_int
    library.uplot_plot_to_json.argtypes = [ctypes.c_void_p,
                                           ctypes.POINTER(ctypes.c_void_p),
                                           ctypes.POINTER(ctypes.c_size_t)]
    library.uplot_plot_to_json.restype = ctypes.c_int
    library.uplot_plot_from_json.argtypes = [ctypes.POINTER(ctypes.c_uint8),
                                             ctypes.c_size_t, ctypes.c_int,
                                             ctypes.c_int]
    library.uplot_plot_from_json.restype = ctypes.c_void_p
    library.uplot_buffer_free.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    library.uplot_plot_free.argtypes = [ctypes.c_void_p]
    if library.uplot_init() != 0:
        raise RuntimeError("uplot_init failed")
    return library


def c_payload(library, xs, ys):
    handle = library.uplot_plot_new(800, 500)
    if not handle:
        raise RuntimeError("uplot_plot_new failed")
    try:
        if library.uplot_add_line(handle, xs, ys, len(xs), b"#3366cc", 2.0):
            raise RuntimeError("uplot_add_line failed")
        output = ctypes.c_void_p()
        length = ctypes.c_size_t()
        if library.uplot_plot_to_json(handle, ctypes.byref(output),
                                      ctypes.byref(length)):
            raise RuntimeError("uplot_plot_to_json failed")
        try:
            return ctypes.string_at(output, length.value)
        finally:
            library.uplot_buffer_free(output, length)
    finally:
        library.uplot_plot_free(handle)


def main():
    iterations = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    point_count = int(sys.argv[2]) if len(sys.argv) > 2 else 100_000
    warmups = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    values_x = [index / 25.0 for index in range(point_count)]
    values_y = [math.sin(x) + 0.02 * x for x in values_x]
    array_type = ctypes.c_double * point_count
    xs, ys = array_type(*values_x), array_type(*values_y)

    library = configure_c_api()
    raw_payload = c_payload(library, xs, ys)
    payload_array = (ctypes.c_uint8 * len(raw_payload)).from_buffer_copy(
        raw_payload)
    python_plot = uniplot.Plot(800, 500).line(values_x, values_y)
    python_payload = python_plot.to_json()
    if raw_payload != python_payload.encode("utf-8"):
        raise RuntimeError("C and Python bindings produced different PlotSpec JSON")
    c_encode, c_decode, py_encode, py_decode = [], [], [], []
    guard = 0

    for iteration in range(iterations + warmups):
        handle = library.uplot_plot_new(800, 500)
        if not handle or library.uplot_add_line(
                handle, xs, ys, point_count, b"#3366cc", 2.0):
            raise RuntimeError("C benchmark setup failed")
        output = ctypes.c_void_p()
        length = ctypes.c_size_t()
        started = time.perf_counter_ns()
        status = library.uplot_plot_to_json(handle, ctypes.byref(output),
                                            ctypes.byref(length))
        c_encode_ms = (time.perf_counter_ns() - started) / 1_000_000
        library.uplot_plot_free(handle)
        if status: raise RuntimeError("C JSON encode failed")
        guard += length.value
        library.uplot_buffer_free(output, length)

        started = time.perf_counter_ns()
        decoded = library.uplot_plot_from_json(
            payload_array, len(raw_payload), 800, 500)
        c_decode_ms = (time.perf_counter_ns() - started) / 1_000_000
        if not decoded: raise RuntimeError("C JSON decode failed")
        library.uplot_plot_free(decoded)

        started = time.perf_counter_ns()
        encoded = python_plot.to_json()
        py_encode_ms = (time.perf_counter_ns() - started) / 1_000_000
        started = time.perf_counter_ns()
        restored = uniplot.Plot.from_json(python_payload, 800, 500)
        py_decode_ms = (time.perf_counter_ns() - started) / 1_000_000
        guard += len(encoded) + int(restored is not None)

        if iteration >= warmups:
            c_encode.append(c_encode_ms); c_decode.append(c_decode_ms)
            py_encode.append(py_encode_ms); py_decode.append(py_decode_ms)

    print(json.dumps({
        "iterations": iterations, "points": point_count,
        "warmup_iterations": warmups,
        "c_json_bytes": len(raw_payload),
        "python_json_bytes": len(python_payload.encode("utf-8")),
        "stages": {
            "ctypes_c_abi_json_encode": summary(c_encode),
            "ctypes_c_abi_json_decode": summary(c_decode),
            "python_json_encode": summary(py_encode),
            "python_json_decode": summary(py_decode),
        },
        "guard": guard,
    }))


if __name__ == "__main__":
    main()
