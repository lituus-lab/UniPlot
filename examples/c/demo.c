/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#include "UniPlot.h"
#include <stdio.h>
int main(void) {
  uplot_init();
  printf("UniPlot %s (ABI v%d)\n", uplot_version(), uplot_abi_version());
  return 0;
}
