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
        [0, 1, 2], [1, 3, 2], color="#cc3333").title("Python").secondary_y(
            1.8, 32.0, "fahrenheit").annotate_text(
                1.0, 3.0, "peak").annotate_arrow(0.5, 1.5, 1.0, 3.0)
    assert plot.svg(FONT).startswith(b"<svg")
    assert plot.png(FONT).startswith(b"\x89PNG")
    density = uniplot.Plot().histogram(
        [0, 0.5, 1, 2, 3], [0, 1, 3], density=True)
    assert density.svg(FONT).startswith(b"<svg")
    assert plot.clear_secondary_y() is plot
    assert plot.clear_annotations() is plot
    with pytest.raises(ValueError):
        plot.secondary_y(0.0)
    with pytest.raises(ValueError):
        plot.annotate_arrow(1.0, 1.0, 1.0, 1.0)

def test_plot_grid_renders_svg_and_png():
    first = uniplot.Plot().line([0, 1, 2], [1, 3, 2]).title("first")
    second = uniplot.Plot().scatter([0, 1, 2], [2, 1, 3]).title("second")
    assert uniplot.grid_svg(
        [first, second], FONT, columns=2, width=656,
        height=240).startswith(b"<svg")
    assert uniplot.grid_png(
        [first, second], FONT, columns=2, width=656,
        height=240, shared_x=True, shared_y=True).startswith(b"\x89PNG")
    with pytest.raises(ValueError):
        uniplot.grid_svg([], FONT, columns=1)
    with pytest.raises(ValueError):
        uniplot.grid_svg([first], FONT, columns=0)
    with pytest.raises(TypeError):
        uniplot.grid_svg([first, object()], FONT, columns=2)

def test_categorical_facets_render_svg_and_png():
    plot = (uniplot.Plot()
            .line([0, 1, 2, 3], [1, 3, 2, 4])
            .categorical_column(
                "group", (value for value in ["west", "east", "west", "east"]))
            .categorical_column("side", ["left", "right", "right", "right"]))
    assert uniplot.facet_svg(
        plot, "group", FONT, columns=2, width=656, height=240,
        shared_x=True, shared_y=True).startswith(b"<svg")
    assert uniplot.facet_png(
        plot, "group", FONT, columns=2, width=656,
        height=240).startswith(b"\x89PNG")
    assert uniplot.facet_matrix_svg(
        plot, "group", "side", FONT, width=656, height=480,
        shared_x=True, shared_y=True).startswith(b"<svg")
    assert uniplot.facet_matrix_png(
        plot, "group", "side", FONT, width=656,
        height=480).startswith(b"\x89PNG")
    with pytest.raises(ValueError):
        plot.categorical_column("bad", ["short"])
    with pytest.raises(RuntimeError):
        uniplot.facet_svg(plot, "missing", FONT, columns=2)

def test_series_shape_is_checked():
    with pytest.raises(ValueError):
        uniplot.Plot().line([1], [1, 2])

def test_grouped_boxplots_render_and_validate_empty_plot_contract():
    plot = uniplot.Plot().boxplot(
        ["a", "a", "a", "a", "a", "b", "b"],
        [1, 2, 3, 4, 100, 8, 9])
    assert plot.svg(FONT).startswith(b"<svg")
    assert plot.png(FONT).startswith(b"\x89PNG")
    with pytest.raises(ValueError):
        plot.boxplot(["a"], [1])
    with pytest.raises(ValueError):
        uniplot.Plot().boxplot(["a"], [1, 2])
    with pytest.raises(ValueError):
        uniplot.Plot().boxplot(["a"], [1], whisker_length=-1)
    with pytest.raises(ValueError):
        uniplot.Plot().boxplot(["a"], [float("nan")])

def test_categorical_heatmaps_render_and_validate_empty_plot_contract():
    plot = uniplot.Plot().heatmap(
        ["left", "right", "left", "left"],
        ["north", "north", "south", "north"],
        [1, 4, float("nan"), 3])
    assert plot.svg(FONT).startswith(b"<svg")
    assert plot.png(FONT).startswith(b"\x89PNG")
    with pytest.raises(ValueError):
        plot.heatmap(["left"], ["north"], [1])
    with pytest.raises(ValueError):
        uniplot.Plot().heatmap(["left"], ["north", "south"], [1])
    with pytest.raises(ValueError):
        uniplot.Plot().heatmap(["left"], ["north"], [1], aggregation=999)
    all_missing = uniplot.Plot().heatmap(
        ["left"], ["north"], [float("nan")])
    with pytest.raises(RuntimeError):
        all_missing.svg(FONT)

def test_explicit_break_histograms_render_and_validate_empty_plot_contract():
    plot = uniplot.Plot().histogram(
        [-1, 0, 0.5, 1, 2, 3, float("nan")], [0, 1, 2],
        color="#267a5e")
    assert plot.svg(FONT).startswith(b"<svg")
    assert plot.png(FONT).startswith(b"\x89PNG")
    with pytest.raises(ValueError):
        plot.histogram([1], [0, 1])
    with pytest.raises(ValueError):
        uniplot.Plot().histogram([], [0, 1])
    with pytest.raises(ValueError):
        uniplot.Plot().histogram([1], [0])
    with pytest.raises(ValueError):
        uniplot.Plot().histogram([1], [0, 0])

def test_grouped_aggregates_render_and_validate_empty_plot_contract():
    plot = uniplot.Plot().aggregate(
        ["beta", "alpha", "beta", "empty"],
        [1, 4, 3, float("nan")], aggregation=uniplot.AGG_MEAN,
        color="#9b4d96")
    assert plot.svg(FONT).startswith(b"<svg")
    assert plot.png(FONT).startswith(b"\x89PNG")
    with pytest.raises(ValueError):
        plot.aggregate(["beta"], [1])
    with pytest.raises(ValueError):
        uniplot.Plot().aggregate(["beta"], [1, 2])
    with pytest.raises(ValueError):
        uniplot.Plot().aggregate(["beta"], [1], aggregation=999)
    with pytest.raises(ValueError):
        uniplot.Plot().aggregate([""], [1])
    with pytest.raises(ValueError):
        uniplot.Plot().aggregate(["beta"], [1], color="not-a-color")
    all_missing = uniplot.Plot().aggregate(["empty"], [float("nan")])
    assert all_missing.svg(FONT).startswith(b"<svg")
    counted_missing = uniplot.Plot().aggregate(
        ["empty"], [float("nan")], aggregation=uniplot.AGG_COUNT)
    assert counted_missing.svg(FONT).startswith(b"<svg")

def test_line_styles_and_marker_shapes_are_exposed():
    plot = uniplot.Plot().line(
        [0, 1, 2], [1, 2, 1], style=uniplot.LINE_DOT_DASH).scatter(
            [0, 1], [1, 2], shape=uniplot.MARKER_DIAMOND)
    assert plot.svg(FONT).startswith(b"<svg")
    with pytest.raises(ValueError):
        uniplot.Plot().line([0, 1], [1, 2], style=999)
    with pytest.raises(ValueError):
        uniplot.Plot().scatter([0, 1], [1, 2], shape=999)

def test_missing_value_policies_are_exposed():
    broken = uniplot.Plot().line([0, 1, 2], [1, float("nan"), 2])
    assert broken.svg(FONT).startswith(b"<svg")
    dropped = uniplot.Plot().scatter(
        [0, 1, 2], [1, float("inf"), 2], missing=uniplot.MISSING_DROP)
    assert dropped.svg(FONT).startswith(b"<svg")
    rejecting = uniplot.Plot().line(
        [0, 1, 2], [1, float("nan"), 2], missing=uniplot.MISSING_REJECT)
    with pytest.raises(RuntimeError):
        rejecting.svg(FONT)
    with pytest.raises(ValueError):
        uniplot.Plot().line([0, 1], [1, 2], missing=999)

def test_versioned_json_round_trip():
    original = uniplot.Plot(320, 240).line([1, 2, 3], [2, 4, 3]).title(
        "Python JSON")
    payload = original.to_json()
    restored = uniplot.Plot.from_json(payload, 320, 240)
    assert restored.to_json() == payload
    assert restored.svg(FONT).startswith(b"<svg")
    assert uniplot.Plot.from_json(payload.encode("utf-8")).to_json() == payload
    with pytest.raises(ValueError):
        uniplot.Plot.from_json('{"version": 999}')
    with pytest.raises(TypeError):
        uniplot.Plot.from_json(42)
