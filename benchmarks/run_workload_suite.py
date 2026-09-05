# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "benchmarks" / "results"
WORKLOADS = ((1_000, 20, 3), (100_000, 5, 1), (1_000_000, 1, 0))


def main() -> int:
    RESULTS.mkdir(exist_ok=True)
    reports = []
    for points, iterations, warmups in WORKLOADS:
        print(f"[benchmarkScales] {points} points, {iterations} iterations, "
              f"{warmups} warmups", flush=True)
        subprocess.run([
            sys.executable, "benchmarks/run_benchmarks.py",
            str(iterations), str(points), str(warmups)
        ], cwd=ROOT, check=True)
        with (RESULTS / "latest.json").open(encoding="utf-8") as stream:
            reports.append(json.load(stream))
    report = {
        "schema": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "workloads": reports,
        "output_semantics": {
            "canvas": "800x500",
            "plot": "line plus point series",
            "stages": [
                "construct_compile",
                "svg_from_compiled_scene",
                "png_from_compiled_scene",
            ],
            "warning": (
                "Iteration counts decrease with output size; compare providers "
                "within one workload and machine, never across machines."
            ),
        },
    }
    destination = RESULTS / "workload_suite.json"
    destination.write_text(json.dumps(report, indent=2) + "\n",
                           encoding="utf-8")
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
