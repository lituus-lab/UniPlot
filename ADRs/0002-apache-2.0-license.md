<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0002: Apache License 2.0 for UniPlot

- Status: Accepted
- Date: 2026-07-15
- Scope: UniPlot sources and distributions

## Decision

UniPlot is Apache-2.0. The license covers the Nim engine, CLI, C header, Python
binding, examples and documentation. NimContracts retains its upstream MIT
license; the other Uni* dependencies retain the licenses in their packages.

The repository ships `LICENSE`, `NOTICE`, and DCO contribution rules.
Apache-2.0 provides the explicit patent grant required for downstream native
and Python distributions.
