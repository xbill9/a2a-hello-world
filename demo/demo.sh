#!/usr/bin/env bash
# One-command runner for the A2A demo agents.
# Usage: demo/demo.sh <command> [args]   (run with no args for help)
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$DEMO_DIR")"
RUN_DIR="$DEMO_DIR/.run"
PYTHON="${PYTHON:-python}"

# name|port|stack|dir|command
# Masters are started only after the agents they delegate to are ready.
AGENTS=(
  "events|8082|adk|src/agents/a2a_events|$PYTHON agent.py"
  "hello|8083|adk|src/agents/a2a_hello_world|$PYTHON agent.py"
  "weather|8084|adk|src/agents/a2a_weather_time|$PYTHON agent.py"
  "master|8081|adk|src/agents/a2a_master_agent|$PYTHON agent.py"
  "prime-check|8086|poly|poly-go|$RUN_DIR/bin/poly-go"
  "rand|8087|poly|poly-python/agents/poly_rand|$PYTHON agent.py"
  "prime-gen|8091|poly|poly-node|node dist/server.js"
  "poly-master|8085|poly|poly-python/agents/poly_master|$PYTHON agent.py"
  "rust-echo|8080|rust|poly-rust|target/debug/a2a-server-rust"
)

# Scripted prompts for `tour`: target|prompt (read by name in cmd_tour)
# shellcheck disable=SC2034
TOUR_adk=(
  "hello|Say hello"
  "weather|What's the weather in New York?"
  "master|What time is it in New York, and what's the weather like?"
  "master|Find me a few events happening in NYC"
)
# shellcheck disable=SC2034
TOUR_poly=(
  "rand|Give me a random odd number"
  "prime-check|Is 97 prime?"
  "prime-gen|Generate a prime number"
  "poly-master|Is 7919 prime?"
  "poly-master|Generate a prime number for me"
)
# shellcheck disable=SC2034
TOUR_rust=(
  "rust-echo|Hello from the A2A demo"
)

if [[ -t 1 ]]; then
  B=$'\e[1m' DIM=$'\e[2m' RED=$'\e[31m' GRN=$'\e[32m' YEL=$'\e[33m' RST=$'\e[0m'
else
  B="" DIM="" RED="" GRN="" YEL="" RST=""
fi

log() { echo "${DIM}==>${RST} $*"; }
warn() { echo "${YEL}warning:${RST} $*" >&2; }
die() {
  echo "${RED}error:${RST} $*" >&2
  exit 1
}

field() { # <agent-name> <column>
  local row
  for row in "${AGENTS[@]}"; do
    if [[ "${row%%|*}" == "$1" ]]; then
      cut -d'|' -f"$2" <<<"$row"
      return 0
    fi
  done
  return 1
}

stack_agents() { # <adk|poly|rust|all>
  local row
  case "$1" in adk | poly | rust | all) ;; *) die "unknown stack '$1' (adk, poly, rust, all)" ;; esac
  for row in "${AGENTS[@]}"; do
    [[ "$1" == all || "$(cut -d'|' -f3 <<<"$row")" == "$1" ]] && echo "${row%%|*}"
  done
  return 0
}

is_master() { [[ "$1" == *master ]]; }

card_json() { # <base-url>
  local path
  for path in /.well-known/agent-card.json /.well-known/agent.json /agent-card; do
    curl -sf -m 2 "$1$path" 2>/dev/null && return 0
  done
  return 1
}

port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

resolve_url() { # <agent-name|port|url>
  if [[ "$1" == http* ]]; then
    echo "${1%/}"
  elif [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "http://localhost:$1"
  else
    local port
    port="$(field "$1" 2)" || die "unknown agent '$1' (see: demo.sh status)"
    echo "http://localhost:$port"
  fi
}

# JSON-RPC endpoint for an agent: the path its card advertises (the Go agent
# serves /a2a/invoke), on the host we actually reached. Cards often advertise a
# bind address like 0.0.0.0 rather than a reachable host.
rpc_url() { # <base-url>
  local card u path="/"
  if card="$(card_json "$1")"; then
    u="$(jq -r '.url // .supportedInterfaces[0].url // empty' <<<"$card" 2>/dev/null || true)"
    [[ "$u" == *://*/* ]] && path="/${u#*://*/}"
  fi
  echo "$1$path"
}

new_id() {
  cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "demo-$(date +%s)-$RANDOM"
}

# Gemini credentials: Vertex AI when a project is known, otherwise an API key.
# Override with DEMO_AUTH=vertex|apikey. Avoids set_env.sh, which is slow and
# prompts for logins.
load_env() {
  local project="${GOOGLE_CLOUD_PROJECT:-}"
  if [[ -z "$project" && -s "$HOME/project_id.txt" ]]; then
    project="$(<"$HOME/project_id.txt")"
  fi
  if [[ -z "$project" ]] && command -v gcloud >/dev/null; then
    project="$(gcloud config get-value project 2>/dev/null || true)"
  fi

  local mode="${DEMO_AUTH:-}"
  if [[ -z "$mode" ]]; then
    if [[ -n "$project" ]]; then
      mode=vertex
    elif [[ -n "${GOOGLE_API_KEY:-}" || -s "$HOME/gemini.key" ]]; then
      mode=apikey
    else
      die "no Gemini credentials: run ./init.sh, set GOOGLE_CLOUD_PROJECT, or set GOOGLE_API_KEY"
    fi
  fi

  case "$mode" in
    vertex)
      [[ -n "$project" ]] || die "DEMO_AUTH=vertex needs a project (~/project_id.txt or GOOGLE_CLOUD_PROJECT)"
      export GOOGLE_GENAI_USE_VERTEXAI=TRUE
      export GOOGLE_CLOUD_PROJECT="$project" PROJECT_ID="$project"
      export GOOGLE_CLOUD_LOCATION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
      log "Gemini via Vertex AI (project $project, $GOOGLE_CLOUD_LOCATION)"
      ;;
    apikey)
      if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
        [[ -s "$HOME/gemini.key" ]] || die "DEMO_AUTH=apikey needs GOOGLE_API_KEY or ~/gemini.key"
        GOOGLE_API_KEY="$(<"$HOME/gemini.key")"
      fi
      export GOOGLE_API_KEY GOOGLE_GENAI_USE_VERTEXAI=FALSE
      log "Gemini via API key"
      ;;
    *) die "DEMO_AUTH must be vertex or apikey" ;;
  esac
}

# Build steps for the non-Python agents. Output goes to .run/<name>.build.log.
prepare() {
  local name="$1" blog="$RUN_DIR/$1.build.log"
  case "$name" in
    prime-check)
      command -v go >/dev/null || die "go is not installed"
      log "building poly-go"
      (cd "$REPO_ROOT/poly-go" && go build -o "$RUN_DIR/bin/poly-go" .) >"$blog" 2>&1 ||
        die "poly-go build failed, see demo/.run/$name.build.log"
      ;;
    prime-gen)
      command -v npm >/dev/null || die "node/npm is not installed"
      log "building poly-node"
      (
        cd "$REPO_ROOT/poly-node"
        # A half-finished install leaves package dirs without their code; reinstall clean.
        if [[ ! -f node_modules/typescript/lib/tsc.js || ! -d node_modules/@a2a-js/sdk/dist ]]; then
          echo "==> npm ci" && npm ci --no-audit --no-fund
        fi
        echo "==> npm run build" && npm run build
      ) >"$blog" 2>&1 || die "poly-node build failed, see demo/.run/$name.build.log"
      ;;
    rust-echo)
      command -v cargo >/dev/null || die "cargo is not installed"
      log "compiling poly-rust (the first build takes a few minutes)"
      (cd "$REPO_ROOT/poly-rust" && cargo build) >"$blog" 2>&1 ||
        die "poly-rust build failed, see demo/.run/$name.build.log"
      ;;
  esac
}

start_agent() {
  local name="$1" port dir cmd url
  port="$(field "$name" 2)" dir="$(field "$name" 4)" cmd="$(field "$name" 5)"
  url="http://localhost:$port"
  if card_json "$url" >/dev/null; then
    log "$name already running on :$port"
    return 0
  fi
  port_busy "$port" && die "port $port is in use by something that is not an A2A agent"
  prepare "$name"
  # setsid gives each agent its own process group so `down` can stop children too.
  setsid nohup bash -c 'cd "$1" && exec $2' _ "$REPO_ROOT/$dir" "$cmd" \
    >"$RUN_DIR/$name.log" 2>&1 </dev/null &
  echo $! >"$RUN_DIR/$name.pid"
  log "started $name on :$port (log: demo/.run/$name.log)"
}

wait_ready() { # <name> <timeout-seconds>
  local name="$1" port pid="" deadline
  port="$(field "$name" 2)"
  [[ -f "$RUN_DIR/$name.pid" ]] && pid="$(<"$RUN_DIR/$name.pid")"
  deadline=$((SECONDS + $2))
  until card_json "http://localhost:$port" >/dev/null; do
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      echo "${RED}$name exited during startup.${RST} Last lines of demo/.run/$name.log:" >&2
      tail -n 15 "$RUN_DIR/$name.log" >&2
      rm -f "$RUN_DIR/$name.pid"
      return 1
    fi
    if ((SECONDS >= deadline)); then
      warn "$name not ready after $2s, see demo/.run/$name.log"
      return 1
    fi
    sleep 1
  done
  echo "${GRN}ready${RST}  $name  http://localhost:$port"
}

cmd_up() {
  local stack="${1:-adk}" name failed=0
  local -a workers=() masters=()
  mkdir -p "$RUN_DIR/bin"
  for name in $(stack_agents "$stack"); do
    if is_master "$name"; then masters+=("$name"); else workers+=("$name"); fi
  done
  load_env
  for name in "${workers[@]}"; do start_agent "$name"; done
  for name in "${workers[@]}"; do wait_ready "$name" 120 || failed=1; done
  ((failed)) && warn "starting masters anyway; they cannot reach the agents that failed"
  for name in "${masters[@]}"; do start_agent "$name"; done
  for name in "${masters[@]}"; do wait_ready "$name" 120 || failed=1; done
  echo
  ((failed)) && die "some agents did not start"
  log "stop with: demo/demo.sh down $stack"
}

cmd_down() {
  local stack="${1:-all}" name pid
  for name in $(stack_agents "$stack"); do
    [[ -f "$RUN_DIR/$name.pid" ]] || continue
    pid="$(<"$RUN_DIR/$name.pid")"
    if kill -0 "$pid" 2>/dev/null; then
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
      for _ in {1..20}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
      done
      kill -9 -- "-$pid" 2>/dev/null || true
      log "stopped $name"
    fi
    rm -f "$RUN_DIR/$name.pid"
  done
}

cmd_status() {
  local row name port stack card state
  printf "${B}%-12s %-6s %-5s %-8s %s${RST}\n" AGENT PORT STACK STATE "CARD NAME"
  for row in "${AGENTS[@]}"; do
    IFS='|' read -r name port stack _ _ <<<"$row"
    if card="$(card_json "http://localhost:$port")"; then
      state="${GRN}up${RST}"
      card="$(jq -r '.name // "?"' <<<"$card" 2>/dev/null || echo "?")"
    else
      state="${DIM}down${RST}" card=""
    fi
    printf "%-12s %-6s %-5s %-17s %s\n" "$name" "$port" "$stack" "$state" "$card"
  done
}

cmd_card() {
  [[ $# -ge 1 ]] || die "usage: demo.sh card <agent|port|url>"
  local url
  url="$(resolve_url "$1")"
  card_json "$url" | jq . || die "no agent card at $url"
}

rpc_post() { # <rpc-url> <json-body>
  curl -s -m 300 "$1" -H 'content-type: application/json' -d "$2" || die "could not reach $1"
}

# Sends one message. Uses A2A v0.3 `message/send`, which the Python (a2a-sdk
# 1.x compat), Node and Go agents accept; falls back to `tasks/send` for a2a-rs.
cmd_ask() {
  local raw=0
  [[ "${1:-}" == "--raw" ]] && raw=1 && shift
  [[ $# -ge 2 ]] || die "usage: demo.sh ask [--raw] <agent|port|url> <message...>"
  local rpc msg resp code
  rpc="$(rpc_url "$(resolve_url "$1")")"
  shift
  msg="$(jq -nc --arg t "$*" --arg id "$(new_id)" \
    '{kind: "message", messageId: $id, role: "user", parts: [{kind: "text", text: $t}]}')"

  resp="$(rpc_post "$rpc" "$(jq -nc --argjson m "$msg" \
    '{jsonrpc: "2.0", id: 1, method: "message/send", params: {message: $m}}')")"
  if ! jq -e . >/dev/null 2>&1 <<<"$resp"; then
    echo "$resp" >&2
    die "non-JSON response from $rpc"
  fi
  code="$(jq -r '.error.code // empty' <<<"$resp")"
  # -32601 method not found, -32004 unsupported operation (a2a-rs)
  if [[ "$code" == "-32601" || "$code" == "-32004" ]]; then
    resp="$(rpc_post "$rpc" "$(jq -nc --argjson m "$msg" --arg id "$(new_id)" \
      '{jsonrpc: "2.0", id: 1, method: "tasks/send", params: {id: $id, message: $m}}')")"
  fi

  if ((raw)); then
    jq . <<<"$resp"
    return
  fi
  jq -r '
    def texts: [.[]? | .parts[]? | select(.text != null) | .text];
    if .error then "ERROR \(.error.code): \(.error.message)"
    else .result as $r
      | ([$r.artifacts] | map(.[]?) | texts) as $a
      | if ($a | length) > 0 then $a | join("\n")
        elif $r.parts then [$r] | texts | join("\n")
        else ([$r.history[]? | select(.role == "agent")] | texts | last)
             // "(no text in response; use ask --raw)"
        end
    end' <<<"$resp"
}

cmd_logs() {
  [[ $# -ge 1 ]] || die "usage: demo.sh logs <agent>"
  field "$1" 1 >/dev/null || die "unknown agent '$1'"
  [[ -f "$RUN_DIR/$1.log" ]] || die "no log for $1 yet"
  tail -n 50 -f "$RUN_DIR/$1.log"
}

cmd_tour() {
  local stack="${1:-adk}" step target prompt
  declare -p "TOUR_$stack" >/dev/null 2>&1 || die "no tour for '$stack' (adk, poly, rust)"
  local -n steps="TOUR_$stack"
  cmd_up "$stack"
  for step in "${steps[@]}"; do
    target="${step%%|*}" prompt="${step#*|}"
    echo
    echo "${B}you -> $target:${RST} $prompt"
    echo -n "${B}$target:${RST} "
    cmd_ask "$target" "$prompt"
    if [[ -t 0 && -z "${DEMO_NO_PAUSE:-}" ]]; then
      read -rp "${DIM}[enter for next]${RST}" _
    fi
  done
  echo
  log "agents are still running. Try: demo/demo.sh ask $target \"...\""
  log "stop with: demo/demo.sh down $stack"
}

usage() {
  cat <<EOF
${B}A2A demo runner${RST}

  demo/demo.sh tour [adk|poly|rust]       start a stack and walk through example prompts
  demo/demo.sh up [adk|poly|rust|all]     start a stack in the background (default: adk)
  demo/demo.sh down [adk|poly|rust|all]   stop agents started by this script (default: all)
  demo/demo.sh status                     show which agents are up
  demo/demo.sh ask [--raw] <agent> <msg>  send a message (agent name, port, or URL)
  demo/demo.sh card <agent>               print an agent card
  demo/demo.sh logs <agent>               follow an agent's log

Stacks:
  adk   master (8081) -> events (8082), hello (8083), weather (8084)       Python/ADK
  poly  poly-master (8085) -> prime-check (8086, Go), rand (8087, Python),
        prime-gen (8091, Node)
  rust  rust-echo (8080), a2a-rs echo server with no LLM

Env: DEMO_AUTH=vertex|apikey, PYTHON=<interpreter>, DEMO_NO_PAUSE=1
EOF
}

main() {
  mkdir -p "$RUN_DIR"
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    status | ps) cmd_status ;;
    ask) cmd_ask "$@" ;;
    card) cmd_card "$@" ;;
    logs) cmd_logs "$@" ;;
    tour) cmd_tour "$@" ;;
    help | -h | --help) usage ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
