<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# unitemplate — Python binding

```bash
nimble clib                                              # build libUniTemplate.so
cd py && python3 setup.py build_ext --inplace            # build extension
cd py && python3 -m pytest -q                            # test
```

```python
import unitemplate
unitemplate.version()       # "0.1.0"
unitemplate.fibonacci(10)   # 55
```
