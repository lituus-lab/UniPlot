# cython: language_level=3
cdef extern from "UniTemplate.h":
    const char *unitemplate_version()
    long long unitemplate_fibonacci(int n)


def fibonacci(int n):
    """Raw C call (no domain check). Use unitemplate.fibonacci."""
    return unitemplate_fibonacci(n)


def version():
    return unitemplate_version()
