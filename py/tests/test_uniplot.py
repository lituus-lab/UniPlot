# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from pathlib import Path
import pytest
import uniplot

FONT = Path(__file__).parents[2] / "tests" / "DejaVuSans.ttf"

def test_version():
    assert uniplot.__version__ == "1.0.0"
    assert uniplot.abi_version() == 1

def test_plot_renders_svg_and_png():
    plot = uniplot.Plot(320, 240).line([0, 1, 2], [1, 3, 2]).scatter(
        [0, 1, 2], [1, 3, 2], color="#cc3333").title("Python")
    assert plot.svg(FONT).startswith(b"<svg")
    assert plot.png(FONT).startswith(b"\x89PNG")

def test_series_shape_is_checked():
    with pytest.raises(ValueError):
        uniplot.Plot().line([1], [1, 2])

