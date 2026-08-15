# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Python interface to the UniPlot pure-Nim plotting engine."""
from ._core import Plot, abi_version, version

__version__ = version()
__all__ = ["Plot", "abi_version", "version", "__version__"]

