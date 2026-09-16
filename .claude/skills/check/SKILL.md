---
name: check
description: Lint and test only the subprojects touched by the current changes (Rust variants, Go, Node, Python). Use after editing code and before committing, or when asked to verify changes.
---

Verify the current changes in this multi-language repo.

1. Find changed files: `git status --porcelain` plus `git diff --name-only HEAD` (or `$ARGUMENTS` if a path/subproject was given).
2. Map each file to its subproject and run that subproject's checks **from inside its directory**:
   - `poly-rust/`, `poly-lightsail-rust-aws/`, `poly-aca-rust-azure/`, `poly-aci-rust-azure/` → `make lint` then `make test`. Also run `cargo build --release` if `Cargo.toml` or the `Dockerfile` changed, and confirm the Dockerfile's `COPY`/`CMD` binary name matches the `[package] name` in `Cargo.toml`.
   - `poly-go/` → `make lint` then `make test`.
   - `poly-node/` → `make build` then `make lint`. Skip `make test`; no tests are defined and it always fails.
   - `src/agents/**` → from the repo root, `flake8 <changed files>` (config in `.flake8`, max line length 88). If the change is under `a2a_weather_time`, also run `python3 -m unittest discover src/agents/a2a_weather_time/tests`. Don't use the root `make test`/`make run`; both are broken.
   - `poly-python/**` → `flake8 <changed files>`.
   - Shell scripts, docs or config only → nothing to run; say so.
3. If a tool is missing (e.g. `flake8`, `black`, eslint deps), report it rather than installing into a venv. Install globally with pyenv's `python3 -m pip` only if the user agrees.
4. Report a per-subproject pass/fail table, with the failing output for anything red. Don't fix failures unless asked.
