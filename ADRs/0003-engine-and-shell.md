<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0003: UniPlot engine and consumer boundary

- Status: Accepted
- Date: 2026-07-15
- Scope: UniPlot native and Python consumers

## Decision

- **Engine**: the pure-Nim plotting library and `src/UniPlot/c_api.nim`, built
  as `libUniPlot.a` or the platform shared library. No UI lives in the engine.
- **Consumers**: applications link the C ABI or import Nim/Python and own
  windows, event loops, interaction and platform integration.
- **C header** (`include/UniPlot.h`): hand-written, kept in sync with `c_api.nim`.
  `tests/c` links the header against the lib — a renamed/retyped symbol fails
  to link, so the C test is the ABI drift detector. (`--header:X.h` auto-gen is
  not used.)
- `--mm:arc`: deterministic memory model for foreign callers (no cycle
  collector). `--noMain`: no `NimMain()` call needed from C.
- **Python binding**: Cython over the shared library, with an origin-relative
  runtime search path.
