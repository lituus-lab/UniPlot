# UniTemplate

Reference scaffold cloned to start each `lituus-lab` `Uni*` library. Private
repo (not a public GitHub template). Hello-world: `fibonacci`, in Nim, C ABI,
and Python.

## Layout

```
src/UniTemplate.nim          umbrella module
src/UniTemplate/fibonacci.nim  Nim core (NimContracts)
src/UniTemplate/c_api.nim    C ABI
include/UniTemplate.h        hand-written C header
tests/test_fibonacci.nim     Nim tests
tests/c/                     C ABI test (links the header against the lib)
examples/                    Nim + C demos
py/                          Cython binding + pytest
ADRs/                        0001 DAG, 0002 license, 0003 engine&shell, 0004 conventions
.github/workflows/ci.yml     3-OS Nim matrix + C ABI + Python
```

## Build

```bash
nimble install -y
nimble test           # Nim, debug (contracts active)
nimble testRelease    # Nim, release (contracts compiled away)
nimble testAll        # debug + release + C ABI
nimble ctest          # C ABI: static lib + tests/c
nimble cexample       # C demo
nimble example        # Nim demo
nimble pyTest         # Cython + pytest
nimble coverage       # gcov + lcov -> coverage/
nimble book           # nimib book -> book/index.html
nimble docs           # book + API reference -> pages/
```

## CI

`test`, `cabi` and `python` on ubuntu/macOS/Windows. `consume-cabi` and
`consume-wheel` rebuild against the published artifacts on a machine without Nim,
so what ships is what was tested. `coverage` and `docs` run on ubuntu.

`dco` blocks PRs missing a `Signed-off-by` trailer; `commitizen` blocks PRs whose
commits or title are not [Conventional Commits](https://www.conventionalcommits.org/)
(`CONTRIBUTING.md`).

The same gates run locally with pre-commit: `pip install pre-commit && pre-commit install`
(`CONTRIBUTING.md`).

`docs` publishes to GitHub Pages only from a public repo — the template itself is
private, so that deploy stays skipped here and turns itself on in the engines.

## Clone map

Clone, then rename tokens, then replace `fibonacci.nim` with the domain module(s).

| Template | Clone | Example |
|---|---|---|
| `UniTemplate` | `UniFoo` | `UniAccurate`, `UniMath`, `UniGeom` |
| `unitemplate` | `unifoo` | `uniaccurate`, `unimath`, `unigeom` |
| `ut_` | `<short>_` | `ua_`, `um_`, `ulin_`, `ug_` |
| `libUniTemplate` | `libUniFoo` | `libUniMusic` |
| `UniTemplate.h` | `UniFoo.h` | `UniMusic.h` |

Files to rename: `UniTemplate.nimble`, `src/UniTemplate.nim`, `src/UniTemplate/`,
`include/UniTemplate.h`, `tests/c/test_unitemplate.c` (+ its Makefile target),
`py/unitemplate/`. Then update `LICENSE`/`NOTICE` copyright and the ADR titles.

## AI-assisted contributions

Assistance from AI/LLM tools is welcome on the same terms as any other
contribution.

- **Accountability.** The human contributor is the author and remains fully
  responsible for the change. The DCO sign-off (`Signed-off-by`) is the mechanism:
  by signing you certify the content is yours or properly licensed — this covers
  AI-assisted work, provided you can stand behind it.
- **No third-party contamination.** Ensure AI output introduces no code from a
  third party without a compatible license and attribution. If an LLM reproduced
  protected material, do not submit it.
- **Correctness is yours.** The gates (tests, `nimble lint`, conventional commits,
  pre-commit) catch a lot, but you own the result — review and verify what you
  commit.
- **Atomic commits.** Each commit is one logical change. A PR may stack
  several atomic commits (one per element, say) — one monolithic big-bang
  commit is not.
- **Disclosure.** State in the PR whether AI assistance was used (see the PR
  template). It is not a hard requirement — the DCO remains the gate.

## License

Apache-2.0 (`LICENSE`). DCO sign-off on every commit (`CONTRIBUTING.md`).
