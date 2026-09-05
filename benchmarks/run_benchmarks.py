# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
RESULTS = ROOT / "benchmarks" / "results"
PYTHON_ENV = BUILD / "benchmark-python"
R_LIBRARY = BUILD / "benchmark-r-library"
JULIA_PROJECT = ROOT / "benchmarks" / "julia"


def command_json(command, provider, env=None):
    started = time.perf_counter_ns()
    try:
        completed = subprocess.run(command, cwd=ROOT, check=True, env=env,
                                   capture_output=True, text=True)
        result = json.loads(completed.stdout.strip().splitlines()[-1])
    except (FileNotFoundError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        detail = getattr(error, "stderr", "") or str(error)
        result = {"provider": provider, "available": False,
                  "reason": detail.strip()}
    result["process_wall_ms"] = (time.perf_counter_ns() - started) / 1_000_000
    return result


def main():
    iterations = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    points = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
    warmups = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    BUILD.mkdir(exist_ok=True)
    RESULTS.mkdir(exist_ok=True)
    binary = BUILD / "benchmark_uniplot"
    subprocess.run([
        "nim", "c", "-d:release", "--hints:off",
        "--nimcache:build/nimcache-benchmark", f"-o:{binary}",
        "benchmarks/benchmark_uniplot.nim"
    ], cwd=ROOT, check=True)

    benchmark_python = (PYTHON_ENV / ("Scripts/python.exe" if os.name == "nt"
                                      else "bin/python"))
    if not benchmark_python.exists():
        benchmark_python = Path(sys.executable)
    benchmark_env = os.environ.copy()
    if R_LIBRARY.exists():
        benchmark_env["R_LIBS_USER"] = str(R_LIBRARY)

    providers = [
        command_json([str(binary), str(iterations), str(points),
                      "tests/DejaVuSans.ttf", str(warmups)], "UniPlot"),
        command_json([str(benchmark_python), "benchmarks/benchmark_matplotlib.py",
                      str(iterations), str(points), str(warmups)],
                     "Matplotlib", benchmark_env),
        command_json([str(benchmark_python), "benchmarks/benchmark_plotly.py",
                      str(iterations), str(points), str(warmups)],
                     "Plotly", benchmark_env),
    ]
    if shutil.which("Rscript"):
        providers.append(command_json([
            "Rscript", "benchmarks/benchmark_ggplot2.R",
            str(iterations), str(points), str(warmups)
        ], "ggplot2", benchmark_env))
    else:
        providers.append({"provider": "ggplot2", "available": False,
                          "reason": "Rscript is not installed"})
    if shutil.which("julia"):
        providers.append(command_json([
            "julia", f"--project={JULIA_PROJECT}",
            "benchmarks/benchmark_plots.jl",
            str(iterations), str(points), str(warmups)
        ], "Plots.jl", benchmark_env))
    else:
        providers.append({"provider": "Plots.jl", "available": False,
                          "reason": "Julia is not installed"})
    report = {
        "schema": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "machine": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "python": subprocess.run([str(benchmark_python), "--version"],
                                     capture_output=True, text=True).stdout.strip(),
            "nim": subprocess.run(["nim", "--version"], capture_output=True,
                                  text=True).stdout.splitlines()[0],
        },
        "methodology": {
            "iterations": iterations,
            "warmup_iterations": warmups,
            "points": points,
            "canvas": "800x500",
            "warning": "Stages align intent, not internal implementation; compare trends, not API overhead as identical work."
        },
        "providers": providers,
        "optional_runtimes": {
            "Rscript": shutil.which("Rscript") is not None,
            "julia": shutil.which("julia") is not None,
        },
    }
    destination = RESULTS / "latest.json"
    destination.write_text(json.dumps(report, indent=2) + "\n")
    print(destination)


if __name__ == "__main__":
    main()
