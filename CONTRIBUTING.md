# Contributing

## License

Apache-2.0 (`LICENSE`).

## DCO

Every commit signs off the [Developer Certificate of Origin](https://developercertificate.org/):

```bash
git commit -s
```

Commits without a `Signed-off-by` trailer are not accepted.

## Workflow

1. Branch from `main`, one logical change per commit.
2. Pass the gates: `nimble testAll`, `nimble pyTest`.
3. Open a PR; CI runs the 3-OS Nim matrix + C ABI + Python.

## Conventions

See `ADRs/0004` and `CLAUDE.md`. English comments, terse, describe what is done.
NimContracts compiled away under `-d:release`; the C ABI clamps, never raises.
