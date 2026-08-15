# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from pathlib import Path
import sys

import uniplot


def main() -> int:
    if len(sys.argv) != 12:
        raise SystemExit(
            "usage: book_demo.py FONT MATRIX.svg MATRIX.png BOX.svg BOX.png "
            "HEAT.svg HEAT.png HIST.svg HIST.png GROUPED.svg GROUPED.png")
    (font, svg_path, png_path, box_svg_path, box_png_path,
     heat_svg_path, heat_png_path, histogram_svg_path,
     histogram_png_path, grouped_svg_path, grouped_png_path) = map(
        Path, sys.argv[1:])
    x = [0, 1, 2, 3, 4, 5]
    y = [1.2, 2.2, 1.8, 3.7, 3.1, 4.6]
    figure = (
        uniplot.Plot(800, 500)
        .line(x, y, color="#267a5e", width=2.5,
              style=uniplot.LINE_DASHED)
        .scatter(x[1:-1], y[1:-1], color="#dc7c28", radius=5.0,
                 shape=uniplot.MARKER_CROSS)
        .title("Py")
        .secondary_y(1.8, 32.0, "F")
        .annotate_text(3.15, 4.25, "peak", color="#7a3db8")
        .annotate_arrow(3.75, 4.15, 3.0, 3.7, color="#7a3db8")
    )
    figure = uniplot.Plot.from_json(figure.to_json(), 800, 500)
    figure.categorical_column(
        "region", ["west", "west", "west", "east", "east", "east"])
    figure.categorical_column(
        "phase", ["early", "late", "late", "late", "late", "late"])
    svg_path.write_bytes(uniplot.facet_matrix_svg(
        figure, "region", "phase", font, width=1000, height=700, gap=16,
        shared_x=True, shared_y=True))
    png_path.write_bytes(uniplot.facet_matrix_png(
        figure, "region", "phase", font, width=1000, height=700, gap=16,
        shared_x=True, shared_y=True))
    boxes = (uniplot.Plot(760, 440)
             .boxplot(
                 ["control"] * 5 + ["treated"] * 5,
                 [1.0, 1.4, 1.8, 2.1, 5.2, 2.0, 2.4, 2.7, 3.0, 3.3],
                 color="#267a5e", outlier_color="#d64255")
             .title("Python grouped boxplot"))
    box_svg_path.write_bytes(boxes.svg(font))
    box_png_path.write_bytes(boxes.png(font))
    heatmap = (uniplot.Plot(760, 440)
               .heatmap(
                   ["morning", "morning", "afternoon", "evening", "evening"],
                   ["north", "north", "north", "north", "south"],
                   [2.0, 4.0, 7.0, 5.0, 9.0],
                   aggregation=uniplot.AGG_MEAN)
               .title("Python categorical heatmap"))
    heat_svg_path.write_bytes(heatmap.svg(font))
    heat_png_path.write_bytes(heatmap.png(font))
    histogram = (uniplot.Plot(760, 440)
                 .histogram(
                     [-1.0, 0.0, 0.3, 0.9, 1.0, 1.4, 2.0, 3.0],
                     [0.0, 0.5, 1.0, 2.0], color="#267a5e", density=True)
                 .title("Python variable-width density"))
    histogram_svg_path.write_bytes(histogram.svg(font))
    histogram_png_path.write_bytes(histogram.png(font))
    grouped = (uniplot.Plot(760, 440)
               .aggregate(
                   ["beta", "alpha", "beta", "empty", "alpha"],
                   [1.0, 4.0, 3.0, float("nan"), 8.0],
                   aggregation=uniplot.AGG_MEAN, color="#9b4d96")
               .title("Python grouped mean"))
    grouped_svg_path.write_bytes(grouped.svg(font))
    grouped_png_path.write_bytes(grouped.png(font))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
