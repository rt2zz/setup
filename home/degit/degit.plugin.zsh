# degit - Git to jj translator plugin
# Intercepts git commands in jj repositories and suggests jj equivalents using OpenAI

# Configuration
: ${DEGIT_TIMEOUT:=30}
: ${DEGIT_MODEL_FAST:="gpt-5-nano"}
: ${DEGIT_MODEL_THINK:="gpt-5.2"}
: ${DEGIT_DEBUG:=0}

# Debug logging helper
_degit_debug() {
  if [[ "$DEGIT_DEBUG" == "1" ]]; then
    printf '\033[38;5;243m[degit debug] %s\033[0m\n' "$1" >&2
  fi
}

# Store the real git path
_DEGIT_REAL_GIT="${commands[git]:-$(command -v git)}"

# Spinner frames for loading animation
_degit_spinner_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Show spinner in background while waiting
_degit_show_spinner() {
  local i=0
  while true; do
    printf '\r  %s Translating...' "${_degit_spinner_frames[$((i % 10 + 1))]}"
    sleep 0.1
    ((i++))
  done
}

# Stop the spinner
_degit_stop_spinner() {
  local pid=$1
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  fi
  printf '\r\033[K'  # Clear the line
}

# System prompt for the LLM (translation mode)
_degit_system_prompt() {
  cat <<'EOF'
<role>
You are a git-to-jj command translator. You help users transition from git to jj (Jujutsu).
</role>

<task>
Translate the given git command to its jj equivalent. Be terse.
</task>

<jj_reference>
## Core Concepts
- Working copy is always a commit (no staging area)
- Changes are auto-tracked; use `jj file track` for new files only
- `@` refers to the working copy commit

## Command Mappings
| git | jj | notes |
|-----|----|----|
| status | status | |
| log | log | |
| diff | diff | |
| add <file> | file track <file> | only for new files |
| commit -m "msg" | commit -m "msg" | |
| commit --amend | squash | squash into parent |
| commit --amend -m | describe -m "msg" | message only |
| checkout <ref> | edit <rev> | or `jj new <rev>` |
| checkout -b <name> | new && bookmark create <name> | |
| branch | bookmark list | |
| branch <name> | bookmark create <name> | |
| merge <branch> | new <rev1> <rev2> | creates merge |
| rebase <base> | rebase -d <dest> | |
| cherry-pick <ref> | duplicate <rev> | |
| stash | new | changes already committed |
| reset --hard | abandon | |
| push | git push | |
| pull | git fetch && rebase | |
| fetch | git fetch | |

## Common Workflows
- Amend current commit: `jj squash` or `jj describe -m "new msg"`
- Undo last operation: `jj undo`
- View operation history: `jj op log`
- Split a commit: `jj split`
- Move changes between commits: `jj squash --from <src> --into <dest>`
</jj_reference>

<output_rules>
- jjEquivalent: exact jj command to run, or null if no direct equivalent
- explanation: one sentence max explaining the translation
- Preserve user's arguments (paths, refs, messages) in the translation
</output_rules>
EOF
}

# Call OpenAI Chat Completions API (for fast mode)
_degit_call_chat_completions() {
  local user_message="$1"
  local system_prompt="$2"

  _degit_debug "Using Chat Completions API with $DEGIT_MODEL_FAST"

  local json_payload
  json_payload=$(jq -n \
    --arg model "$DEGIT_MODEL_FAST" \
    --arg system "$system_prompt" \
    --arg user "$user_message" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $user}
      ],
      max_completion_tokens: 16384,
      reasoning_effort: "low",
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "jj_translation",
          strict: true,
          schema: {
            type: "object",
            properties: {
              jjEquivalent: {
                type: ["string", "null"],
                description: "The jj command equivalent, or null if no equivalent exists"
              },
              explanation: {
                type: "string",
                description: "Brief explanation of the translation or why there is no equivalent"
              }
            },
            required: ["jjEquivalent", "explanation"],
            additionalProperties: false
          }
        }
      }
    }')

  local curl_exit_code
  local response
  response=$(curl -s --max-time "$DEGIT_TIMEOUT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$json_payload" \
    "https://api.openai.com/v1/chat/completions" 2>&1)
  curl_exit_code=$?

  _degit_debug "curl exit code: $curl_exit_code"
  _degit_debug "Raw response: $response"

  if [[ $curl_exit_code -ne 0 ]]; then
    _degit_debug "curl failed with exit code $curl_exit_code"
    echo "ERROR: API request failed (curl exit $curl_exit_code)"
    return 1
  fi

  # Check if response is valid JSON (use printf to avoid echo interpreting escapes)
  if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    _degit_debug "Response is not valid JSON"
    echo "ERROR: Invalid JSON response"
    return 1
  fi

  # Check for API error
  if printf '%s' "$response" | jq -e '.error != null' >/dev/null 2>&1; then
    local error
    error=$(printf '%s' "$response" | jq -r '.error.message // "Unknown error"')
    _degit_debug "API error: $error"
    echo "ERROR: $error"
    return 1
  fi

  # Return parsed content from Chat Completions format
  _degit_debug "Parsing Chat Completions response"
  printf '%s' "$response" | jq -r '.choices[0].message.content'
}

# Call OpenAI Responses API (for think mode with web search)
_degit_call_responses() {
  local user_message="$1"
  local system_prompt="$2"

  _degit_debug "Using Responses API with $DEGIT_MODEL_THINK (web search enabled)"

  local json_payload
  json_payload=$(jq -n \
    --arg model "$DEGIT_MODEL_THINK" \
    --arg input "$user_message" \
    --arg instructions "$system_prompt" \
    '{
      model: $model,
      input: $input,
      instructions: $instructions,
      tools: [{"type": "web_search"}],
      text: {
        format: {
          type: "json_schema",
          name: "jj_translation",
          strict: true,
          schema: {
            type: "object",
            properties: {
              jjEquivalent: {type: ["string", "null"]},
              explanation: {type: "string"}
            },
            required: ["jjEquivalent", "explanation"],
            additionalProperties: false
          }
        }
      }
    }')

  local curl_exit_code
  local response
  response=$(curl -s --max-time "$DEGIT_TIMEOUT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$json_payload" \
    "https://api.openai.com/v1/responses" 2>&1)
  curl_exit_code=$?

  _degit_debug "curl exit code: $curl_exit_code"
  _degit_debug "Raw response: $response"

  if [[ $curl_exit_code -ne 0 ]]; then
    _degit_debug "curl failed with exit code $curl_exit_code"
    echo "ERROR: API request failed (curl exit $curl_exit_code)"
    return 1
  fi

  # Check if response is valid JSON (use printf to avoid echo interpreting escapes)
  if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    _degit_debug "Response is not valid JSON"
    echo "ERROR: Invalid JSON response"
    return 1
  fi

  # Check for API error (handle null error field)
  if printf '%s' "$response" | jq -e '.error != null' >/dev/null 2>&1; then
    local error
    error=$(printf '%s' "$response" | jq -r '.error.message // "Unknown error"')
    _degit_debug "API error: $error"
    echo "ERROR: $error"
    return 1
  fi

  # Return parsed content from Responses API format
  # The response has .output[] array with message type containing the text
  _degit_debug "Parsing Responses API response"
  printf '%s' "$response" | jq -r '.output[] | select(.type == "message") | .content[0].text'
}

# Dispatcher: calls the appropriate API based on model
_degit_call_openai() {
  local user_message="$1"
  local system_prompt="$2"
  local model="${3:-$DEGIT_MODEL_FAST}"

  _degit_debug "Model: $model"
  _degit_debug "User message: $user_message"

  if [[ "$model" == "$DEGIT_MODEL_THINK" ]]; then
    _degit_call_responses "$user_message" "$system_prompt"
  else
    _degit_call_chat_completions "$user_message" "$system_prompt"
  fi
}

# Present options menu to user
_degit_present_options() {
  local git_cmd="$1"
  local jj_cmd="$2"
  local explanation="$3"

  _degit_debug "present_options called with:"
  _degit_debug "  git_cmd='$git_cmd'"
  _degit_debug "  jj_cmd='$jj_cmd'"
  _degit_debug "  explanation='$explanation'"

  local has_git=false
  local has_jj=false

  [[ -n "$git_cmd" ]] && has_git=true
  [[ -n "$jj_cmd" ]] && has_jj=true

  _degit_debug "  has_git=$has_git, has_jj=$has_jj"

  # No options available
  if ! $has_git && ! $has_jj; then
    print -P "%F{yellow}No action available.%f"
    [[ -n "$explanation" ]] && echo "$explanation"
    return 1
  fi

  # Show suggested command and explanation (use printf to avoid print -P interpreting content)
  if $has_jj; then
    print -P "\n%F{cyan}Suggested jj command:%f"
    printf '  \033[32m%s\033[0m\n' "$jj_cmd"
    [[ -n "$explanation" ]] && printf '\033[38;5;243m  %s\033[0m\n' "$explanation"
    echo
  else
    print -P "\n%F{yellow}No jj equivalent%f"
    [[ -n "$explanation" ]] && echo "  $explanation"
    echo
  fi

  # Build prompt (use printf for dynamic content to avoid interpretation)
  $has_git && printf '\033[34m[G]\033[0m git %s  ' "$git_cmd"
  $has_jj && printf '\033[32m[J]\033[0m %s  ' "$jj_cmd"
  printf '\033[31m[C]\033[0m cancel\n'
  printf "> "

  # Read single keypress
  local choice
  read -k1 choice
  echo  # newline after keypress

  case "${choice:l}" in
    g)
      if $has_git; then
        print -z "git --really ${git_cmd}"
        return 0
      else
        print -P "%F{red}Git command not available%f"
        return 1
      fi
      ;;
    j)
      if $has_jj; then
        print -z "$jj_cmd"
        return 0
      else
        print -P "%F{red}jj command not available%f"
        return 1
      fi
      ;;
    *)
      print -P "%F{yellow}Cancelled%f"
      return 130
      ;;
  esac
}

# Main intercept function
_degit_intercept() {
  local model="$1"
  shift
  local git_args="$*"
  local spinner_pid=""

  _degit_debug "Intercepting: git $git_args (model: $model)"

  # Trap Ctrl+C
  trap '_degit_stop_spinner $spinner_pid; print -P "\n%F{yellow}Cancelled%f"; trap - INT; return 130' INT

  # Check for jq dependency
  if ! command -v jq &>/dev/null; then
    trap - INT
    print -P "%F{red}degit: jq is required but not installed%f"
    command "$_DEGIT_REAL_GIT" "$@"
    return $?
  fi

  # Check for API key
  if [[ -z "$OPENAI_API_KEY" ]]; then
    trap - INT
    print -P "%F{yellow}degit: OPENAI_API_KEY not set, running git directly%f"
    command "$_DEGIT_REAL_GIT" "$@"
    return $?
  fi

  # Start spinner in background
  _degit_show_spinner &
  spinner_pid=$!

  # Call OpenAI
  local response
  response=$(_degit_call_openai "Translate this git command to jj: git $git_args" "$(_degit_system_prompt)" "$model")
  local openai_exit=$?

  # Stop spinner
  _degit_stop_spinner $spinner_pid

  # Clear trap
  trap - INT

  _degit_debug "OpenAI call exit code: $openai_exit"

  # Check for error
  if [[ "$response" == ERROR:* ]]; then
    print -P "%F{red}API error%f"
    echo "${response#ERROR: }"
    return 1
  fi

  # Parse JSON response (API functions return the JSON content directly)
  local jj_cmd explanation
  jj_cmd=$(printf '%s' "$response" | jq -r 'if .jjEquivalent == null then "" else .jjEquivalent end')
  explanation=$(printf '%s' "$response" | jq -r '.explanation // ""')

  _degit_debug "Parsed jj_cmd: '$jj_cmd'"
  _degit_debug "Parsed explanation: '$explanation'"

  # Present options
  _degit_present_options "$git_args" "$jj_cmd" "$explanation"
}

# Query mode system prompt
_degit_query_system_prompt() {
  local git_command="$1"
  local query="$2"

  cat <<EOF
<role>
You are a jj (Jujutsu) expert helping a git user.
</role>

<task>
Answer the user's question about jj. Be terse and practical.
</task>

<context>
User invoked: $git_command
User asks: $query
</context>

<jj_reference>
## Core Concepts
- Working copy is always a commit (no staging area)
- Changes are auto-tracked; use \`jj file track\` for new files only
- \`@\` refers to the working copy commit

## Command Mappings
| git | jj | notes |
|-----|----|----|
| status | status | |
| log | log | |
| diff | diff | |
| add <file> | file track <file> | only for new files |
| commit -m "msg" | commit -m "msg" | |
| commit --amend | squash | squash into parent |
| commit --amend -m | describe -m "msg" | message only |
| checkout <ref> | edit <rev> | or \`jj new <rev>\` |
| checkout -b <name> | new && bookmark create <name> | |
| branch | bookmark list | |
| branch <name> | bookmark create <name> | |
| merge <branch> | new <rev1> <rev2> | creates merge |
| rebase <base> | rebase -d <dest> | |
| cherry-pick <ref> | duplicate <rev> | |
| stash | new | changes already committed |
| reset --hard | abandon | |
| push | git push | |
| pull | git fetch && rebase | |
| fetch | git fetch | |

## Common Workflows
- Amend current commit: \`jj squash\` or \`jj describe -m "new msg"\`
- Undo last operation: \`jj undo\`
- View operation history: \`jj op log\`
- Split a commit: \`jj split\`
- Move changes between commits: \`jj squash --from <src> --into <dest>\`
</jj_reference>

<output_rules>
- jjEquivalent: if a specific command answers the question, provide it; otherwise null
- explanation: 2-3 sentences max answering the question directly
</output_rules>
EOF
}

# Query mode - ask LLM arbitrary questions
_degit_query() {
  local git_command="$1"
  local user_query="$2"
  local model="${3:-$DEGIT_MODEL_FAST}"
  local spinner_pid=""

  _degit_debug "Query mode (model: $model)"

  # Trap Ctrl+C
  trap '_degit_stop_spinner $spinner_pid; print -P "\n%F{yellow}Cancelled%f"; trap - INT; return 130' INT

  # Check for jq dependency
  if ! command -v jq &>/dev/null; then
    trap - INT
    print -P "%F{red}degit: jq is required but not installed%f"
    return 1
  fi

  # Check for API key
  if [[ -z "$OPENAI_API_KEY" ]]; then
    trap - INT
    print -P "%F{red}degit: OPENAI_API_KEY not set%f"
    return 1
  fi

  # For query mode, context is embedded in the system prompt
  local user_message="$user_query"
  local system_prompt
  system_prompt=$(_degit_query_system_prompt "$git_command" "$user_query")

  # Start spinner
  _degit_show_spinner &
  spinner_pid=$!

  # Call OpenAI
  local response
  response=$(_degit_call_openai "$user_message" "$system_prompt" "$model")

  # Stop spinner
  _degit_stop_spinner $spinner_pid

  # Clear trap
  trap - INT

  if [[ "$response" == ERROR:* ]]; then
    print -P "%F{red}API error%f"
    echo "${response#ERROR: }"
    return 1
  fi

  # Parse JSON response (API functions return the JSON content directly)
  local jj_cmd explanation
  jj_cmd=$(printf '%s' "$response" | jq -r 'if .jjEquivalent == null then "" else .jjEquivalent end')
  explanation=$(printf '%s' "$response" | jq -r '.explanation // ""')

  # Display response (use printf with ANSI codes to avoid print -P interpreting content)
  echo
  if [[ -n "$jj_cmd" ]]; then
    printf '\033[32m%s\033[0m\n' "$jj_cmd"
  fi
  if [[ -n "$explanation" ]]; then
    printf '\033[38;5;243m%s\033[0m\n' "$explanation"
  fi
  echo

  # Offer options - G for original git, J for jj equivalent
  local has_git=false
  local has_jj=false
  # Extract just the command part from "git <cmd>"
  local git_cmd_only="${git_command#git }"

  [[ -n "$git_cmd_only" ]] && has_git=true
  [[ -n "$jj_cmd" ]] && has_jj=true

  if $has_git || $has_jj; then
    # Build prompt (use printf for dynamic content to avoid interpretation)
    $has_git && printf '\033[34m[G]\033[0m %s  ' "$git_command"
    $has_jj && printf '\033[32m[J]\033[0m %s  ' "$jj_cmd"
    printf '\033[31m[C]\033[0m cancel\n'
    printf "> "

    local choice
    read -k1 choice
    echo

    case "${choice:l}" in
      g)
        if $has_git; then
          print -z "git --really ${git_cmd_only}"
          return 0
        fi
        ;;
      j)
        if $has_jj; then
          print -z "$jj_cmd"
          return 0
        fi
        ;;
      *)
        print -P "%F{yellow}Cancelled%f"
        return 0
        ;;
    esac
  fi
}

# Main git wrapper function
git() {
  # Parse arguments, looking for --really, -q, and --think flags
  local query=""
  local think=0
  local really=0
  local args=()
  local i=1
  while [[ $i -le $# ]]; do
    local arg="${@[$i]}"
    if [[ "$arg" == "-q" ]]; then
      ((i++))
      query="${@[$i]}"
    elif [[ "$arg" == "--think" ]]; then
      think=1
    elif [[ "$arg" == "--really" ]]; then
      really=1
    else
      args+=("$arg")
    fi
    ((i++))
  done

  # Bypass: --really flag (run git immediately)
  if [[ $really -eq 1 ]]; then
    command "$_DEGIT_REAL_GIT" "${args[@]}"
    return $?
  fi

  # Bypass: non-interactive (piped input/output)
  if [[ ! -t 0 || ! -t 1 ]]; then
    command "$_DEGIT_REAL_GIT" "$@"
    return $?
  fi

  # Bypass: GIT_DIR or GIT_WORK_TREE set (likely automated)
  if [[ -n "$GIT_DIR" || -n "$GIT_WORK_TREE" ]]; then
    command "$_DEGIT_REAL_GIT" "$@"
    return $?
  fi

  # Bypass: not in a jj repository
  if ! jj root &>/dev/null; then
    command "$_DEGIT_REAL_GIT" "$@"
    return $?
  fi

  # Select model based on --think flag
  local model="$DEGIT_MODEL_FAST"
  [[ $think -eq 1 ]] && model="$DEGIT_MODEL_THINK"

  # If -q provided, use query mode
  if [[ -n "$query" ]]; then
    _degit_query "git ${args[*]}" "$query" "$model"
  else
    _degit_intercept "$model" "${args[@]}"
  fi
}
