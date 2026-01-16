#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="${AI_COMMIT_CONFIG_DIR:-$HOME/.config/ai-commit}"
CONFIG_PATH="${AI_COMMIT_CONFIG:-$CONFIG_DIR/config}"
STATS_PATH="${AI_COMMIT_STATS:-$CONFIG_DIR/stats.json}"
VALID_SCOPES_PATH="${AI_COMMIT_SCOPES:-$CONFIG_DIR/valid-scopes.json}"

# Default values
MODEL_SUM="google/gemini-3-flash-preview"
MODEL_SUM_FAST="google/gemini-3-flash-preview"
MODEL_GEN="google/gemini-3-flash-preview"
FAST_MODE=false
AUTO_FAST_THRESHOLD=40
SPINNER_ENABLED=true
CURSOR_HIDDEN=false
DRY_RUN=false
COPY_TO_CLIPBOARD=false
VERBOSE=false
HISTORY_LIMIT=20
USE_HISTORY=true
TMP_ITEMS=()
DIFF_COMPACT=""
DIFF_STATUS=""
DIFF_NUMSTAT=""
DIFF_STAT_RAW=""
DIFF_STAT_SUMMARY=""
PROJECT_NAME=""
PROJECT_DETAILS=""
HISTORY=""
SEMANTIC_WEIGHTS=""
RAW_SUMMARY=""
RESPONSE=""
SCOPES_JSON=""
STRICT_SCOPES=false

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
  --fast, -f          Use fast summarization model (default: $MODEL_SUM_FAST)
  --no-spinner        Disable animated spinner output
  --no-progress       Disable all progress spinners and timing output
  --dry-run           Print the message without committing
  --copy              Copy the generated message to clipboard
  --verbose           Print summarizer output before generating commit
  --help              Show this help message and exit


Configuration file ($CONFIG_PATH):
  KEY=VALUE pairs, e.g.:
    MODEL_SUM=x-ai/grok-code-fast-1
    MODEL_SUM_FAST=google/gemini-2.0-flash-lite
    MODEL_GEN=google/gemini-2.0-flash-lite
    AUTO_FAST_THRESHOLD=40
    SPINNER_ENABLED=true
    HISTORY_LIMIT=20
    USE_HISTORY=true

Analytics:
  Stats stored in $STATS_PATH
EOF
}

load_config() {
  [[ ! -f "$CONFIG_PATH" ]] && return
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    
    # Trim whitespace and normalize key
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    key="${key^^}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    
    case "$key" in
      MODEL_SUM) MODEL_SUM="$value" ;;
      MODEL_SUM_FAST) MODEL_SUM_FAST="$value" ;;
      MODEL_GEN) MODEL_GEN="$value" ;;
      AUTO_FAST_THRESHOLD) AUTO_FAST_THRESHOLD="$value" ;;
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

analyze_diff_semantics() {
  local numstat="$1"
  local logic_score=0
  local config_score=0
  local data_score=0

  while read -r added deleted file; do
    [[ -z "$file" ]] && continue
    # Handle binary files (git numstat returns '-' for binary changes)
    [[ "$added" == "-" ]] && added=0
    [[ "$deleted" == "-" ]] && deleted=0
    
    case "$file" in
      *.sh|*.js|*.py|*.lua|*.ts|*.tsx|*.jsx|*.go|*.rs|*.c|*.cpp|*.h|*.hpp|*.swift|*.kt|*.java|*.rb|*.php)
        logic_score=$((logic_score + added + deleted))
        ;;
      *.json|*.yaml|*.yml|*.toml|*.conf|*rc|*.xml|*.gradle|*.props)
        config_score=$((config_score + added + deleted))
        ;;
      *.lock|*.md|*.txt|*.svg|*.png|*.jpg|*.jpeg)
        data_score=$((data_score + added + deleted))
        ;;
      *)
        config_score=$((config_score + added + deleted))
        ;;
    esac
  done <<< "$numstat"

  SEMANTIC_WEIGHTS=$(jq -n \
    --argjson logic "$logic_score" \
    --argjson config "$config_score" \
    --argjson data "$data_score" \
    '{logic_score:$logic, config_score:$config, data_score:$data}')
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
       --fast|-f) FAST_MODE=true ;;
       --no-spinner|--no-progress) SPINNER_ENABLED=false ;;
       --dry-run) DRY_RUN=true ;;
       --copy) COPY_TO_CLIPBOARD=true ;;
       --verbose) VERBOSE=true ;;
       --help) print_help; exit 0 ;;
       *) echo "❌ Error: Unknown option '$1'" >&2; exit 1 ;;
     esac
     shift
   done

}

compress_diff() {
  # Compresses consecutive deleted lines in git diff to save tokens.
  # Keeps up to 2 deleted lines, then summarizes.
  awk '
    /^-/ && !/^--- / {
      count++
      if (count <= 2) print $0
      next
    }
    {
      if (count > 2) printf "--- [%d lines deleted]\n", count
      count = 0
      print $0
    }
    END { if (count > 2) printf "--- [%d lines deleted]\n", count }
  '
}

capture_git_state() {
  DIFF_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-diff.XXXXXX")
  local RAW_DIFF_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-diff-raw.XXXXXX")
  STATUS_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-status.XXXXXX")
  NUMSTAT_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-numstat.XXXXXX")
  STAT_RAW_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-stat-raw.XXXXXX")
  SUMMARY_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-summary.XXXXXX")
  HISTORY_FILE=$(mktemp "${TMPDIR:-/tmp}/ai-commit-history.XXXXXX")
  TMP_ITEMS+=("$DIFF_FILE" "$RAW_DIFF_FILE" "$STATUS_FILE" "$NUMSTAT_FILE" "$STAT_RAW_FILE" "$SUMMARY_FILE" "$HISTORY_FILE")

  # Compact diff with minimal context and no space noise
  git diff --cached -U1 --no-prefix --ignore-space-change > "$RAW_DIFF_FILE" &
  local p1=$!
  # File status (A, M, D, R...)
  git diff --cached --name-status > "$STATUS_FILE" &
  local p2=$!
  # Exact line counts per file
  git diff --cached --numstat > "$NUMSTAT_FILE" &
  local p3=$!
  # Full stat for weighting
  git diff --cached --stat > "$STAT_RAW_FILE" &
  local p4=$!
  # Single line summary
  git diff --cached --stat | tail -1 > "$SUMMARY_FILE" &
  local p5=$!

  if $USE_HISTORY; then
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git log -"$HISTORY_LIMIT" --oneline > "$HISTORY_FILE" &
    else
      : > "$HISTORY_FILE" &
    fi
  fi
  local p6=$!

  wait "$p1" "$p2" "$p3" "$p4" "$p5" "$p6" || true

  if [[ ! -s "$RAW_DIFF_FILE" && ! -s "$STATUS_FILE" ]]; then
    echo "⚠️  No staged changes to commit." >&2
    exit 0
  fi

  # Compress deleted lines to save tokens
  compress_diff < "$RAW_DIFF_FILE" > "$DIFF_FILE"

  DIFF_COMPACT=$(<"$DIFF_FILE")
  DIFF_STATUS=$(<"$STATUS_FILE")
  DIFF_NUMSTAT=$(<"$NUMSTAT_FILE")
  DIFF_STAT_RAW=$(<"$STAT_RAW_FILE")
  DIFF_STAT_SUMMARY=$(<"$SUMMARY_FILE")
  [[ -s "$HISTORY_FILE" ]] && HISTORY=$(<"$HISTORY_FILE")

  analyze_diff_semantics "$DIFF_NUMSTAT"

  # Project context
  PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
  if [[ -f "README.md" ]]; then
    PROJECT_DETAILS=$(head -n 50 "README.md")
  fi
}

call_api() {
  local model=$1
  local payload=$2
  local msg=$3
  local response_file=$(mktemp "${TMPDIR:-/tmp}/ai-commit-api.XXXXXX")
  TMP_ITEMS+=("$response_file")

  local helper="$SCRIPT_DIR/openrouter"
  "$helper" --model "$model" "$payload" > "$response_file" &
  local pid=$!
  spinner "$pid" "$msg"
  if ! wait "$pid"; then
    echo "❌ Error: API request failed." >&2
    update_stats failure
    exit 1
  fi
  
  RESPONSE_CONTENT=$(cat "$response_file")
}

resolve_scopes() {
  # Default fallback if no file exists
  SCOPES_JSON='{
    "scopes": {
      "core": {"desc": "Business logic"},
      "cli": {"desc": "Command line interface"},
      "workflow": {"desc": "CI/CD and automation"},
      "dev-env": {"desc": "Development environment config"},
      "deps": {"desc": "Dependencies"},
      "docs": {"desc": "Documentation"},
      "ui": {"desc": "Visual elements and themes"}
    }
  }'
  
  if [[ -f "$VALID_SCOPES_PATH" ]]; then
    SCOPES_JSON=$(cat "$VALID_SCOPES_PATH")
  fi

  if [[ -f ".ai-commit-scopes.json" ]]; then
    SCOPES_JSON=$(cat ".ai-commit-scopes.json")
    STRICT_SCOPES=true
  fi
}

summarize_changes() {
  local scope_constraint="1. You MUST use the provided \"valid_scopes\" to categorize the change."
  if ! $STRICT_SCOPES; then
    scope_constraint="1. You SHOULD prefer the provided \"valid_scopes\", but MAY use a project-specific kebab-case scope if none fit perfectly."
  fi

  local prompt=$(cat <<EOF
You are a Technical Architect. Analyze the git diff and metadata.
Produce a "Functional Manifest" as a minified JSON object.

Constraints:
${scope_constraint}
2. If multiple domains exist, identify the "primary_scope" based on the "semantic_weights" (Logic > Config).
3. If changes are disjoint, suggest an "umbrella_scope" from the valid list.
4. LOGIC BIAS: If ANY executable script (.sh, .py, .js, .lua, .ts) is modified, it MUST be listed as its own separate DOMAIN in the "domains" array. ALWAYS assign these logic domains a weight of 50 or higher.
5. PRIMARY SELECTION: You MUST select a logic-based scope (e.g., cli, core, workflow) as the "primary_scope" if any logic domain exists, even if config changes are more numerous.

JSON Structure:
{
  "domains": [{ "name": "...", "weight": 70, "priority": "High", "lca": "...", "scopes": ["..."], "change": "..." }],
  "primary_scope": "...",
  "disjointness": true/false,
  "why": "...",
  "style_hints": "..."
}

ENTITY PRESERVATION RULE:
- NEVER "autocorrect" or rename libraries, packages, or plugins.
- Use the EXACT casing and spelling found in the code or diff (e.g., "conform.nvim", "basedpyright", "ai-commit.sh").
- If a word looks like a technical name (contains a dot, kebab-case, or CamelCase), treat it as a rigid proper noun.
EOF
)

  local payload=$(jq -n \
    --arg p "$prompt" \
    --rawfile dc "$DIFF_FILE" \
    --rawfile ds "$STATUS_FILE" \
    --rawfile dn "$NUMSTAT_FILE" \
    --rawfile dss "$SUMMARY_FILE" \
    --argjson vs "$SCOPES_JSON" \
    --argjson sw "$SEMANTIC_WEIGHTS" \
    '{instruction:$p, context:{diff_compact:$dc, diff_status:$ds, diff_numstat:$dn, diff_stat_summary:$dss, valid_scopes:$vs, semantic_weights:$sw}}')
  
  local payload_size=${#payload}
  local est_tokens=$((payload_size / 4))
  local model_to_use="$MODEL_SUM"
  local model_label="$MODEL_SUM"
  if $FAST_MODE; then
    model_to_use="$MODEL_SUM_FAST"
    model_label="Fast Mode"
  fi

  call_api "$model_to_use" "$payload" "🤖 Analyzing code structure ($model_label) [~${est_tokens} tokens]"
  RAW_SUMMARY="$RESPONSE_CONTENT"

  if $VERBOSE; then
    echo "🔎 Functional Manifest (Raw):" >&2
    echo "$RAW_SUMMARY" >&2
    echo "🔎 Functional Manifest (Parsed):" >&2
    echo "$RAW_SUMMARY" | jq . 2>/dev/null || echo "⚠️  Warning: Grok output is not valid JSON." >&2
    echo "" >&2
  fi
}

generate_commit() {
  local prompt=$(cat <<EOF
Generate a Conventional Commit message based on the provided JSON "technical_manifest".

Format: <type>(<scope>): <subject>
[optional body]

Constraints for Generator:
1. SCOPE SELECTION:
   - You MUST use the "primary_scope" value from the technical_manifest. 
   - NEVER combine different domain names into a single scope.
2. SUBJECT LINE:
   - Subject must be lowercase, imperative, no trailing dot.
   - Summarize the ONE most important technical achievement of the PRIMARY domain.
   - ABSOLUTE RULE: No "and" or "&" in the subject line. If you have two ideas, DELETE the less important one.
   - Example of WRONG subject: "integrate lsp and update scripts" (Too many topics).
   - Example of RIGHT subject: "implement interactive retry logic" (Single topic).
3. BANNED VOCABULARY:
   - NEVER use (in subject OR body): update, improve, enhance, fix, tweak, modify, change.
   - INSTEAD use: integrate, implement, refactor, simplify, adopt, migrate, add, remove, streamline.
4. BODY PROTOCOL:
   - Maximum 3-4 bullet points total.
   - Group minor config changes into a single bullet.
   - Final bullet should summarize secondary domains if they were excluded from the subject.
5. NO PREAMBLE: Output ONLY the commit message.
6. ENTITY PRESERVATION:
   - NEVER "autocorrect" or rename libraries, packages, or plugins from the manifest.
   - Use the EXACT casing and spelling provided in the "domains" or "change" fields.
   - Example: If input says "conform.nvim", DO NOT write "Conduit" or "Conform".
EOF
)

  # Save RAW_SUMMARY to a temporary file to use with --rawfile
  local summary_tmp=$(mktemp "${TMPDIR:-/tmp}/ai-commit-raw-summary.XXXXXX")
  echo "$RAW_SUMMARY" > "$summary_tmp"
  TMP_ITEMS+=("$summary_tmp")

  local payload=$(jq -n --arg p "$prompt" --rawfile s "$summary_tmp" --arg h "$HISTORY" --rawfile st "$STAT_RAW_FILE" \
    '{instruction:$p, context:{technical_manifest:$s, recent_history:$h, diff_stat:$st}}')
  
  local payload_size=${#payload}
  local est_tokens=$((payload_size / 4))
  call_api "$MODEL_GEN" "$payload" "✍️  Formatting commit message ($MODEL_GEN) [~${est_tokens} tokens]"
  RESPONSE="$RESPONSE_CONTENT"
  if [[ -z "$RESPONSE" ]]; then
    echo "❌ Error: $MODEL_GEN returned empty response." >&2
  fi
}


validate_response() {
  local cleaned="$1"
  # Clean markdown, preambles, and extra whitespace/quotes in one pass
  CLEAN_RESPONSE=$(echo "$cleaned" | sed -E \
    -e '/^```/d' \
    -e '/^[Hh]ere is/d' \
    -e '/^[Cc]ommit message/d' \
    -e 's/^[[:space:]"'\''`]*//' \
    -e 's/[[:space:]"'\''`]*$//')
  
  if [[ -z "$CLEAN_RESPONSE" ]]; then
    echo "❌ Error: Received empty message after processing."
    update_stats failure
    exit 1
  fi
}

main() {
  load_config
  parse_args "$@"
  resolve_scopes
  require_command git
  require_command jq
  require_command tput

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not a git repository." >&2
    exit 1
  fi

  capture_git_state

  # Auto-fast mode based on diff size
  local total_lines=0
  if [[ -n "$SEMANTIC_WEIGHTS" ]]; then
    total_lines=$(echo "$SEMANTIC_WEIGHTS" | jq '.logic_score + .config_score + .data_score' 2>/dev/null || echo 0)
    if ! $FAST_MODE && [[ "$total_lines" =~ ^[0-9]+$ ]] && (( total_lines < AUTO_FAST_THRESHOLD )); then
      FAST_MODE=true
      echo "🚀 Small change detected ($total_lines lines), auto-enabling fast mode..." >&2
    fi
  fi

  summarize_changes
  echo "" >&2 # Clear line after spinner
  generate_commit
  echo "" >&2 # Clear line after spinner
  validate_response "$RESPONSE"
  
  # Remove any remaining ANSI escape codes just in case
  CLEAN_RESPONSE=$(echo "$CLEAN_RESPONSE" | sed $'s/\e\[[0-9;]*[a-zA-Z]//g')

  # Final safety check for banned words
  local banned_match=$(echo "$CLEAN_RESPONSE" | grep -Ei "\<(update|improve|enhance|fix|change|tweak|modify)\>" || true)
  if [[ -n "$banned_match" ]]; then
     echo "⚠️  Note: Message contains potentially generic verbs ($banned_match)." >&2
  fi

  # Scope Validation
  local current_scope=$(echo "$CLEAN_RESPONSE" | sed -n 's/^[a-z]*(\([^)]*\)):.*/\1/p')
  if [[ -n "$current_scope" ]]; then
    if ! jq -e --arg s "$current_scope" '.scopes | has($s)' <<< "$SCOPES_JSON" >/dev/null 2>&1; then
      echo "⚠️  Warning: Scope '$current_scope' is not in the valid list." >&2
      if $STRICT_SCOPES; then
        echo "🛡️  Strict mode: Prepending [REVIEW]." >&2
        CLEAN_RESPONSE="[REVIEW] $CLEAN_RESPONSE"
      fi
    fi
  fi

  echo "✅ Generated:"
  echo -e "\033[32m$CLEAN_RESPONSE\033[0m"
  echo ""

  if $COPY_TO_CLIPBOARD; then
    if command -v pbcopy >/dev/null 2>&1; then
      echo "$CLEAN_RESPONSE" | pbcopy
      echo "📋 Message copied to clipboard."
    elif command -v wl-copy >/dev/null 2>&1; then
      echo "$CLEAN_RESPONSE" | wl-copy
      echo "📋 Message copied to clipboard."
    elif command -v xclip >/dev/null 2>&1; then
      echo "$CLEAN_RESPONSE" | xclip -selection clipboard
      echo "📋 Message copied to clipboard."
    fi
  fi

  if $DRY_RUN; then
    echo "ℹ️ Dry run: skipping git commit."
    exit 0
  fi

  while true; do
    echo -n "Action: [y]es, [e]dit, [r]etry, [n]o? "
    read -r -n 1 opt
    echo ""
    case "$opt" in
      y|Y)
        if git commit -m "$CLEAN_RESPONSE"; then
          update_stats success
          exit 0
        else
          update_stats failure
          exit 1
        fi
        ;;
      e|E)
        if git commit -e -m "$CLEAN_RESPONSE"; then
          update_stats success
          exit 0
        else
          update_stats failure
          exit 1
        fi
        ;;
      r|R)
        echo -n "Retry: [f]ull restart or [s]ummary only? "
        read -r -n 1 retry_opt
        echo ""
        if [[ "$retry_opt" == "f" || "$retry_opt" == "F" ]]; then
          exec "$0" "$@" # Re-execute the script with same args
        else
          generate_commit
          validate_response "$RESPONSE"
          CLEAN_RESPONSE=$(echo "$CLEAN_RESPONSE" | sed $'s/\e\[[0-9;]*[a-zA-Z]//g')
          echo "✅ Re-generated:"
          echo -e "\033[32m$CLEAN_RESPONSE\033[0m"
          echo ""
          continue
        fi
        ;;
      n|N)
        echo "❌ Aborted."
        exit 0
        ;;
      *)
        echo "Invalid option. Please use y, e, r, or n."
        ;;
    esac
  done
}

main "$@"
