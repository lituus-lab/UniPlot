# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniPlot — scientific visualisation for the lituus-lab Uni* family.

version       = "1.0.0"
author        = "lituus-lab"
description   = "Pure-Nim scientific visualisation engine (Nim + C-ABI + Python)"
license       = "Apache-2.0"
srcDir        = "src"

requires "nim >= 2.0.0"
requires "https://github.com/lbartoletti/NimContracts#main"
requires "https://github.com/lituus-lab/UniLinalg#main"
requires "https://github.com/lituus-lab/UniMath#main"
requires "https://github.com/lituus-lab/UniColor#main"
requires "https://github.com/lituus-lab/UniImage#main"
requires "https://github.com/lituus-lab/UniVector#main"
requires "https://github.com/lituus-lab/UniGlyph#main"

# Book-only dependencies, pinned to the compatible upstream releases used by
# UniGraph. They never enter the library core dependency graph.
taskRequires "book", "https://github.com/pietroppeter/nimib#v0.4.1",
    "https://github.com/pietroppeter/nimibook#v0.4.0"
taskRequires "docs", "https://github.com/pietroppeter/nimib#v0.4.1",
    "https://github.com/pietroppeter/nimibook#v0.4.0"
taskRequires "docsDeps", "https://github.com/pietroppeter/nimib#v0.4.1",
    "https://github.com/pietroppeter/nimibook#v0.4.0"

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"

task docsDeps, "Install the docs toolchain (nimib + nimibook)":
  echo "nimib/nimibook installed."

task book, "Build the multipage nimib book (needs nimib + nimibook)":
  # Each Nim chapter is compiled and run: an API drift fails the build.
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim clean"
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim build"
    cpFile "__site/preface.html", "__site/index.html"

task bindingBookDemos, "Regenerate book plots through the C and Python bindings":
  mkDir "book/assets"
  mkDir "book/assets/generated"
  exec "nimble clibStatic"
  let cDemo = when defined(windows): "build/book_demo.exe" else:
    "build/book_demo"
  let cCompiler = when defined(windows): "gcc" else: "cc"
  exec cCompiler & " -Iinclude -O2 -Wall -Wextra -std=c11 -o " & cDemo &
       " examples/c/book_demo.c libUniPlot.a -lz"
  exec cDemo & " tests/DejaVuSans.ttf book/assets/generated/c_binding.svg" &
       " book/assets/generated/c_binding.png"
  exec "nimble buildCython"
  withDir "py":
    exec "python3 -m examples.book_demo ../tests/DejaVuSans.ttf" &
         " ../book/assets/generated/python_binding.svg" &
         " ../book/assets/generated/python_binding.png"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  # Generate each public module explicitly. `--project` forces a JS search
  # index and fails on Nim distributions (notably Homebrew) that omit the
  # compiler's optional tools/dochack source.
  for module in ["common", "data", "scales", "stats", "grammar", "scene",
      "guides", "render", "render/wgpu"]:
    exec "nim doc --index:off --outdir:pages/api --hints:off src/UniPlot/" &
         module & ".nim"
  exec "nim doc --index:off --outdir:pages/api --hints:off src/UniPlot.nim"
  exec "nimble book"
  # Nimibook is the landing site; the generated reference remains under api/.
  cpDir "book/__site", "pages"

# One entry per Nim test so every task (test, testRelease, testCi*,
# coverage) compiles the same set from a single source of truth.
const testBins = [
  ("test_version", "test_version"),
  ("test_data", "test_data"),
  ("test_scales", "test_scales"),
  ("test_stats", "test_stats"),
  ("test_serialization", "test_serialization"),
  ("test_plot", "test_plot"),
  ("test_render", "test_render"),
  ("test_wgpu_boundary", "test_wgpu_boundary"),
]

task test, "Nim tests (debug, contracts active)":
  for (name, src) in testBins:
    exec "nim c -r --path:src -o:build/" & name & " tests/" & src & ".nim"

task testRelease, "Nim tests (release, contracts compiled away)":
  for (name, src) in testBins:
    exec "nim c -r -d:release --path:src -o:build/" & name & "_rel tests/" & src & ".nim"

task testCi, "Nim tests (CI subset, debug)":
  for (name, src) in testBins:
    exec "nim c -r --path:src -o:build/" & name & " tests/" & src & ".nim"

task testCiRelease, "Nim tests (CI subset, release)":
  for (name, src) in testBins:
    exec "nim c -r -d:release --path:src -o:build/" & name & "_rel tests/" & src & ".nim"

task testAll, "debug + release + C ABI":
  exec "nimble test"
  exec "nimble testRelease"
  exec "nimble ctest"

task example, "Nim demo (print-only; no file I/O)":
  exec "nim c -r --path:src -o:build/demo examples/demo.nim"

task benchmark, "Reproducible UniPlot/Matplotlib off-screen benchmark":
  exec "python3 benchmarks/run_benchmarks.py"

task benchmarkScales, "Run cross-library 10^3, 10^5, and 10^6-point workloads":
  exec "python3 benchmarks/run_workload_suite.py"

task benchmarkThermals, "Compare cold processes with warmed provider stages":
  exec "python3 benchmarks/run_thermal_suite.py"

task benchmarkDeps, "Install isolated Python/R/Julia benchmark dependencies":
  exec "python3 benchmarks/install_deps.py"

task uniplot, "Build the uniplot CLI (inspect and render PNG/SVG)":
  exec "nim c --path:src -o:bin/uniplot bin/uniplot_cli.nim"

task wgpuCheck, "Compile the optional WGPU scene/resource boundary (no native runtime)":
  exec "nim check --path:src src/UniPlot/render/wgpu.nim"

task wgpuDeps, "Install pinned wgpu-native into the ignored .deps directory":
  exec "nim c -r -d:ssl --path:src -o:build/install_wgpu" &
       " tools/install_wgpu.nim"

task wgpuTest, "Create a real native WGPU device (run wgpuDeps first)":
  let
    platformName = when defined(macosx): "macos" else:
      when defined(windows): "windows" else: "linux"
    archName = when defined(arm64): "aarch64" else: "x86_64"
    targetName = if platformName == "windows": platformName & "-" &
      archName & "-msvc" else: platformName & "-" & archName
    libraryName = when defined(macosx): "libwgpu_native.dylib" else:
      when defined(windows): "wgpu_native.dll" else: "libwgpu_native.so"
    libraryPath = ".deps/wgpu/29.0.1.1/" & targetName & "/lib/" &
      libraryName
  putEnv("UNIPLOT_WGPU_LIBRARY", getCurrentDir() & "/" & libraryPath)
  exec "nim c -r --path:src -o:build/test_wgpu_native" &
       " tests/test_wgpu_boundary.nim"

task wgpuBenchmark, "Benchmark warm WGPU frames with explicit readback":
  let
    platformName = when defined(macosx): "macos" else:
      when defined(windows): "windows" else: "linux"
    archName = when defined(arm64): "aarch64" else: "x86_64"
    targetName = if platformName == "windows": platformName & "-" &
      archName & "-msvc" else: platformName & "-" & archName
    libraryName = when defined(macosx): "libwgpu_native.dylib" else:
      when defined(windows): "wgpu_native.dll" else: "libwgpu_native.so"
    libraryPath = ".deps/wgpu/29.0.1.1/" & targetName & "/lib/" &
      libraryName
  putEnv("UNIPLOT_WGPU_LIBRARY", getCurrentDir() & "/" & libraryPath)
  exec "nim c -r -d:release --path:src -o:build/benchmark_wgpu" &
       " benchmarks/benchmark_wgpu.nim"

# Nim takes `-o:` literally and appends no platform extension.
const
  sharedLib =
    when defined(windows): "libUniPlot.dll"
    elif defined(macosx): "libUniPlot.dylib"
    else: "libUniPlot.so"
  staticLib = "libUniPlot.a"  # MinGW `ar` on Windows, so `.a` everywhere.

  # @rpath install_name, so the copy bundled in the wheel is found at import.
  macArgs =
    when defined(macosx): " --passL:\"-Wl,-install_name,@rpath/" & sharedLib & "\""
    else: ""

task clib, "C shared library":
  exec "nim c --nimcache:build/nimcache-clib --app:lib --noMain --mm:arc" &
       " -d:release -o:" & sharedLib & macArgs &
       " src/UniPlot/c_api.nim"

task clibStatic, "C static library":
  exec "nim c --nimcache:build/nimcache-clib-static --app:staticlib --noMain" &
       " --mm:arc -d:release -o:" & staticLib &
       " src/UniPlot/c_api.nim"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output. MSVC's
  # linker takes the lib name verbatim (no `lib` prefix, unlike MinGW), so the
  # output is `UniPlot.lib` — the intentional exception to the sharedLib /
  # staticLib naming. setup.py's Windows branch matches: `LIB_NAME =
  # "UniPlot.lib"` and `libraries=["UniPlot"]`.
  exec "nim c --nimcache:build/nimcache-clib-msvc --cc:vcc --app:staticlib" &
       " --noMain --mm:arc -d:release" &
       " -o:UniPlot.lib src/UniPlot/c_api.nim"

# Nim's MinGW toolchain names it mingw32-make.
let makeExe = if findExe("mingw32-make").len > 0: "mingw32-make" else: "make"

# `make -C`, not `cd dir && make`: nimble's exec runs no shell on Windows.
task ctest, "C ABI tests":
  exec "nimble clibStatic"
  exec makeExe & " -C tests/c"

task cexample, "C demo (print-only consumer of the uplot_* ABI)":
  exec "nimble clibStatic"
  exec makeExe & " -C examples/c"

task pyDeps, "Install Python build deps (setuptools, Cython, pytest) if missing":
  exec "python3 -m pip install --break-system-packages --quiet setuptools wheel \"Cython>=3.0.0\" pytest"

# The extension links the vcc static lib on Windows, the shared lib elsewhere.
task pyLib, "Build the library the Python extension links against":
  when defined(windows):
    exec "nimble clibMsvc"
  else:
    exec "nimble clib"

task buildCython, "Cython extension in-place":
  exec "nimble pyLib"
  exec "nimble pyDeps"
  # nimscript `cd` (lib/system/nimscript.nim) changes the VM cwd for the next
  # exec without a shell, so the task works under nimble's no-shell exec on Windows.
  cd "py"
  exec "python3 setup.py build_ext --inplace"
  cd ".."

task pyTest, "Cython extension + pytest":
  exec "nimble buildCython"
  cd "py"
  exec "python3 -m pytest -q"
  cd ".."

task pyWheel, "wheel":
  exec "nimble pyLib"
  exec "nimble pyDeps"
  cd "py"
  exec "python3 -m pip wheel --no-deps --no-build-isolation --wheel-dir dist ."
  cd ".."

task pySdist, "Python source distribution":
  exec "nimble pyDeps"
  cd "py"
  exec "python3 setup.py sdist"
  cd ".."

task coverage, "LCOV + HTML coverage report for the Nim sources (needs lcov)":
  # gcov and lcov driven directly, no coco. Linux and macOS only.
  # --debugger:native attributes lines to the .nim sources, not the generated C.
  # --include keeps stdlib out of the capture, where lcov 2.x aborts on Nim's
  # codegen. Nim's native debugger mapping can still attribute a generated C
  # branch a few lines past the end of its source module. genhtml calls this a
  # `range` error, so suppress that mapping-only diagnostic while preserving
  # every other capture and report failure.
  let cache = "build/covcache"
  rmDir cache
  rmDir "coverage"
  rmFile "lcov.info"
  # Each coverage binary gets its own nimcache subdir. Sharing one nimcache
  # across the differently-instrumented `nim c` builds re-instruments the
  # shared stdlib modules with a different gcov counter layout each time, so
  # when the binaries run they write conflicting `.gcda` to the same paths and
  # lcov aborts on `cannot merge previous GCDA file: mismatched number of
  # counters`. `lcov --capture --directory build/covcache` recurses into the
  # subdirs, so aggregation is unchanged.
  const bins = testBins
  let gcovTool = when defined(macosx): " --gcov-tool tools/llvm-gcov.sh" else: ""
  for (name, src) in bins:
    exec "nim c --path:src --nimcache:" & cache & "/" & name &
         " --debugger:native --passC:--coverage --passL:--coverage" &
         " -o:build/test_cov_" & name & " tests/" & src & ".nim"
    exec "./build/test_cov_" & name
  exec "lcov --capture --directory " & cache & " --base-directory ." &
       " --include \"*/src/UniPlot/*\" --output-file lcov.info --quiet" &
       gcovTool
  exec "genhtml lcov.info --output-directory coverage --legend --quiet" &
       " --ignore-errors range"
  exec "lcov --summary lcov.info"
