<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPlot Book

Executable nimib documentation and demo gallery for UniPlot. `nimble book`
compiles and runs every code block before writing `book/index.html`; `nimble
docs` publishes it alongside the generated API reference.

The generated plots are self-contained in the final HTML. SVG output is
inserted inline and PNG output is encoded as a Base64 `data:` URL. The book
build asserts that both formats are present and that no plot depends on a
book-relative image file.
