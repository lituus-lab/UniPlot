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
surfaces. The font is located rather than assumed: the library renders text
with one the caller supplies and ships none of its own."""),
    ("code", """from pathlib import Path
import sys
sys.path.insert(0, "py")
import uniplot

uniplot.version(), uniplot.abi_version()"""),
    ("code", """# The wheel bundles the native library; the text font is the caller's, so
# this looks where one is likely to be. Run from the repository the first
# candidate answers; run against an installed wheel elsewhere, a system font
# does.
candidates = [
    Path("tests/DejaVuSans.ttf"),
    Path("../tests/DejaVuSans.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    Path("/Library/Fonts/Arial Unicode.ttf"),
    Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
]
font = next((c for c in candidates if c.exists()), None)
if font is None:
    # Last resort, because a runner image is not a promise: take the first
    # TrueType file the system font directories offer.
    for root in (Path("/usr/share/fonts"), Path("/Library/Fonts"),
                 Path("/System/Library/Fonts")):
        if root.is_dir():
            font = next(iter(sorted(root.rglob("*.ttf"))), None)
            if font is not None:
                break
if font is None:
    raise SystemExit("no TrueType font found; pass one of your own to render")
font
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
