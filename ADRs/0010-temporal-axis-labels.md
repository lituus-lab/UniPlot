<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0010: Deterministic temporal axis labels

- Status: Accepted
- Date: 2026-08-16
- Scope: UniPlot scales, grammar and bindings

## Context

UniPlot already maps numeric values through deterministic linear and logarithmic
transforms. Date/time and duration axes need the same retained geometry, but
their ticks require semantic formatting. Treating formatted dates as categories
would discard numeric spacing, while storing platform-local time-zone state in a
PlotSpec would make serialization and publication non-reproducible.

## Decision

Axis transformation and axis-label semantics remain separate. `ScaleKind`
continues to describe numeric transformation. A new axis-label kind selects
plain numeric, UTC date/time or signed duration labels. Temporal axes require a
linear transform.

UTC values are finite POSIX seconds since 1970-01-01T00:00:00Z. Leap seconds are
not represented. Duration values are finite signed seconds. Both remain numeric
DataFrame columns, so every mark, missing-value policy, explicit domain,
reversal, composition and renderer continues to consume the existing scale and
scene contracts.

Tick placement is deterministic. Durations choose from a documented fixed
second ladder. UTC axes use aligned seconds, minutes, hours and days for short
spans, then calendar-aligned UTC months and years for longer spans. Formatting
is selected from the trained domain span and never reads the host locale or
local time zone.

Schema-v1 JSON stores the additive label kind in each axis scale. Its absence
means numeric labels for backward compatibility. C and Python bindings expose
axis configuration over the same POSIX-second representation; they do not own
or reinterpret caller data.

## Consequences

- Temporal axes share all CPU, SVG and WGPU geometry and differ only in tick
  values and text.
- Serialized plots are locale-independent and deterministic across machines.
- Callers needing civil-time ambiguity rules convert to UTC before UniPlot.
- Additional numeric transforms and polar coordinates remain independent
  roadmap items rather than being hidden inside this change.
