# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[base64, strutils]

proc pngDataUri*(data: openArray[byte]): string =
  "data:image/png;base64," & base64.encode(data)

proc pngDataUri*(data: string): string =
  "data:image/png;base64," & base64.encode(data)

proc svgFigure*(svg, caption: string): string =
  "<figure class=\"uniplot-demo\">" & svg &
    "<figcaption>" & caption & "</figcaption></figure>"

proc pngFigure*(uri, caption, alt: string): string =
  "<figure class=\"uniplot-demo\"><img src=\"" & uri & "\" alt=\"" & alt &
    "\"><figcaption>" & caption & "</figcaption></figure>"

proc gallery*(figures: openArray[string]): string =
  result = "<div class=\"uniplot-gallery\">"
  for figure in figures:
    result &= figure
  result &= "</div>"

proc bookStyle*(): string = """
<style>
  .uniplot-lead { font-size: 1.08rem; max-width: 72ch; }
  .uniplot-callout {
    margin: 1.25rem 0; padding: 1rem 1.15rem; border-left: 4px solid #3366cc;
    border-radius: .25rem; background: color-mix(in srgb, #3366cc 8%, transparent);
  }
  .uniplot-gallery {
    display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem; align-items: start; margin: 1.5rem 0 2.5rem;
  }
  .uniplot-demo { margin: 1.5rem 0 2.5rem; }
  .uniplot-gallery .uniplot-demo { margin: 0; }
  .uniplot-demo svg, .uniplot-demo img {
    display: block; width: 100%; height: auto; border: 1px solid #d9dde3;
    border-radius: .5rem; background: #fff;
  }
  .uniplot-demo figcaption { margin-top: .6rem; opacity: .78; }
</style>
"""

proc validatePage*(path: string; minSvg = 0; requirePng = false) =
  let html = readFile(path)
  doAssert html.count("<svg") >= minSvg,
    path & " is missing executable SVG demonstrations"
  if requirePng:
    doAssert html.contains("data:image/png;base64,iVBORw0KGgo"),
      path & " is missing an embedded UniPlot PNG"
  doAssert not html.contains("src=\"../") and not html.contains("src=\"book/"),
    path & " contains a plot image with an external relative dependency"
