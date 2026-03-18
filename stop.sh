#!/usr/bin/env bash
# ./stop.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSERVER_DIR="$PROJECT_ROOT/.devserver"
PID_FILE="$DEVSERVER_DIR/server.pid"
PORT_FILE="$DEVSERVER_DIR/server.port"
CMD_FILE="$DEVSERVER_DIR/server.cmd"

log() {
  printf '[stop] %s\n' "$1"
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

listener_pids_for_port() {
  local port="$1"
  ss -ltnp "( sport = :$port )" 2>/dev/null | grep -o 'pid=[0-9]\+' | cut -d= -f2 | sort -u || true
}

stopped_any=0

if [[ -f "$PID_FILE" ]]; then
  saved_pid="$(cat "$PID_FILE")"
  if [[ -n "$saved_pid" ]] && pid_is_running "$saved_pid"; then
    kill_pid "$saved_pid" "saved dev server"
    stopped_any=1
  else
    log "Saved PID file exists but no running process matches it"
  fi
else
  log "No saved PID file found"
fi

while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  if process_matches_project "$pid"; then
    kill_pid "$pid" "project wrangler dev"
    stopped_any=1
  fi
done < <(wrangler_pids)

if [[ -f "$PORT_FILE" ]]; then
  saved_port="$(cat "$PORT_FILE")"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    cmdline="$(proc_cmdline "$pid")"
    if process_matches_project "$pid" || process_looks_like_dev_server "$cmdline"; then
      kill_pid "$pid" "listener on saved port $saved_port"
      stopped_any=1
    else
      log "Leaving unrelated process on port $saved_port alone (PID $pid)"
    fi
  done < <(listener_pids_for_port "$saved_port")
else
  log "No saved port file found"
fi

rm -f "$PID_FILE" "$PORT_FILE" "$CMD_FILE"

if [[ "$stopped_any" -eq 0 ]]; then
  log "Nothing was running"
else
  log "Local development server stopped"
fi
