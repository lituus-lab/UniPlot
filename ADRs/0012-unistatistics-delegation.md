<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0012: Delegate statistical definitions to UniStatistics

- Status: Accepted
- Date: 2026-08-21

## Decision

UniPlot owns filtering, retained plotting summaries, histogram geometry and
visual recipes. Type-7 quantiles and range-safe means delegate to
UniStatistics. UniPlot must not maintain a second numerical implementation of
those definitions.

## Consequences

Plot-facing functions continue to ignore non-finite observations before the
strict UniStatistics call and continue raising `PlotError` at their public
validation boundary. Public UniPlot result types and serialized plots remain
unchanged.
