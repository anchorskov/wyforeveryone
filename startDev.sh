#!/usr/bin/env bash
# ./startDev.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSERVER_DIR="$PROJECT_ROOT/.devserver"
PID_FILE="$DEVSERVER_DIR/server.pid"
PORT_FILE="$DEVSERVER_DIR/server.port"
LOG_FILE="$DEVSERVER_DIR/server.log"
CMD_FILE="$DEVSERVER_DIR/server.cmd"
PORT="${1:-8788}"

mkdir -p "$DEVSERVER_DIR"

log() {
  printf '[startDev] %s\n' "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

pid_is_running() {
  local pid="$1"
  kill -0 "$pid" >/dev/null 2>&1
}

proc_cwd() {
  local pid="$1"
  readlink -f "/proc/$pid/cwd" 2>/dev/null || true
}

proc_cmdline() {
  local pid="$1"
  tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true
}

process_matches_project() {
  local pid="$1"
  [[ "$(proc_cwd "$pid")" == "$PROJECT_ROOT" ]]
}

process_looks_like_dev_server() {
  local cmdline="$1"
  [[ "$cmdline" == *"python3 -m http.server"* ]] ||
    [[ "$cmdline" == *"python -m http.server"* ]] ||
    [[ "$cmdline" == *"npx serve"* ]] ||
    [[ "$cmdline" == *"serve -l"* ]] ||
    [[ "$cmdline" == *"serve --listen"* ]]
}

kill_pid() {
  local pid="$1"
  local label="$2"

  if ! pid_is_running "$pid"; then
    return 0
  fi

  log "Stopping $label (PID $pid)"
  kill "$pid" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5; do
    if ! pid_is_running "$pid"; then
      return 0
    fi
    sleep 1
  done

  log "Force stopping $label (PID $pid)"
  kill -9 "$pid" >/dev/null 2>&1 || true
}

wrangler_pids() {
  pgrep -f '(^|/)(npx[[:space:]]+)?wrangler([[:space:]].*)?[[:space:]]dev([[:space:]]|$)' 2>/dev/null || true
}

stop_project_wrangler() {
  local found=0
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if process_matches_project "$pid"; then
      found=1
      kill_pid "$pid" "project wrangler dev"
    fi
  done < <(wrangler_pids)

  if [[ "$found" -eq 0 ]]; then
    log "No project wrangler dev process found"
  fi
}

listener_pids_for_port() {
  ss -ltnp "( sport = :$PORT )" 2>/dev/null | grep -o 'pid=[0-9]\+' | cut -d= -f2 | sort -u || true
}

describe_port_usage() {
  ss -ltnp "( sport = :$PORT )" 2>/dev/null || true
}

handle_port_conflict() {
  local found=0

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    found=1
    local cmdline
    cmdline="$(proc_cmdline "$pid")"
    log "Port $PORT is in use by PID $pid"
    describe_port_usage

    if process_matches_project "$pid" || process_looks_like_dev_server "$cmdline"; then
      kill_pid "$pid" "port $PORT listener"
    else
      log "Refusing to kill unrelated process on port $PORT"
      exit 1
    fi
  done < <(listener_pids_for_port)

  if [[ "$found" -eq 0 ]]; then
    log "Port $PORT is available"
  fi
}

start_server() {
  if require_cmd python3; then
    log "Starting static server with python3"
    (
      cd "$PROJECT_ROOT"
      nohup python3 -m http.server "$PORT" --bind 127.0.0.1 >"$LOG_FILE" 2>&1 &
      echo $! >"$PID_FILE"
      echo "python3 -m http.server" >"$CMD_FILE"
    )
    return 0
  fi

  if require_cmd npx; then
    log "python3 not found, starting static server with npx serve"
    (
      cd "$PROJECT_ROOT"
      nohup npx serve . --listen "127.0.0.1:$PORT" >"$LOG_FILE" 2>&1 &
      echo $! >"$PID_FILE"
      echo "npx serve" >"$CMD_FILE"
    )
    return 0
  fi

  log "No supported static server found. Install python3 or Node.js with npx."
  exit 1
}

log "Project root: $PROJECT_ROOT"
log "Requested port: $PORT"

stop_project_wrangler
handle_port_conflict
start_server

SERVER_PID="$(cat "$PID_FILE")"
echo "$PORT" >"$PORT_FILE"

sleep 1

if ! pid_is_running "$SERVER_PID"; then
  log "Dev server failed to start. Check $LOG_FILE"
  exit 1
fi

log "Server started with PID $SERVER_PID"
log "Serving $PROJECT_ROOT"
log "Local URL: http://127.0.0.1:$PORT"
