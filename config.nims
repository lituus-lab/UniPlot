# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniPlot build config. UniPlot renders through UniVector; the sibling
## engines are reached via --path in a family checkout (untagged sibling-repo
## pattern). In an isolated clone, Nimble installs the declared dependencies.
switch("path", "src")
switch("path", "../UniVector/src")
switch("path", "../UniGlyph/src")
switch("path", "../UniImage/src")
switch("path", "../UniColor/src")
switch("path", "../UniLinalg/src")
switch("path", "../UniMath/src")
