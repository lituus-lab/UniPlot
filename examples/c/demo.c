// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include "UniTemplate.h"

int main(void) {
  printf("UniTemplate %s\n", unitemplate_version());
  int ns[] = {0, 1, 10, 20, 50, 90, UNITEMPLATE_FIB_MAX_N};
  for (size_t i = 0; i < sizeof(ns) / sizeof(ns[0]); i++)
    printf("fib(%d) = %lld\n", ns[i], unitemplate_fibonacci(ns[i]));
  return 0;
}
