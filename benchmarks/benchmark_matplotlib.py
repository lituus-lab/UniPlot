# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import io
import json
import math
import os
import statistics
import sys
import tempfile
import time

os.environ.setdefault("MPLBACKEND", "Agg")
os.environ.setdefault("MPLCONFIGDIR", tempfile.mkdtemp(prefix="uniplot-mpl-"))
import matplotlib
from matplotlib import pyplot as plt


def describe(values):
    return {
        "mean_ms": statistics.fmean(values),
        "stdev_ms": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min_ms": min(values),
        "max_ms": max(values),
    }


def make_figure(xs, ys):
    figure, axis = plt.subplots(figsize=(8, 5), dpi=100)
    axis.plot(xs, ys, color="#3366cc", linewidth=2)
    axis.scatter(xs, ys, color="#cc3344", s=4)
    axis.set(title="Rosetta benchmark", xlabel="x", ylabel="y")
    return figure


def main():
    iterations = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    point_count = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
    warmups = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    xs = [index / 25.0 for index in range(point_count)]
    ys = [math.sin(x) + 0.02 * x for x in xs]
    construct, svg, png = [], [], []
    guard = 0

    reference = make_figure(xs, ys)
    for iteration in range(iterations + warmups):
        started = time.perf_counter_ns()
        figure = make_figure(xs, ys)
        construct_ms = (time.perf_counter_ns() - started) / 1_000_000
        plt.close(figure)

        target = io.BytesIO()
        started = time.perf_counter_ns()
        reference.savefig(target, format="svg")
        svg_ms = (time.perf_counter_ns() - started) / 1_000_000
        guard ^= len(target.getvalue())

        target = io.BytesIO()
        started = time.perf_counter_ns()
        reference.savefig(target, format="png")
        png_ms = (time.perf_counter_ns() - started) / 1_000_000
        guard ^= len(target.getvalue())

        if iteration >= warmups:
            construct.append(construct_ms)
            svg.append(svg_ms)
            png.append(png_ms)
    plt.close(reference)

    print(json.dumps({
        "provider": "Matplotlib",
        "version": matplotlib.__version__,
        "iterations": iterations,
        "points": point_count,
        "width": 800,
        "height": 500,
        "warmup_iterations": warmups,
        "stages": {
            "construct_compile": describe(construct),
            "svg_from_compiled_scene": describe(svg),
            "png_from_compiled_scene": describe(png),
        },
        "guard": guard,
    }))


if __name__ == "__main__":
    main()
