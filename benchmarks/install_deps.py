# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import os
import shutil
import subprocess
import sys
import venv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
PYTHON_ENV = BUILD / "benchmark-python"
R_LIBRARY = BUILD / "benchmark-r-library"
JULIA_PROJECT = ROOT / "benchmarks" / "julia"


def python_executable():
    if os.name == "nt":
        return PYTHON_ENV / "Scripts" / "python.exe"
    return PYTHON_ENV / "bin" / "python"


def install_python():
    print("[benchmarkDeps] creating isolated Python environment")
    venv.EnvBuilder(with_pip=True, upgrade_deps=True).create(PYTHON_ENV)
    subprocess.run([
        str(python_executable()), "-m", "pip", "install", "-r",
        str(ROOT / "benchmarks" / "requirements.txt")
    ], check=True)


def install_r():
    rscript = shutil.which("Rscript")
    if not rscript:
        print("[benchmarkDeps] Rscript unavailable: skipping ggplot2")
        print("[benchmarkDeps] install R, then rerun this task to enable ggplot2")
        return
    print("[benchmarkDeps] installing ggplot2 into a project-local R library")
    R_LIBRARY.mkdir(parents=True, exist_ok=True)
    expression = (
        f'install.packages("ggplot2", repos="https://cloud.r-project.org", '
        f'lib="{R_LIBRARY.as_posix()}")'
    )
    subprocess.run([rscript, "-e", expression], check=True)


def install_julia():
    julia = shutil.which("julia")
    if not julia:
        print("[benchmarkDeps] Julia unavailable: skipping Plots.jl")
        print("[benchmarkDeps] install Julia, then rerun this task to enable Plots.jl")
        return
    print("[benchmarkDeps] instantiating the dedicated Plots.jl project")
    subprocess.run([
        julia, f"--project={JULIA_PROJECT}", "-e",
        "using Pkg; Pkg.instantiate(); Pkg.precompile()"
    ], check=True)


def main():
    BUILD.mkdir(exist_ok=True)
    install_python()
    install_r()
    install_julia()
    print("[benchmarkDeps] ready; run `nimble benchmark`")


if __name__ == "__main__":
    main()
