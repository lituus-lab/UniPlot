# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Does not compile, on purpose. `canary`, run through the gate, must fail; a
## CI step asserts it does. The day this file compiles, or the day the gate
## lets it pass, every other green result in this repo stops meaning anything.
import UniPlot

echo plot(theCanaryIsSupposedToBeUndefined)
