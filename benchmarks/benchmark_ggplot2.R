# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly=TRUE)
iterations <- if (length(args) >= 1) as.integer(args[[1]]) else 20
point_count <- if (length(args) >= 2) as.integer(args[[2]]) else 1000
warmups <- if (length(args) >= 3) as.integer(args[[3]]) else 3
# Checked before the vectors are allocated: zero iterations leaves the summary
# with nothing to describe, and a negative warmup count removes measurements
# while the report still states the iterations asked for.
if (is.na(iterations) || iterations <= 0 || is.na(point_count) ||
    point_count <= 0 || is.na(warmups) || warmups < 0) {
  stop("iterations and point count must be positive, warmups non-negative")
}
data <- data.frame(x=(0:(point_count - 1)) / 25)
data$y <- sin(data$x) + 0.02 * data$x

make_plot <- function() {
  ggplot(data, aes(x, y)) +
    geom_line(colour="#3366cc", linewidth=0.8) +
    geom_point(colour="#cc3344", size=0.5) +
    labs(title="Rosetta benchmark", x="x", y="y")
}

describe <- function(values) {
  sprintf('{"mean_ms":%.9f,"stdev_ms":%.9f,"min_ms":%.9f,"max_ms":%.9f}',
          mean(values), if (length(values) > 1) sd(values) else 0,
          min(values), max(values))
}

reference <- make_plot()
construct <- svg <- png <- numeric(iterations)
guard <- 0
for (iteration in seq_len(iterations + warmups)) {
  started <- proc.time()[["elapsed"]]
  plot <- make_plot()
  construct_ms <- (proc.time()[["elapsed"]] - started) * 1000

  svg_path <- tempfile(fileext=".svg")
  started <- proc.time()[["elapsed"]]
  grDevices::svg(svg_path, width=8, height=5)
  print(reference)
  grDevices::dev.off()
  svg_ms <- (proc.time()[["elapsed"]] - started) * 1000

  png_path <- tempfile(fileext=".png")
  started <- proc.time()[["elapsed"]]
  grDevices::png(png_path, width=800, height=500)
  print(reference)
  grDevices::dev.off()
  png_ms <- (proc.time()[["elapsed"]] - started) * 1000
  guard <- guard + file.info(svg_path)$size + file.info(png_path)$size
  unlink(c(svg_path, png_path))

  if (iteration > warmups) {
    index <- iteration - warmups
    construct[index] <- construct_ms
    svg[index] <- svg_ms
    png[index] <- png_ms
  }
}

cat(sprintf(paste0(
  '{"provider":"ggplot2","version":"%s","iterations":%d,',
  '"points":%d,"width":800,"height":500,"warmup_iterations":%d,',
  '"stages":{"construct_compile":%s,"svg_from_compiled_scene":%s,',
  '"png_from_compiled_scene":%s},"guard":%d}\n'),
  as.character(packageVersion("ggplot2")), iterations, point_count, warmups,
  describe(construct), describe(svg), describe(png), guard))
