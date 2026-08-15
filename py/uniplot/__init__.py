# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Python interface to the UniPlot pure-Nim plotting engine."""
from ._core import (
    LINE_DASHED,
    LINE_DOT_DASH,
    LINE_DOTTED,
    LINE_LONG_DASH,
    LINE_SOLID,
    MARKER_CIRCLE,
    MARKER_CROSS,
    MARKER_DIAMOND,
    MARKER_PLUS,
    MARKER_SQUARE,
    MARKER_TRIANGLE,
    MISSING_BREAK,
    MISSING_DROP,
    MISSING_REJECT,
    Plot,
    abi_version,
    version,
)

__version__ = version()
__all__ = [
    "LINE_DASHED", "LINE_DOT_DASH", "LINE_DOTTED", "LINE_LONG_DASH",
    "LINE_SOLID", "MARKER_CIRCLE", "MARKER_CROSS", "MARKER_DIAMOND",
    "MARKER_PLUS", "MARKER_SQUARE", "MARKER_TRIANGLE", "Plot",
    "MISSING_BREAK", "MISSING_DROP", "MISSING_REJECT",
    "abi_version", "version", "__version__",
]
