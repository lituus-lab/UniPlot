# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strutils
import UniTemplate

echo "UniTemplate " & UniTemplateVersion
for n in [0, 1, 10, 20, 50, 90, FibMaxN]:
  echo "fib(" & $n & ") = " & $fibonacci(n)
