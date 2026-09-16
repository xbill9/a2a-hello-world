# Demo runner

`demo/demo.sh` starts the A2A agents in the background, waits until each one serves its agent card, and lets you message them from one terminal.

```bash
demo/demo.sh tour           # Python/ADK stack: start it, then walk through example prompts
demo/demo.sh tour poly      # Go + Python + Node agents behind a Python master
demo/demo.sh status         # what's up, on which port
demo/demo.sh ask master "What's the weather in New York?"
demo/demo.sh down           # stop everything this script started
```

| Stack | Agents |
|-------|--------|
| `adk` | `master` :8081 delegates to `events` :8082, `hello` :8083, `weather` :8084 |
| `poly` | `poly-master` :8085 delegates to `prime-check` :8086 (Go), `rand` :8087 (Python), `prime-gen` :8091 (Node) |
| `rust` | `rust-echo` :8080, an a2a-rs echo server with no LLM |

**Credentials.** Uses Vertex AI when a project is found (`GOOGLE_CLOUD_PROJECT`, `~/project_id.txt` from `./init.sh`, or `gcloud config`), otherwise the Gemini API key in `GOOGLE_API_KEY` or `~/gemini.key`. Force one with `DEMO_AUTH=vertex` or `DEMO_AUTH=apikey`. It does not source `set_env.sh`.

**Builds.** `poly` builds the Go binary and runs `npm install`/`npm run build` for Node. `rust` runs `cargo build`, which takes a few minutes the first time. Build output goes to `demo/.run/<agent>.build.log`, and agent logs go to `demo/.run/<agent>.log` (`demo/demo.sh logs <agent>`).

**Masters hand off; they don't chain.** A master passes the conversation to one sub-agent, so "generate a random number and check if it's prime" stops after the random number. Ask one-hop questions.

**Requirements.** `curl`, `jq`, `setsid`, and a Python with `google-adk` installed (override with `PYTHON=...`), plus `go`, `node`/`npm` or `cargo` for the stacks that need them.
