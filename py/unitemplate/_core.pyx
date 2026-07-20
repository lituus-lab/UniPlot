# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
cdef extern from "UniTemplate.h":
    const char *unitemplate_version()
    long long unitemplate_fibonacci(int n)


def fibonacci(int n):
    """Raw C call (no domain check). Use unitemplate.fibonacci."""
    return unitemplate_fibonacci(n)


def version():
    return unitemplate_version()
