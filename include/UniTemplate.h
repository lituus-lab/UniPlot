#ifndef UNITEMPLATE_H
#define UNITEMPLATE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNITEMPLATE_VERSION_MAJOR 0
#define UNITEMPLATE_VERSION_MINOR 1
#define UNITEMPLATE_VERSION_PATCH 0
#define UNITEMPLATE_VERSION "0.1.0"

#define UNITEMPLATE_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNITEMPLATE_VERSION_MAJOR > (ma)) || \
   (UNITEMPLATE_VERSION_MAJOR == (ma) && UNITEMPLATE_VERSION_MINOR > (mi)) || \
   (UNITEMPLATE_VERSION_MAJOR == (ma) && UNITEMPLATE_VERSION_MINOR == (mi) && \
    UNITEMPLATE_VERSION_PATCH >= (pa)))

/* Largest n with unitemplate_fibonacci(n) fitting in long long (int64). */
#define UNITEMPLATE_FIB_MAX_N 92

/* Static version string; do not free. */
const char *unitemplate_version(void);

/* fibonacci(n), n clamped to [0, UNITEMPLATE_FIB_MAX_N].
 * n < 0 -> 0; n > UNITEMPLATE_FIB_MAX_N -> fibonacci(UNITEMPLATE_FIB_MAX_N).
 * Never raises. Single-threaded, reentrant. */
long long unitemplate_fibonacci(int n);

#ifdef __cplusplus
}
#endif

#endif /* UNITEMPLATE_H */
