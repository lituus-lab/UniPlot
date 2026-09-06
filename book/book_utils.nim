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
    "\" decoding=\"async\"><figcaption>" & caption & "</figcaption></figure>"

proc gallery*(figures: openArray[string]): string =
  result = "<div class=\"uniplot-gallery\">"
  for figure in figures:
    result &= figure
  result &= "</div>"

proc bookStyle*(): string = """
<style>
  .uniplot-lead { font-size: 1.08rem; line-height: 1.65; max-width: 72ch; }
  .uniplot-callout {
    margin: 1.25rem 0; padding: 1rem 1.15rem; border-left: 4px solid #3366cc;
    border-radius: .25rem; background: color-mix(in srgb, #3366cc 8%, transparent);
  }
  .uniplot-gallery {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(100%, 280px), 1fr));
    gap: 1rem; align-items: start; margin: 1.5rem 0 2.5rem;
  }
  .uniplot-demo { margin: 1.5rem 0 2.5rem; break-inside: avoid; }
  .uniplot-gallery .uniplot-demo { margin: 0; }
  .uniplot-demo svg, .uniplot-demo img {
    display: block; width: 100%; height: auto; border: 1px solid #d9dde3;
    border-radius: .5rem; background: #fff;
  }
  .uniplot-demo figcaption {
    margin-top: .65rem; line-height: 1.5; opacity: .82;
  }
  @media (max-width: 480px) {
    .uniplot-gallery { gap: 1.35rem; }
    .uniplot-demo { margin-bottom: 2rem; }
  }
</style>
"""

proc validatePage*(path: string; minSvg = 0; requirePng = false) =
  let html = readFile(path)
  doAssert html.count("<svg") >= minSvg,
    path & " is missing executable SVG demonstrations"
  if requirePng:
    doAssert html.contains("data:image/png;base64,iVBORw0KGgo"),
      path & " is missing an embedded UniPlot PNG"
  # Every image reference, not two spellings of a relative one: `src="plot.png"`
  # and an inline `<image href="plot.png">` both passed the old pair and both
  # publish a page that needs a file the site does not carry. The contract is
  # that a page stands alone, so the only accepted form is an embedded one.
  # The attribute is matched with its opening quote, which is what nimib emits;
  # an unquoted `src=plot.png` would not be seen at all.
  for (opening, attribute) in [("<img", "src=\""), ("<image", "href=\"")]:
    var index = html.find(opening)
    while index >= 0:
      let closing = html.find('>', index)
      # Breaking here abandoned this tag and every later one, so a page ending
      # in an unclosed <img src="plot.png" validated with the reference unread.
      doAssert closing >= 0, path & " has an unterminated image tag"
      let tag = html[index .. closing]
      let at = tag.find(attribute)
      if at >= 0:
        let valueStart = at + attribute.len
        let valueEnd = tag.find('"', valueStart)
        # An unterminated value has no closing quote to find; an empty one ends
        # where it starts. Skipping either let the reference through unread.
        doAssert valueEnd >= valueStart,
          path & " has an unterminated image reference: " & tag
        let value = tag[valueStart ..< valueEnd]
        doAssert value.startsWith("data:"),
          path & " references an image the page does not carry: " & value
      index = html.find(opening, closing)
