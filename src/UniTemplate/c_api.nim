## C ABI for UniTemplate. Built --app:staticlib/--app:lib --noMain --mm:arc -d:release.
## Keep in sync with include/UniTemplate.h; tests/c links the header against this lib.
import ../UniTemplate

const UniTemplateVersionC: cstring = "0.1.0"

# Unmangled C symbols, C calling convention, exported from the shared lib.
{.push exportc, cdecl, dynlib.}

proc unitemplate_fibonacci(n: cint): clonglong =
  ## fibonacci(n), n clamped to [0, FibMaxN]. n < 0 -> 0, n > FibMaxN -> fibonacci(FibMaxN). Never raises.
  let m = int(n)
  if m < 0:
    return clonglong(0)
  if m > FibMaxN:
    return fibonacci(FibMaxN).clonglong
  fibonacci(m).clonglong

proc unitemplate_version(): cstring {.exportc, cdecl, dynlib.} =
  ## Static version string; do not free.
  UniTemplateVersionC

{.pop.}
