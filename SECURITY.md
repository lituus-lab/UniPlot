<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Security Policy

Report vulnerabilities privately to the maintainer. Include the affected
UniPlot version, input data or font, output backend and a minimal reproducer.

Only the latest released line is supported. The 1.x C ABI uses the `uniplot_`
prefix and never lets a Nim exception unwind into foreign code.

Plot dimensions, data lengths, colour strings and output pointers are validated
at public boundaries. Font parsing is delegated to UniGlyph. UniPlot performs
no network access, implicit file discovery or shader compilation in its core.
