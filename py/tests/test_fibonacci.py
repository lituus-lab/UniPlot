# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import pytest
import unitemplate


def test_version():
    assert unitemplate.version() == "0.1.0"
    assert unitemplate.__version__ == "0.1.0"


@pytest.mark.parametrize("n,want", [
    (0, 0), (1, 1), (2, 1), (10, 55), (20, 6765),
    (50, 12586269025), (92, 7540113804746346429),
])
def test_known_values(n, want):
    assert unitemplate.fibonacci(n) == want


def test_max_in_range():
    assert unitemplate.fibonacci(92) == 7540113804746346429 > 0


def test_out_of_range_raises():
    with pytest.raises(ValueError):
        unitemplate.fibonacci(-1)
    with pytest.raises(ValueError):
        unitemplate.fibonacci(93)


def test_non_int_raises():
    with pytest.raises(TypeError):
        unitemplate.fibonacci(10.0)
