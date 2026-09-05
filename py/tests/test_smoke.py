# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""What an installed wheel must do with nothing else present.

Copied outside the checkout by CI to prove the package stands alone, so it
touches no repository file. Rendering is deliberately absent: a font is the
caller's to supply and the library ships none, which makes it the one thing a
standalone check cannot exercise.
"""
import json

import uniplot


def test_the_wheel_reports_its_version():
    assert uniplot.__version__ == "1.0.0"
    assert uniplot.abi_version() == 1


def test_a_plot_can_be_built_and_serialised():
    plot = uniplot.Plot(320, 240).line([0, 1, 2], [1, 3, 2]).title("smoke")
    document = json.loads(plot.to_json())
    assert document["schema"] == "org.lituus-lab.uniplot.plot-spec"
    assert document["version"] == 1
    restored = uniplot.Plot.from_json(json.dumps(document))
    assert json.loads(restored.to_json()) == document


def test_impossible_dimensions_are_refused():
    for width, height in ((0, 240), (320, 0), (-1, -1)):
        try:
            uniplot.Plot(width, height)
        except ValueError:
            continue
        raise AssertionError(f"{width}x{height} was accepted")
