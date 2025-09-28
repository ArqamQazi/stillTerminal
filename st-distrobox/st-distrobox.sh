#!/usr/bin/env bash

# Standalone st-distrobox helper
#
# Reads a stillTerminal profile JSON and ensures a distrobox exists, then enters it.
#
# Usage:
#   st-distrobox --profile-file /path/to/profile.json
#   st-distrobox --profile-id <id>

set -u

SCRIPT_NAME="st-distrobox"

# Debug mode: 0=disabled, 1=enabled
# Can be set via env ST_DISTROBOX_DEBUG or --debug flag
debug_enabled="${ST_DISTROBOX_DEBUG:-0}"

# Name style: underscores (default), as-is, or dashes.
# Can be set via env ST_DISTROBOX_NAME_STYLE or --name-style flag.
name_style="${ST_DISTROBOX_NAME_STYLE:-underscores}"

profile_file=""
requested_profile_id=""

print_usage() {
  cat <<EOF
${SCRIPT_NAME}: ensure and enter a distrobox container from a stillTerminal profile
This is meant to be used internally by stillTerminal for container management.

Usage:
  ${SCRIPT_NAME} --profile-file /path/to/profile.json
  ${SCRIPT_NAME} --profile-id <id>

Options:
  --name-style <style>    One of: underscores, as-is, dashes (default: underscores)
  -h, --help              Show this help and exit
EOF
}

log_err() { printf '%s\n' "$*" >&2; }
status() { printf 'stillTerminal: %s\n' "$*" >&2; }
dbg() { [[ "$debug_enabled" -eq 1 ]] && printf '[DEBUG] %s\n' "$*" >&2; }

clear_screen() {
  if command -v clear >/dev/null 2>&1; then
    clear
  elif command -v tput >/dev/null 2>&1; then
    tput reset
  else
    printf '\033c'
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "${SCRIPT_NAME}: missing required command: $1"; exit 127
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile-file)
      [[ $# -ge 2 ]] || { log_err "${SCRIPT_NAME}: --profile-file needs an argument"; exit 2; }
      profile_file="$2"; shift 2;;
    --profile-id)
      [[ $# -ge 2 ]] || { log_err "${SCRIPT_NAME}: --profile-id needs an argument"; exit 2; }
      requested_profile_id="$2"; shift 2;;
    --name-style)
      [[ $# -ge 2 ]] || { log_err "${SCRIPT_NAME}: --name-style needs an argument"; exit 2; }
      name_style="$2"; shift 2;;
    -h|--help)
      print_usage; exit 0;;
    *)
      log_err "${SCRIPT_NAME}: unknown argument: $1"; print_usage; exit 2;;
  esac
done

require_cmd jq
require_cmd distrobox

# Resolve profile file
if [[ -n "$profile_file" ]]; then
  if [[ ! -f "$profile_file" ]]; then
    log_err "${SCRIPT_NAME}: profile file not found: $profile_file"; exit 1
  fi
elif [[ -n "$requested_profile_id" ]]; then
  profiles_dir="$HOME/.local/share/stillTerminal/profiles"
  if [[ ! -d "$profiles_dir" ]]; then
    log_err "${SCRIPT_NAME}: profiles dir not found: $profiles_dir"; exit 1
  fi
  found_file=""
  # Iterate regular files and match JSON .id
  while IFS= read -r -d '' file; do
    # Skip non-regular files
    [[ -f "$file" ]] || continue
    id=$(jq -r '(.id // "")' "$file" 2>/dev/null || printf '')
    if [[ "$id" == "$requested_profile_id" ]]; then
      found_file="$file"
      break
    fi
  done < <(find "$profiles_dir" -maxdepth 1 -type f -print0 2>/dev/null)
  if [[ -z "$found_file" ]]; then
    log_err "${SCRIPT_NAME}: unable to find profile with id: $requested_profile_id"; exit 1
  fi
  profile_file="$found_file"
else
  log_err "${SCRIPT_NAME}: one of --profile-file or --profile-id is required"; print_usage; exit 2
fi

status "Profile file: $profile_file"

# Extract core fields from profile JSON
profile_id=$(jq -r '(.id // "")' "$profile_file" 2>/dev/null || printf '')
profile_type=$(jq -r '(.type // "system")' "$profile_file" 2>/dev/null || printf '')
spawn_command=$(jq -r '(.spawn_command // "")' "$profile_file" 2>/dev/null || printf '')

if [[ -z "$profile_id" ]]; then
  log_err "${SCRIPT_NAME}: invalid profile: missing id"; exit 1
fi

lc_type=$(printf '%s' "$profile_type" | tr '[:upper:]' '[:lower:]')
if [[ "$lc_type" != "distrobox" ]]; then
  log_err "${SCRIPT_NAME}: not a distrobox profile"; exit 1
fi

# Helper to fetch a string type_param or empty
jq_tp_str() { jq -r --arg k "$1" '(.type_params[$k] // "")' "$profile_file" 2>/dev/null || printf ''; }
jq_tp_bool() { jq -r --arg k "$1" '(.type_params[$k] // "")' "$profile_file" 2>/dev/null | grep -qi '^true$'; }

# Normalize separators in names according to name_style
unify_separators() {
  local s="$1"
  case "$name_style" in
    underscores)
      s=${s//-/_}
      ;;
    dashes)
      s=${s//_/-}
      ;;
    as-is|*) ;;
  esac
  printf '%s' "$s"
}

name=$(jq_tp_str name)
image=$(jq_tp_str image)
[[ -n "$name" ]] || name="stillterminal-$profile_id"
# Apply name style normalization (also affects prefix)
name=$(unify_separators "$name")
[[ -n "$image" ]] || image="docker.io/library/ubuntu:latest"

# Derive hostname: prefer explicit; else use normalized name (to match IDs by default)
explicit_hostname=$(jq_tp_str hostname)
if [[ -z "$explicit_hostname" ]]; then
  explicit_hostname="$name"
fi

# Summarize what will happen
status "Profile '$profile_id' → container '$name' using image '$image'"

container_exists() {
  # Prefer non-interactive list parsing to avoid any potential interactivity in enter
  if distrobox list --no-trunc --json >/dev/null 2>&1; then
    if distrobox list --no-trunc --json | jq -e --arg n "$name" '
        def flat(a): a | (.["containers"]? // .) // [];
        (flat(.) | map(.name) | index($n)) != null
      ' >/dev/null; then
      [[ "$debug_enabled" -eq 1 ]] && dbg "exists check: found via JSON list"
      return 0
    else
      [[ "$debug_enabled" -eq 1 ]] && dbg "exists check: not found via JSON list"
      return 1
    fi
  else
    # Fallback to text parsing
    if distrobox list 2>/dev/null | awk -v n="$name" 'NR>1 && $1==n {found=1} END{exit found?0:1}'; then
      [[ "$debug_enabled" -eq 1 ]] && dbg "exists check: found via text list"
      return 0
    else
      [[ "$debug_enabled" -eq 1 ]] && dbg "exists check: not found via text list"
      return 1
    fi
  fi
}

create_container() {
  local has_nvidia=0
  if [[ -e /dev/nvidia0 || -e /proc/driver/nvidia/version || -x /usr/bin/nvidia-smi ]]; then
    has_nvidia=1
  fi

  # Build arguments
  local args=("distrobox" "create" "-n" "$name" "-i" "$image" "--no-entry" "--yes")
  if [[ "$has_nvidia" -eq 1 ]]; then args+=("--nvidia"); fi

  if jq_tp_bool pull; then args+=("--pull"); fi
  if jq_tp_bool root; then args+=("--root"); fi

  local v
  v=$(jq_tp_str home);      [[ -n "$v" ]] && args+=("--home" "$v")
  v="$explicit_hostname";  if [[ -n "$v" ]]; then v=$(unify_separators "$v"); args+=("--hostname" "$v"); fi
  v=$(jq_tp_str platform);  [[ -n "$v" ]] && args+=("--platform" "$v")
  if jq_tp_bool init; then args+=("--init"); fi
  v=$(jq_tp_str additional_packages); [[ -n "$v" ]] && args+=("--additional-packages" "$v")
  v=$(jq_tp_str additional_flags);    [[ -n "$v" ]] && args+=("--additional-flags" "$v")
  v=$(jq_tp_str pre_init_hooks);      [[ -n "$v" ]] && args+=("--pre-init-hooks" "$v")
  v=$(jq_tp_str init_hooks);          [[ -n "$v" ]] && args+=("--init-hooks" "$v")

  # Volumes can be newline-separated
  local volumes
  volumes=$(jq_tp_str volumes)
  if [[ -n "$volumes" ]]; then
    while IFS= read -r line; do
      line="${line%%$'\r'}"
      [[ -n "$line" ]] || continue
      args+=("--volume" "$line")
    done <<< "$volumes"
  fi

  if [[ "$debug_enabled" -eq 1 ]]; then
    dbg "create: ${args[*]}"
  fi

  local out_f err_f status
  out_f=$(mktemp) || return 1
  err_f=$(mktemp) || { rm -f "$out_f"; return 1; }
  "${args[@]}" >"$out_f" 2>"$err_f"
  status=$?
  if [[ "$debug_enabled" -eq 1 ]]; then
    dbg "create status=$status"
    if [[ -s "$out_f" ]]; then dbg "[stdout] $(cat "$out_f")"; fi
    if [[ -s "$err_f" ]]; then dbg "[stderr] $(cat "$err_f")"; fi
  fi
  rm -f "$out_f" "$err_f"
  return $status
}

create_container_with_feedback() {
  local has_nvidia=0
  if [[ -e /dev/nvidia0 || -e /proc/driver/nvidia/version || -x /usr/bin/nvidia-smi ]]; then
    has_nvidia=1
  fi

  local args=("distrobox" "create" "-n" "$name" "-i" "$image" "--no-entry" "--yes")
  if [[ "$has_nvidia" -eq 1 ]]; then args+=("--nvidia"); fi
  if jq_tp_bool pull; then args+=("--pull"); fi
  if jq_tp_bool root; then args+=("--root"); fi
  local v
  v=$(jq_tp_str home);      [[ -n "$v" ]] && args+=("--home" "$v")
  v=$(jq_tp_str hostname);  if [[ -n "$v" ]]; then v=$(unify_separators "$v"); args+=("--hostname" "$v"); fi
  v=$(jq_tp_str platform);  [[ -n "$v" ]] && args+=("--platform" "$v")
  if jq_tp_bool init; then args+=("--init"); fi
  v=$(jq_tp_str additional_packages); [[ -n "$v" ]] && args+=("--additional-packages" "$v")
  v=$(jq_tp_str additional_flags);    [[ -n "$v" ]] && args+=("--additional-flags" "$v")
  v=$(jq_tp_str pre_init_hooks);      [[ -n "$v" ]] && args+=("--pre-init-hooks" "$v")
  v=$(jq_tp_str init_hooks);          [[ -n "$v" ]] && args+=("--init-hooks" "$v")
  local volumes
  volumes=$(jq_tp_str volumes)
  if [[ -n "$volumes" ]]; then
    while IFS= read -r line; do
      line="${line%%$'\r'}"; [[ -n "$line" ]] || continue
      args+=("--volume" "$line")
    done <<< "$volumes"
  fi

  [[ "$debug_enabled" -eq 1 ]] && dbg "create: ${args[*]}"

  local out_f err_f
  out_f=$(mktemp) || return 1
  err_f=$(mktemp) || { rm -f "$out_f"; return 1; }

  "${args[@]}" >"$out_f" 2>"$err_f" &
  local pid=$!
  local spin='|/-\\'
  local i=0
  status "Creating container '$name' (this may take a while)..."
  while kill -0 "$pid" >/dev/null 2>&1; do
    i=$(( (i+1) % 4 ))
    printf "\r[st-distrobox] Working %s" "${spin:$i:1}" >&2
    sleep 0.2
  done
  wait "$pid"; local status_code=$?
  printf "\r" >&2
  if [[ "$debug_enabled" -eq 1 ]]; then
    if [[ -s "$out_f" ]]; then dbg "[stdout] $(cat "$out_f")"; fi
    if [[ -s "$err_f" ]]; then dbg "[stderr] $(cat "$err_f")"; fi
  fi
  rm -f "$out_f" "$err_f"
  return $status_code
}

# Ensure container exists
status "Checking for container '$name'..."
if ! container_exists; then
  if ! create_container_with_feedback; then
    log_err "${SCRIPT_NAME}: failed to create container '$name'"
    exit 1
  fi
  status "Container '$name' is ready."
else
  status "Container '$name' already exists."
fi

# Build enter command
enter_args=("distrobox" "enter" "-n" "$name")
if [[ -n "$spawn_command" ]]; then
  # Split by whitespace similar to the Vala implementation
  read -r -a spawn_tokens <<< "$spawn_command"
  if [[ ${#spawn_tokens[@]} -gt 0 ]]; then
    enter_args+=("--")
    enter_args+=("${spawn_tokens[@]}")
  fi
fi

status "Entering container '$name'..."
clear_screen
if [[ "$debug_enabled" -eq 1 ]]; then
  dbg "enter: ${enter_args[*]}"
  out_f=$(mktemp) || exit 1
  err_f=$(mktemp) || { rm -f "$out_f"; exit 1; }
  # Add a short timeout to avoid hangs when debugging
  if command -v timeout >/dev/null 2>&1; then
    timeout 30s "${enter_args[@]}" >"$out_f" 2>"$err_f"
  else
    "${enter_args[@]}" >"$out_f" 2>"$err_f"
  fi
  status=$?
  dbg "enter status=$status"
  if [[ -s "$out_f" ]]; then dbg "[stdout] $(cat "$out_f")"; fi
  if [[ -s "$err_f" ]]; then dbg "[stderr] $(cat "$err_f")"; fi
  rm -f "$out_f" "$err_f"
  exit $status
else
  # Exec-replace so the terminal tracks the container directly
  # Use --no-tty to avoid pseudo-tty allocation issues if the parent already handles TTY
  exec "${enter_args[@]}"
fi


