# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import json
import math
import statistics
import sys
import time

import plotly
import plotly.graph_objects as go


def describe(values):
    return {
        "mean_ms": statistics.fmean(values),
        "stdev_ms": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min_ms": min(values),
        "max_ms": max(values),
    }


def make_figure(xs, ys):
    figure = go.Figure(go.Scatter(
        x=xs, y=ys, mode="lines+markers",
        line={"color": "#3366cc", "width": 2},
        marker={"color": "#cc3344", "size": 2}))
    figure.update_layout(width=800, height=500, title="Rosetta benchmark",
                         xaxis_title="x", yaxis_title="y")
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

    # Fail before timing when the optional static image engine is unavailable.
    reference.to_image(format="svg", width=800, height=500)
    for iteration in range(iterations + warmups):
        started = time.perf_counter_ns()
        figure = make_figure(xs, ys)
        construct_ms = (time.perf_counter_ns() - started) / 1_000_000

        started = time.perf_counter_ns()
        svg_bytes = reference.to_image(format="svg", width=800, height=500)
        svg_ms = (time.perf_counter_ns() - started) / 1_000_000
        started = time.perf_counter_ns()
        png_bytes = reference.to_image(format="png", width=800, height=500)
        png_ms = (time.perf_counter_ns() - started) / 1_000_000
        guard ^= len(svg_bytes) ^ len(png_bytes) ^ len(figure.data)

        if iteration >= warmups:
            construct.append(construct_ms)
            svg.append(svg_ms)
            png.append(png_ms)

    print(json.dumps({
        "provider": "Plotly",
        "version": plotly.__version__,
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
