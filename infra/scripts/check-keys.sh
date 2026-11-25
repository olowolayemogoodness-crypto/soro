#!/usr/bin/env bash
# Check that the API keys in .env work, printing ONLY HTTP status codes.
# Never prints key values. Safe to run in a shared terminal / Claude Code session.
# Usage: infra/scripts/check-keys.sh [path/to/.env]   (default: repo-root .env)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${1:-$ROOT/.env}"
[ -f "$ENV_FILE" ] || { echo "No env file at $ENV_FILE"; exit 1; }

# Read one KEY=value without sourcing the file (no code execution, no echo).
get() { grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '\r' | sed -E 's/^["'\'']//; s/["'\'']$//'; }

status() { # name, http code
  case "$2" in
    200) echo "$1: 200 ✅ works" ;;
    000) echo "$1: no response ⚠️ (network?)" ;;
    *)   echo "$1: $2 ❌ key rejected or wrong" ;;
  esac
}

check() { # name, var, curl args...
  local name="$1" val; val="$(get "$2")"; shift 2
  case "$val" in ""|your_*) echo "$name: not set"; return ;; esac
  status "$name" "$(curl -s -o /dev/null -m 10 -w '%{http_code}' "${@//\{KEY\}/$val}")"
}

check "Gemini" GEMINI_API_KEY -H "x-goog-api-key: {KEY}" https://generativelanguage.googleapis.com/v1beta/models
check "Groq  " GROQ_API_KEY   -H "Authorization: Bearer {KEY}" https://api.groq.com/openai/v1/models
