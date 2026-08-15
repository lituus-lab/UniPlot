# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import book_utils

nbInit(theme = useNimibook)
nbRawHtml bookStyle()
nbText: """
# Typed data

`DataFrame` stores ordered numeric and categorical columns. All columns share a
row count. Accessors preserve concrete types; `finiteRows` identifies the rows
safe for numeric scale training.
"""

nbCode:
  import std/[math, strutils]
  import UniPlot

  var observations = initDataFrame()
  observations.addColumn("time", [0.0, 1.0, 2.0, 3.0])
  observations.addColumn("value", [1.2, NaN, 2.8, 4.1])
  observations.addColumn("station", ["north", "south", "north", "west"])

  echo "columns: ", observations.order.join(", ")
  echo "rows: ", observations.rowCount
  echo "numeric: ", observations.numeric("time")
  echo "categorical: ", observations.categorical("station")
  echo "finite rows: ", observations.finiteRows(["time", "value"])

nbText: """
## Column model

`ColumnKind` distinguishes `ckNumeric` from `ckCategorical`. A `Column` exposes
either `numbers` or `categories`; a `DataFrame` exposes insertion `order`, its
column table and `rowCount`. Replacing a column keeps its original order.

Non-finite numeric values are filtered during plot compilation. Categorical
values retain first-seen order when a band scale is trained.

## Checked invariants
"""

nbCode:
  proc showDataError(label: string; body: proc()) =
    try:
      body()
    except PlotError as error:
      echo label, ": ", error.msg

  showDataError("mismatched lengths"):
    var bad = initDataFrame()
    bad.addColumn("x", [1.0, 2.0])
    bad.addColumn("y", [1.0])

  showDataError("wrong accessor"):
    discard observations.numeric("station")

  showDataError("missing finiteRows column"):
    discard observations.finiteRows(["absent"])

nbText: """
Column names cannot be empty, lengths cannot disagree, and accessors reject a
missing or incompatible column with `PlotError`. An empty first column still
sets the frame row count to zero.

Next: [Recipes and layered grammar](grammar.html).
"""

nbSave
validatePage("data.html")
