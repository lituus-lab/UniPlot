<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: UniPlot repository conventions

- Status: Accepted
- Date: 2026-08-15
- Scope: UniPlot source and distributions

## Layout

```text
src/UniPlot/       data, scales, statistics, grammar, scene, guides, render
src/UniPlot.nim    public umbrella module
bin/uniplot_cli.nim
include/UniPlot.h  hand-written C header using uplot_ symbols
tests/             Nim and C conformance tests
py/                Cython binding and pytest
book/              executable examples
```

## Conventions

- Public errors are typed; the C ABI translates them to status codes.
- Public dimensions and coordinates reject non-finite values.
- Ordered sequences define draw, layer and guide order.
- Core types contain no backend or window-system handles.
- English comments are terse and explain one relevant fact.
- Every executable tutorial block is compiled and run.
- C symbols use `uplot_`; the library is `libUniPlot`.

## Gates

Debug and release Nim tests, DAG validation, C ABI consumers, Python consumers,
distribution artefacts, executable documentation and renderer fixtures all run
before a release.
