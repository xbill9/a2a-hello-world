# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of **independent** A2A (agent-to-agent) demos. There is no shared library; every subdirectory has its own build, and all are actively maintained.

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

The four Rust dirs currently share an identical `src/`, but they are **allowed to diverge**. Don't propagate a change from one variant to the others unless asked.

## Commands

Run `make` targets from inside the subproject directory.

- **Rust (all four):** `make build`, `make start` (runs on port 8080), `make test` (unit tests are inline in `src/main.rs`), `make lint` (`cargo clippy -- -D warnings` plus fmt check), `make format`. `make card`, `make status` and `make test-remote` hit a running server; the Python scripts in `tests/` need `httpx`.
- **Go:** `make build|run|test|lint|format`. Lint is `go vet`.
- **Node:** `make deps build run lint format`. `make test` always fails because no tests are defined.
- **Python:** the root `make lint` runs `flake8 src` (max line length 88), and `make format` runs `black src`. Root `make test` and `make run` are broken: they point at a nonexistent tests dir and pass an unused arg. The only Python test is `src/agents/a2a_weather_time/tests/`.
- **Root run scripts:** `./a2ahello.sh`, `./a2amaster.sh`, `./poly-master.sh`, `./poly-go.sh`, etc. Check running agents with `./a2acard.sh [urls]` and `./a2atest.sh`.

## Deploying

Claude may run `make deploy` and destroy targets without asking. Note that the Azure `make destroy` deletes the whole resource group.

- **GCP (`poly-rust`):** `make deploy` runs `gcloud builds submit` and deploys to Cloud Run in us-central1. `make endpoint` prints the URL.
- **AWS (`poly-lightsail-rust-aws`):** run `./save-aws-creds.sh` first; it writes `.aws_creds`, which the Makefile includes. Then `make deploy`. The Lightsail container service must already exist. Other targets: `make lightsail-status`, `make aws-destroy`.
- **Azure (`poly-aca-rust-azure`, `poly-aci-rust-azure`):** `make az-login`, then `make deploy`. Defaults are `AZ_LOCATION=westus2` and `AZ_RESOURCE_GROUP=a2a-rg-westus2`. ACR and app names derive from `hostname`, and the image tag is the git short SHA.

## Gotchas

- Root scripts source `$HOME/a2a-hello-world/set_env.sh` and `cd` using relative paths. The repo must live at that exact path, and the scripts must run from the repo root.
- `set_env.sh` needs `gcloud auth` + ADC and `~/project_id.txt` (written by `./init.sh`). The `set_env.sh`/`init.sh` copies inside the AWS and Azure dirs are GCP scripts and do nothing for those clouds.
- The Dockerfiles copy a binary named `a2a-server-rust`, but the Lightsail crate is `a2a-server-rust-lightsail` and the ACA crate is `a2a-server-rust-azure`. If you change a crate name, the Dockerfile's `COPY`/`CMD` must change with it.
- Lightsail's `make test-remote` defaults to a hard-coded Cloud Run URL instead of the Lightsail endpoint.
- Rust agent cards advertise `http://0.0.0.0:<port>`, not the public URL. The card path is `/agentcard` in some places and `/agent-card` in others; the Makefiles try both.
- `poly-go` and `poly-node` `make deploy` reference a Dockerfile and `cloudbuild.yaml` that don't exist.
- Don't trust `README.md` (lists scripts that don't exist) or `AGENTS.md` (a copy of the upstream adk-python contributor guide, not about this repo). Most CI workflows in `.github/workflows/` target missing paths.
- `poly-node/node_modules` and `src/**/.env` are committed despite `.gitignore`.
