# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/math

type
  PlotError* = object of CatchableError

  Bounds* = object
    xMin*, yMin*, xMax*, yMax*: float32

  Size* = object
    width*, height*: int

  Insets* = object
    left*, top*, right*, bottom*: float32

  Point* = object
    x*, y*: float32

proc isFinite*(value: SomeFloat): bool {.inline.} =
  classify(value) notin {fcNan, fcInf, fcNegInf}

proc validate*(size: Size) =
  if size.width <= 0 or size.height <= 0:
    raise newException(PlotError, "plot dimensions must be positive")

proc width*(bounds: Bounds): float32 {.inline.} = bounds.xMax - bounds.xMin
proc height*(bounds: Bounds): float32 {.inline.} = bounds.yMax - bounds.yMin

