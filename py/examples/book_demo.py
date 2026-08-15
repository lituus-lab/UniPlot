# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from pathlib import Path
import sys

import uniplot


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit("usage: book_demo.py FONT OUTPUT.svg OUTPUT.png")
    font, svg_path, png_path = map(Path, sys.argv[1:])
    x = [0, 1, 2, 3, 4, 5]
    y = [1.2, 2.2, 1.8, 3.7, 3.1, 4.6]
    figure = (
        uniplot.Plot(800, 500)
        .line(x, y, color="#267a5e", width=2.5,
              style=uniplot.LINE_DASHED)
        .scatter(x[1:-1], y[1:-1], color="#dc7c28", radius=5.0,
                 shape=uniplot.MARKER_CROSS)
        .title("UniPlot Python binding")
    )
    svg_path.write_bytes(figure.svg(font))
    png_path.write_bytes(figure.png(font))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
