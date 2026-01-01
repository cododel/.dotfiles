#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="${AI_COMMIT_CONFIG_DIR:-$HOME/.config/ai-commit}"
CONFIG_PATH="${AI_COMMIT_CONFIG:-$CONFIG_DIR/config}"
STATS_PATH="${AI_COMMIT_STATS:-$CONFIG_DIR/stats.json}"

# Default values
MODEL_SUM="x-ai/grok-code-fast-1"
MODEL_GEN="google/gemini-2.5-flash-lite"
SPINNER_ENABLED=true
CURSOR_HIDDEN=false
DRY_RUN=false
HISTORY_LIMIT=20
USE_HISTORY=true
TMP_ITEMS=()
DIFF_COMPACT=""
DIFF_STATUS=""
DIFF_NUMSTAT=""
DIFF_STAT_SUMMARY=""
HISTORY=""
RAW_SUMMARY=""
RESPONSE=""

require_command() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
}

cleanup() {
  local status=$?
  if $CURSOR_HIDDEN; then
    tput cnorm >&2 2>/dev/null || true
  fi
  for item in "${TMP_ITEMS[@]}"; do
    [[ -n "$item" && -e "$item" ]] && rm -f "$item" 2>/dev/null || true
  done
  return $status
}
trap cleanup EXIT

print_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  --config <path>     Use custom config file (default: $CONFIG_PATH)
  --model-sum <name>  Model for change summarization (default: $MODEL_SUM)
  --model-gen <name>  Model for commit generation (default: $MODEL_GEN)
  --no-spinner        Disable animated spinner output
  --dry-run           Print the message without committing
  --help              Show this help message and exit

Configuration file ($CONFIG_PATH):
  KEY=VALUE pairs, e.g.:
    MODEL_SUM=x-ai/grok-code-fast-1
    MODEL_GEN=google/gemini-2.5-flash-lite
    SPINNER_ENABLED=true
    HISTORY_LIMIT=20
    USE_HISTORY=true

Analytics:
  Stats stored in $STATS_PATH
EOF
}

load_config() {
  [[ ! -f "$CONFIG_PATH" ]] && return
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^\s*# ]] && continue
    key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      MODEL_SUM) MODEL_SUM="$value" ;;
      MODEL_GEN) MODEL_GEN="$value" ;;
      SPINNER_ENABLED) [[ "$value" =~ ^(false|0|no)$ ]] && SPINNER_ENABLED=false || SPINNER_ENABLED=true ;;
      HISTORY_LIMIT) HISTORY_LIMIT="$value" ;;
      USE_HISTORY) [[ "$value" =~ ^(false|0|no)$ ]] && USE_HISTORY=false || USE_HISTORY=true ;;
    esac
  done < "$CONFIG_PATH"
}

update_stats() {
  local status=$1
  mkdir -p "$CONFIG_DIR"
  local total=0 successes=0 failures=0
  if [[ -f "$STATS_PATH" ]]; then
    read -r total successes failures < <(jq -r '.total_runs // 0,.successes // 0,.failures // 0' "$STATS_PATH" 2>/dev/null || printf '0\n0\n0\n')
  fi
  total=$((total + 1))
  [[ "$status" == "success" ]] && successes=$((successes + 1)) || failures=$((failures + 1))
  
  jq -n \
    --argjson total "$total" \
    --argjson successes "$successes" \
    --argjson failures "$failures" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{total_runs:$total,successes:$successes,failures:$failures,last_run:$timestamp}' > "$STATS_PATH"
}

spinner() {
  local pid=$1
  local message=$2
  local start_time=$(date +%s)
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  if ! $SPINNER_ENABLED; then
    wait "$pid"
    return
  fi
  tput civis >&2 2>/dev/null || true
  CURSOR_HIDDEN=true
  while kill -0 "$pid" 2>/dev/null; do
    local elapsed=$(( $(date +%s) - start_time ))
    printf '\r\033[36m%s %s... %02ds\033[0m' "${frames[i]}" "$message" "$elapsed" >&2
    i=$(((i + 1) % ${#frames[@]}))
    sleep 0.1
  done
  tput cnorm >&2 2>/dev/null || true
  CURSOR_HIDDEN=false
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config) shift; CONFIG_PATH="$1" ;;
      --model-sum) shift; MODEL_SUM="$1" ;;
      --model-gen) shift; MODEL_GEN="$1" ;;
      --no-spinner) SPINNER_ENABLED=false ;;
      --dry-run) DRY_RUN=true ;;
      --help) print_help; exit 0 ;;
      *) echo "❌ Error: Unknown option '$1'" >&2; exit 1 ;;
    esac
    shift
  done
}

capture_git_state() {
  local diff_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-diff.XXXXXX")
  local status_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-status.XXXXXX")
  local numstat_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-numstat.XXXXXX")
  local summary_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-summary.XXXXXX")
  local history_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-history.XXXXXX")
  TMP_ITEMS+=("$diff_file" "$status_file" "$numstat_file" "$summary_file" "$history_file")

  # Compact diff with minimal context and no space noise
  git diff --cached -U1 --no-prefix --ignore-space-change > "$diff_file" &
  local p1=$!
  # File status (A, M, D, R...)
  git diff --cached --name-status > "$status_file" &
  local p2=$!
  # Exact line counts per file
  git diff --cached --numstat > "$numstat_file" &
  local p3=$!
  # Single line summary
  git diff --cached --stat | tail -1 > "$summary_file" &
  local p4=$!

  if $USE_HISTORY; then
    git log -"$HISTORY_LIMIT" --oneline > "$history_file" &
  fi
  local p5=$!

  wait "$p1" "$p2" "$p3" "$p4" "$p5"

  if [[ ! -s "$diff_file" && ! -s "$status_file" ]]; then
    echo "⚠️  No staged changes to commit." >&2
    exit 0
  fi

  DIFF_COMPACT=$(<"$diff_file")
  DIFF_STATUS=$(<"$status_file")
  DIFF_NUMSTAT=$(<"$numstat_file")
  DIFF_STAT_SUMMARY=$(<"$summary_file")
  [[ -s "$history_file" ]] && HISTORY=$(<"$history_file")
}

call_api() {
  local model=$1
  local payload=$2
  local msg=$3
  local response_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-api.XXXXXX")
  TMP_ITEMS+=("$response_file")

  local helper="$SCRIPT_DIR/openrouter"
  "$helper" --model "$model" "$payload" > "$response_file" 2>/dev/null &
  local pid=$!
  spinner "$pid" "$msg"
  wait "$pid" || true
  
  RESPONSE_CONTENT=$(cat "$response_file")
}

summarize_changes() {
  local prompt=$(cat <<EOF
You are a technical code analyst. Analyze the provided git metadata and code diff.
Identify the core semantic changes, distinguishing between:
1. Major architectural changes (new tools, scripts, core logic).
2. Refactorings and standardizations (e.g., symlinks, file moves).
3. Minor configuration tweaks and dependency updates.

Use DIFF_STATUS (file operations) and DIFF_NUMSTAT (impact size) to weigh the importance.
Output a concise technical summary of what was actually changed.
EOF
)
  local payload=$(jq -n \
    --arg p "$prompt" \
    --arg dc "$DIFF_COMPACT" \
    --arg ds "$DIFF_STATUS" \
    --arg dn "$DIFF_NUMSTAT" \
    --arg dss "$DIFF_STAT_SUMMARY" \
    '{instruction:$p, context:{diff_compact:$dc, diff_status:$ds, diff_numstat:$dn, diff_stat_summary:$dss}}')
  
  call_api "$MODEL_SUM" "$payload" "🤖 Analyzing code structure (Grok)"
  RAW_SUMMARY="$RESPONSE_CONTENT"
}

generate_commit() {
  local prompt=$(cat <<EOF
Write exactly ONE Conventional Commit message following strictly this format:
<type>(<scope>): <subject>

where:
- type: feat|fix|docs|style|refactor|perf|test|build|ci|chore
- scope: short noun describing changed area (optional)
- subject: lowercase imperative, no period, max 72 chars
- body: optional additional lines for key details

RULES:
1. Base the message ONLY on the provided <technical_summary>.
2. Choose the most significant change for the subject line.
3. Use a broad scope (e.g., devtools, dotfiles) if many areas are affected.
4. If a file was replaced by a symlink, call it "centralization" or "standardization".
5. Output ONLY the commit message (subject with optional body).
EOF
)
  local payload=$(jq -n --arg p "$prompt" --arg s "$RAW_SUMMARY" --arg h "$HISTORY" \
    '{instruction:$p, context:{technical_summary:$s, recent_history:$h}}')
  
  call_api "$MODEL_GEN" "$payload" "✍️  Formatting commit message (Gemini)"
  RESPONSE="$RESPONSE_CONTENT"
}

validate_response() {
  local cleaned=$(echo "$1" | sed -e 's/^[[:space:]"'\''`]*//' -e 's/[[:space:]"'\''`]*$//')
  if [[ -z "$cleaned" ]]; then
    echo "❌ Error: Received empty message after processing."
    update_stats failure
    exit 1
  fi
  CLEAN_RESPONSE="$cleaned"
}

main() {
  load_config
  parse_args "$@"
  require_command git
  capture_git_state
  summarize_changes
  echo "" >&2 # Clear line after spinner
  generate_commit
  echo "" >&2 # Clear line after spinner
  validate_response "$RESPONSE"
  
  # Remove any remaining ANSI escape codes just in case
  CLEAN_RESPONSE=$(echo "$CLEAN_RESPONSE" | sed $'s/\e\[[0-9;]*[a-zA-Z]//g')

  echo "✅ Generated:"
  echo "$CLEAN_RESPONSE"
  echo ""

  if $DRY_RUN; then
    echo "ℹ️ Dry run: skipping git commit."
    exit 0
  fi

  if git commit -e -m "$CLEAN_RESPONSE"; then
    update_stats success
  else
    update_stats failure
    exit 1
  fi
}

main "$@"
