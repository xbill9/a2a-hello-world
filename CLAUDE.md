# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Layout

A collection of independent A2A demo modules with no shared build. Each module has its own Makefile; run commands from inside the module directory.

- Python (Google ADK + a2a-sdk): `src/agents/*`, `poly-python/`, `a2a-agentcard/`, `a2a-client-test/`
- Rust (`a2a-rs`, edition 2024): `poly-rust/` (GCP Cloud Run), `poly-aca-rust-azure/` (Azure Container Apps), `poly-aci-rust-azure/` (Azure Container Instances), `poly-lightsail-rust-aws/` (AWS Lightsail)
- Go: `poly-go/` — TypeScript: `poly-node/`

| Dir | Stack | Local port | Deploy |
|---|---|---|---|
| `src/agents/{a2a_master_agent,a2a_events,a2a_hello_world,a2a_weather_time}` | Python, google-adk + a2a-sdk | 8081, 8082, 8083, 8084 | Cloud Run via `./cloudrun.sh` |
| `poly-python/agents/{poly_master,poly_rand}` | Python ADK | 8085, 8087 | none |
| `poly-go/` | Go, `google.golang.org/adk` | `$PORT` (default 8086) | none working |
| `poly-node/` | TypeScript, `@a2a-js/sdk`, npm | 8091 (hard-coded) | none working |
| `poly-rust/` | Rust 2024, `a2a-rs` | `$PORT` (default 8080) | GCP Cloud Run (`cloudbuild.yaml`) |
| `poly-lightsail-rust-aws/` | Rust | 8080 | AWS Lightsail |
| `poly-aca-rust-azure/` | Rust | 8080 | Azure Container Apps |
| `poly-aci-rust-azure/` | Rust | 8080 | Azure Container Instances (plain HTTP `:8080`) |

The master agents call the others over A2A: `a2a_master_agent` calls 8082–8084, and `poly_master` calls Go 8086, Node 8091 and `poly_rand` 8087. Keep ports consistent when changing any of them.

## Rust variants must stay in sync

`src/main.rs` and `src/common/` are identical across all four Rust modules. Any change to shared server code must be applied to all four (use `/sync-rust`). Per-cloud differences live only in each module's `Makefile`, `Dockerfile`, and `tests/*.py` — don't sync those.

In any Rust module: `make lint` (clippy `-D warnings` + `cargo fmt --check`), `make test` (unit tests are inline in `src/main.rs`), `make start` (PORT=8080). `make card`, `make status` and `make test-remote` hit a running server; the Python scripts in `tests/` need `httpx`.

## Other languages

- **Go:** `make build|run|test|lint|format`. Lint is `go vet`.
- **Node:** `make deps build run lint format`. `make test` always fails because no tests are defined.
- **Root run scripts:** `./a2ahello.sh`, `./a2amaster.sh`, `./poly-master.sh`, `./poly-go.sh`, etc. Check running agents with `./a2acard.sh [urls]` and `./a2atest.sh`.

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

## Deploying

Claude may run `make deploy` and destroy targets without asking. Note that the Azure `make destroy` in `poly-aca-rust-azure` deletes the whole resource group.

- **GCP (`poly-rust`):** `make deploy` runs `gcloud builds submit` and deploys to Cloud Run in us-central1. `make endpoint` prints the URL.
- **AWS (`poly-lightsail-rust-aws`):** run `./save-aws-creds.sh` first; it writes gitignored `.aws_creds`, which the Makefile includes. Then `make deploy`. The Lightsail container service must already exist. Other targets: `make lightsail-status`, `make aws-destroy`.
- **Azure (`poly-aca-rust-azure`, `poly-aci-rust-azure`):** `make az-login`, then `make deploy`. Defaults are `AZ_LOCATION=westus2` and `AZ_RESOURCE_GROUP=a2a-rg-westus2`. ACR and app names derive from `hostname`, and the image tag is the git short SHA.

## Env setup

- `./init.sh` writes `~/project_id.txt` and `~/gemini.key`; `source set_env.sh` exports PROJECT_ID, GOOGLE_CLOUD_LOCATION, GOOGLE_GENAI_USE_VERTEXAI=TRUE, etc. `set_env.sh` needs `gcloud auth` + ADC.
- Root `*.sh` scripts hardcode `$HOME/a2a-hello-world/set_env.sh` and `cd` using relative paths, so the repo must live at that exact path and the scripts must run from the repo root.
- The `set_env.sh`/`init.sh` copies inside the AWS and Azure dirs are GCP scripts and do nothing for those clouds.

## Gotchas

- The Dockerfiles copy a binary named `a2a-server-rust`, but the Lightsail crate is `a2a-server-rust-lightsail` and the ACA crate is `a2a-server-rust-azure`, so those two are broken. If you change a crate name, the Dockerfile's `COPY`/`CMD` must change with it.
- Lightsail's `make test-remote` defaults to a hard-coded Cloud Run URL instead of the Lightsail endpoint.
- Rust agent cards advertise `http://0.0.0.0:<port>`, not the public URL. The card path is `/agentcard` in some places and `/agent-card` in others; the Makefiles try both.
- `poly-node/node_modules` and `src/**/.env` are committed despite `.gitignore`.

## Known broken (don't rely on these)

- `.github/workflows/rust.yml` targets nonexistent `a2a-client-rust/`; `python-agent.yml` runs tests in `a2a_hello_world`, which has none. Most CI workflows in `.github/workflows/` target missing paths.
- Root `make test` points at `src/agents/a2a_hello_world/tests`, which doesn't exist. Root `make run` passes an unused arg.
- `make deploy` in `poly-go` and `poly-node` references a `cloudbuild.yaml` (and Dockerfile) that doesn't exist.
- README mentions `local.sh`, `run.sh`, `api_server.sh` — they don't exist. Don't trust `README.md`.
- `npm test` in `poly-node` is a stub that exits 1.
