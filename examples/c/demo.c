/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#include "UniPlot.h"
#include <stdio.h>
int main(void) {
  uniplot_init();
  printf("UniPlot %s (ABI v%d)\n", uniplot_version(), uniplot_abi_version());
  return 0;
}
