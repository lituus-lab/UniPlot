# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Build and execute the UniPlot Python quickstart notebook."""
import os
import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ("md", """# UniPlot — Python quickstart

The Python API drives the same pure-Nim scene and renderers as the Nim and C
surfaces. A font path is explicit so output is reproducible."""),
    ("code", """from pathlib import Path
import sys
sys.path.insert(0, "py")
import uniplot

uniplot.version(), uniplot.abi_version()"""),
    ("code", """font = Path("tests/DejaVuSans.ttf")
figure = (uniplot.Plot(480, 300)
          .line([0, 1, 2, 3], [1, 3, 2, 4])
          .scatter([0, 1, 2, 3], [1, 3, 2, 4], color="#cc3344")
          .title("Python quickstart"))
svg = figure.svg(font)
png = figure.png(font)
(svg[:4], png[:4], len(svg), len(png))"""),
    ("md", """`svg` and `png` were compiled from one retained scene. The wheel
bundles the native library; users provide the TrueType font used for text."""),
]

def main():
    notebook = nbf.v4.new_notebook()
    notebook.cells = []
    for index, (kind, source) in enumerate(CELLS):
        cell = (nbf.v4.new_markdown_cell(source) if kind == "md"
                else nbf.v4.new_code_cell(source))
        cell.id = f"uniplot-{index + 1}"
        notebook.cells.append(cell)
    notebook.metadata["kernelspec"] = {
        "display_name": "Python 3", "language": "python", "name": "python3"
    }
    NotebookClient(notebook, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": ROOT}}).execute()
    for cell in notebook.cells:
        cell.metadata.pop("execution", None)
    with open(OUT, "w", encoding="utf-8") as stream:
        nbf.write(notebook, stream)
    print(f"wrote {OUT}")

if __name__ == "__main__":
    main()
