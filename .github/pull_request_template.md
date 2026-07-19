## What changes, and why

<!-- The problem, then the fix. Link the issue if there is one. -->

## Checks

- [ ] Every commit carries `Signed-off-by:` (`git commit -s`) — the DCO job blocks otherwise
- [ ] `nimble testAll` passes
- [ ] `nimble lint` and `nimble checkVGraph` pass
- [ ] C ABI touched → `include/UniTemplate.h` updated in the same commit
- [ ] Public API touched → `book/index.nim` still builds and describes it
