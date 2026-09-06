# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import json
import subprocess
import time
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "benchmarks" / "results"


def run(iterations: int, warmups: int) -> dict:
    subprocess.run([
        sys.executable, "benchmarks/run_benchmarks.py",
        str(iterations), "1000", str(warmups)
    ], cwd=ROOT, check=True)
    with (RESULTS / "latest.json").open(encoding="utf-8") as stream:
        return json.load(stream)


def main() -> int:
    RESULTS.mkdir(exist_ok=True)
    # An untimed pass first: `run_benchmarks.py` compiles UniPlot on its first
    # invocation, and the semantics below exclude that. Without it the timed
    # run measured a build.
    run(1, 0)
    started = time.perf_counter()
    cold = run(1, 0)
    cold_wall_ms = (time.perf_counter() - started) * 1000.0
    warm = run(20, 3)
    report = {
        "schema": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "points": 1_000,
        "cold_process": cold,
        "cold_process_wall_ms": round(cold_wall_ms, 3),
        "warm_process": warm,
        "semantics": {
            "cold_process_wall_ms": (
                "Wall time of one full cold run: the runner's own startup, "
                "the provider subprocess, runtime and library initialization, "
                "reference construction, one real SVG and PNG render, JSON "
                "serialization, and shutdown. UniPlot compilation is excluded "
                "by compiling in an untimed pass first."
            ),
            "warm_stages": (
                "Per-stage measurements after three loop warmups in a separate "
                "provider process."
            ),
            "warning": (
                "Cold process wall time and warm stage time answer different "
                "questions and must not be divided into a speedup ratio."
            ),
        },
    }
    destination = RESULTS / "thermal_suite.json"
    destination.write_text(json.dumps(report, indent=2) + "\n",
                           encoding="utf-8")
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

