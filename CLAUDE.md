# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Layout

A collection of independent A2A demo modules with no shared build. Each module has its own Makefile; run commands from inside the module directory.

- Python (Google ADK + a2a-sdk): `src/agents/*`, `poly-python/`, `a2a-agentcard/`, `a2a-client-test/`
- Rust (`a2a-rs`, edition 2024): `poly-rust/` (GCP Cloud Run), `poly-aca-rust-azure/` (Azure Container Apps), `poly-aci-rust-azure/` (Azure Container Instances), `poly-lightsail-rust-aws/` (AWS Lightsail)
- Go: `poly-go/` — TypeScript: `poly-node/`

## Rust variants must stay in sync

`src/main.rs` and `src/common/` are identical across all four Rust modules. Any change to shared server code must be applied to all four (use `/sync-rust`). Per-cloud differences live only in each module's `Makefile`, `Dockerfile`, and `tests/*.py` — don't sync those.

In any Rust module: `make lint` (clippy `-D warnings` + `cargo fmt --check`), `make test`, `make start` (PORT=8080).

## Python

- Style follows the adk-python conventions in `AGENTS.md`: 2-space indent, 80-column lines, pyink + isort (Google profile). Ignore the rest of AGENTS.md — it was copied from google/adk-python and does not describe this repo.
- Do NOT run root `make format` / `make lint` on Python: they run black and flake8 at 88 columns, which conflicts with the chosen style.
- Dependencies are managed with both uv (`pyproject.toml`/`uv.lock`) and pip (`requirements.txt`, including per-agent ones). When changing a dependency, update both.
- Only Python tests: `src/agents/a2a_weather_time/tests/`. Single test: `cd src/agents/a2a_weather_time && python -m unittest tests.test_agent.TestAgent.test_get_weather_success`

## Running the demos

`demo/demo.sh tour [adk|poly|rust]` starts a stack and sends example prompts; `demo/demo.sh down` stops it. Logs are in `demo/.run/`. See `demo/README.md`.

A2A interop pitfalls (each one fails silently as a master reply with no text):
- Agent cards must advertise `localhost`, and masters must fetch cards from `localhost`. ADK's `RemoteA2aAgent` rejects plain-http cards on non-loopback hosts (`0.0.0.0`) and cards whose origin differs from the fetch URL (`127.0.0.1` vs `localhost`).
- A2A v0.3 servers (poly-go, poly-node) must set `protocolVersion: "0.3.0"` in their card. Otherwise a2a-sdk 1.x clients speak v1.0 (`SendMessage`), which the server rejects. This is why poly-go builds its own card instead of using the ADK launcher.
- Masters use `sub_agents` (`transfer_to_agent`), so one request cannot chain two sub-agents.

## Env setup

- `./init.sh` writes `~/project_id.txt` and `~/gemini.key`; `source set_env.sh` exports PROJECT_ID, GOOGLE_CLOUD_LOCATION, GOOGLE_GENAI_USE_VERTEXAI=TRUE, etc.
- Root `*.sh` scripts hardcode `$HOME/a2a-hello-world/set_env.sh`, so the repo must live at that path.
- Lightsail Makefile loads gitignored `.aws_creds` (written by `./save-aws-creds.sh`) and assumes the container service already exists.
- `make destroy` in `poly-aca-rust-azure` deletes the whole resource group. Deploy/destroy targets hit real cloud accounts — confirm before running.

## Known broken (don't rely on these)

- `.github/workflows/rust.yml` targets nonexistent `a2a-client-rust/`; `python-agent.yml` runs tests in `a2a_hello_world`, which has none.
- Root `make test` points at `src/agents/a2a_hello_world/tests`, which doesn't exist.
- `make deploy` in `poly-go` and `poly-node` references a `cloudbuild.yaml` (and Dockerfile) that doesn't exist.
- README mentions `local.sh`, `run.sh`, `api_server.sh` — they don't exist.
- `npm test` in `poly-node` is a stub that exits 1.
