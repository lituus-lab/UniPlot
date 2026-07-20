<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: UniTemplate conventions

- Status: Accepted
- Date: 2026-07-15
- Scope: UniTemplate and the conventions every clone inherits

## Layout

```
UniTemplate.nimble          package + tasks
config.nims                 arch-conditional build flags
src/UniTemplate.nim         umbrella
src/UniTemplate/fibonacci.nim  hello-world (NimContracts)
src/UniTemplate/c_api.nim   C ABI
include/UniTemplate.h       hand-written C header
tests/ tests/c/             Nim + C ABI tests
examples/                   Nim + C demos
py/                         Cython binding + pytest
book/                       nimib placeholder
ADRs/                       0001–0004
.github/workflows/ci.yml    3-OS Nim + C ABI + Python
LICENSE NOTICE CONTRIBUTING.md SECURITY.md .gitignore README.md AGENTS.md CLAUDE.md
```

## Naming

- Nim package/module: `UniFoo` (PascalCase).
- C library: `libUniFoo`. C header: `UniFoo.h`.
- C symbol prefix: the lib's short token (`ut_` here; `ua_`, `um_`, `ulin_`…).

## Conventions

- Hello-world `fibonacci`, exercised in Nim + C ABI + Python.
- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. The C ABI never raises — it clamps out-of-range input.
- A postcondition is cheaper than the body; it never re-derives the result.
- English comments, terse, describe what is done. No "deprecated".
- Internal `types/` never imports `algorithms/`; `io/` → `types/` only.

## CI gates

- `nimble testCi` + `testCiRelease` on ubuntu/macOS/Windows.
- `nimble ctest` on linux/macOS.
- `nimble pyTest` on linux.

## Clone map

| Template | Clone |
|---|---|
| `UniTemplate` | `UniFoo` |
| `unitemplate` | `unifoo` |
| `ut_` | `<short>_` |
| `libUniTemplate` | `libUniFoo` |
| `UniTemplate.h` | `UniFoo.h` |

After the rename, replace `fibonacci.nim` with the domain module(s), update the
umbrella exports, the C ABI + header + C test + Python `_core.pyx`, and run the
gates.
