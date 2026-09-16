---
name: sync-rust
description: Propagate a change to shared Rust server code (src/main.rs, src/common/) across all four Rust variants (poly-rust, poly-aca-rust-azure, poly-aci-rust-azure, poly-lightsail-rust-aws) and verify each builds, lints, and tests. Use after editing shared Rust code in any one variant.
---

The four Rust modules share identical `src/main.rs` and `src/common/`. Keep them identical.

Variants (repo root):
- `poly-rust`
- `poly-aca-rust-azure`
- `poly-aci-rust-azure`
- `poly-lightsail-rust-aws`

## Steps

1. Identify the source variant — the one that was just edited (ask if unclear). Before copying, run `diff -r <source>/src <other>/src` against each other variant. If a target has changes the source lacks, stop and show them rather than overwriting.
2. Copy the shared files from the source into the other three:
   `for d in poly-rust poly-aca-rust-azure poly-aci-rust-azure poly-lightsail-rust-aws; do [ "$d" = "<source>" ] || { cp <source>/src/main.rs "$d/src/main.rs"; rm -rf "$d/src/common"; cp -r <source>/src/common "$d/src/common"; }; done`
3. If the change added a dependency in `Cargo.toml`, add the same dependency to each variant's `Cargo.toml` by hand — don't copy the whole file (package names differ).
4. Do NOT copy `Makefile`, `Dockerfile`, `Cargo.toml`, `tests/`, or env scripts — those are per-cloud.
5. Confirm `diff -r` shows no differences in `src/` between all pairs.
6. In each variant run `make lint && make test`. Report pass/fail per variant with the failing output.
