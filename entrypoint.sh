#!/usr/bin/env bash
################
#### README ####
################
##
##  Use this file to quickly write well formed bash scripts.
##  User Script Logic is placed at the bottom of this template.
##
##  Quick Notes:
##    - Reference files relative to the script using "$CONTEXT". This is an absolute path of the parent directory.
##    - Basic state info found in the "$OS" & "$PROC" associative arrays.
##    - A Temporary Directory is provided at "$TEMP_DIR" & is cleaned up on exit.
##    - Leveled logging provided with the trace(), debug() info(), warn(), error(), success() & critical() functions.
##    - Logging is color coded by level.
##    - Exit with a critical level log using the panic() function.
##    - Switch between text & json logging with the --log-format parameter.
##    - Quick sanity checks with check_env() & check_dep().
##    - Assert Conditions & exit with an critical message with the assert() function.
##    - Pretty Print arrays the printa() functions.
##    - Print associative arrays, their keys & values using the printaa(), printaak(), printaav() functions respectively.
##    - Add custom flags & parameters in the parse_params() function
##    - Update the help message in the usage() function
##
##  This script is based off in part from https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038
##  This script falls under the Apache License, Version 2.0
##
################
set -Eeuo pipefail
### Global Variables
declare CONTEXT UUID TEMP_DIR
CONTEXT="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
UUID="$(uuidgen || uuid -v4 || cat /proc/sys/kernel/random/uuid || od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}' || echo -n 'cd259b1d-9164-d4aa-fdc5-39a6b894ee19')"
TEMP_DIR="${TMPDIR:-/tmp}/${UUID}"; mkdir -p "$TEMP_DIR"; trap "rm -rf '${TEMP_DIR}'" EXIT
declare -A OS PROC
OS["name"]="$(uname -s)"
OS["release"]="$(uname -r)"
OS["arch"]="$(uname -m)"
PROC["pid"]="$$"
PROC["ppid"]="$(awk '/PPid/ { print $2 }' "/proc/$$/status")"
PROC["version"]="${BASH_VERSION}"
PROC["path"]="$(which bash)"
PROC["script"]="${BASH_SOURCE[0]}"
# For list of full colors see https://en.wikipedia.org/wiki/ANSI_escape_code
declare -a log_formats=( "text" "json" ) args=(); declare -A colors log_colors log_levels
colors["none"]='\033[0m'; colors["black"]='\033[0;30m'; colors["red"]='\033[0;31m'; colors["green"]='\033[0;32m'; colors["yellow"]='\033[0;33m'; colors["blue"]='\033[0;34m'; colors["magenta"]='\033[0;35m'; colors["cyan"]='\033[0;36m'; colors["white"]='\033[0;37m'
log_colors["trace"]="blue"; log_colors["debug"]="blue"; log_colors["info"]="cyan"; log_colors["warn"]="yellow"; log_colors["error"]="red"; log_colors["success"]="green"; log_colors["critical"]="red"
log_levels["trace"]="90"; log_levels["debug"]="80"; log_levels["info"]="70"; log_levels["warn"]="60"; log_levels["error"]="50"; log_levels["success"]="50"; log_levels["critical"]="40"; log_levels["quiet"]="0"
declare log_format="text" log_level="error"
printa() { trace "printa"; declare -n arr; arr="$1"; for val in "${arr[@]}"; do trace "val = '$val'"; declare suffix="'" prefix="'"; if [[ "$val" == "${arr[-1]}" ]]; then :; elif [[ "$val" == "${arr[-2]}" ]]; then suffix="' & "; else suffix="', "; fi; printf "%s%s%s" "$prefix" "$val" "$suffix"; unset suffix prefix; done; }
printaa() { trace "printaa"; declare -n asc_arr; asc_arr="$1"; declare -a keys; keys=("${!asc_arr[@]}"); for key in "${!asc_arr[@]}"; do declare suffix="'" prefix="'"; if [[ "$key" != "${keys[-1]}" ]]; then suffix="', "; fi; printf "%s%s=%s%s" "$prefix" "$key" "${asc_arr["$key"]}" "$suffix"; unset suffix prefix; done; }
printaak() { trace "printak"; declare -n asc_arr; asc_arr="$1"; declare -a keys; keys=("${!asc_arr[@]}"); printa keys; }
printaav() { trace "printav"; declare -n asc_arr; asc_arr="$1"; declare -a vals; vals=("${asc_arr[@]}"); printa vals; }
usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-x] [-l "error"] [--log-format "text"] [--flag] [--custom-param "foobar"] [subcmd1|subcmd2] [...]

Brief Summary of the script

Subcommands:
  subcmd1
    Describe what subcmd1 does
  
  subcmd2 [FOO...]
    Describe what subcmd2 does
      FOO...: Describe the FOO arguements

Available options:

-h, --help          Print this help and exit
--no-color          Disables Colored Logging
-x, --shell-trace   Print trace of the shell commands; WARNING! this can leak secrets
-l, --log-level     Sets the logging level; Valid Values are $(printaak "log_levels"); defaults to 'error'
--log-format        Sets the format of the log output; Valid Values are $(printa "log_formats"); defaults to 'text'; note that 'json' disables colors
--flag              What does flag enable?
--custom-param      What does custom-param do? What value does it except? Does it have a default value?
EOF
  exit
}
#### Logging ####
setup_colors() { if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then :; else for color in "${!colors[@]}"; do colors["$color"]=''; done; fi; }
compact_string() { declare -a lines; while read -r line; do lines+=('\n' "$line"); done <<<"$@"; printf "%s" "${lines[*]:1}"; }
msg() { echo >&2 -e "$*"; }
set_log_format() { for lformat in "${log_formats[@]}"; do if [[ "${1,,}" == "${lformat}" ]]; then debug "Set log format to $1"; log_format="${lformat}"; if [[ "${lformat}" == "json" ]]; then check_dep jq || panic "Please install jq to enable json formatted logs"; fi; return 0; fi; done; error "Unsupported Log Format $1"; return 1; }
set_log_level() { for level in "${!log_levels[@]}"; do if [[ "${1,,}" == "${level}" ]]; then log_level="${level}"; info "Log Level set to '$log_level'"; return 0; fi; done; msg "${colors[red]}$(date_prefix) [CRITICAL] unsupported log level '${1,,}'${colors[none]}"; return 1;}
log() { if [[ "${log_levels["$1"]}" -le "${log_levels["$log_level"]}" ]]; then if [[ "${log_format}" == "text" ]]; then msg "${colors["$2"]}$(date_prefix) [${1^^}] ${*:3}${colors[none]}"; elif [[ "${log_format}" == "json" ]]; then msg "$(jq -cn "{\"time\": \"$(date_prefix)\", \"level\": \"${1,,}\", \"message\": \$msg}" --arg msg "$(compact_string "${*:3}")")"; fi; fi; } # $1 == level; $2 == Color; $3... == Message
date_prefix() { date -Ins 2>/dev/null || date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || ps -p "$$" -o "etime=" 2>/dev/null; }
trace()     { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
debug()     { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
info()      { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
warn()      { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
error()     { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
success()   { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
critical()  { log "${FUNCNAME[0],,}" "${log_colors[${FUNCNAME[0],,}]}" "$*"; }
panic()     { critical "$*"; exit 255; } # default exit status 255
assert()    { if ! eval "$1"; then panic "${2:-"Assertion Failed for '$1'"}"; fi; }
#### Helpers ###
check_env() { declare env_error="false"; for var in "$@"; do trace "Checking for ${var} in environment"; if [[ -z "${!var:-}" ]]; then env_error="true"; echo "$var"; warn "$var not found in environment"; else debug "${var} found in environment"; fi; done; if [[ "$env_error" == "true" ]]; then trace "return 1"; return 1; else trace "return 0"; return 0; fi; }
check_dep() { declare dep_error="false"; for dep in "$@"; do trace "Checking for ${dep} in environment"; if ! which "$dep" 2>/dev/null 1>&2; then dep_error="true"; echo "$dep"; warn "$dep not found in path"; else debug "$dep found in path"; fi; done; if [[ "$dep_error" == "true" ]]; then trace "return 1"; return 1; else trace "return 0"; return 0; fi; }
parse_params() {
  # Global User Variables & Default Values
  # declare -g \
  #   custom_flag=0 \
  #   custom_param="foobar"

  while :; do
    # Just parse paramter list here; don't execute logic until after logging is set
    case "${1:-}" in
    ### Script Parameters ###
    -h | --help) usage ;;
    -x | --shell-trace) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -l | --log-level)
      log_level="${2:-}"
      shift
      ;;
    --log-format)
      log_format="${2:-}"
      shift
      ;;
    ### User Parameters ###
    # -f | --custom-flag) custom_flag=1 ;; # example flag
    # --custom-param)
    #   param="${2:-}"
    #   shift
    #   ;;
    -?*) panic "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done
  # Setup Logging
  set_log_format "$log_format" || panic "invalid log format"
  set_log_level "$log_level"  || panic "invalid log level"
  # Set Args
  args+=("$@")
  # Global User Variable Parsing Logic
  # ...
  return 0
}
parse_params "$@"
setup_colors
declare runtime_info script_info
runtime_info="$(cat - <<EOF
Runtime Info:
  Bash ............................ $(printaa "PROC")
  Operating System ................ $(printaa "OS")
EOF
)"
script_info="$(cat - <<EOF
Script Info:
  Subcommand ...................... ${args[*]:0:1}
  Parameters:
    --flag ...................... ${custom_flag:-}
    --custom-param .................. ${custom_param:-}
  Arguments ....................... ${args[*]:1}
EOF
)"
info "$runtime_info"
info "$script_info"

############################
#### SCRIPT LOGIC BELOW ####
############################

check_env \
  SSHD_CONFIG

trace "${SSHD_CONFIG}:\n$(< "${SSHD_CONFIG}")"

exec "$(command -v sshd)" \
  -f "${SSHD_CONFIG}" \
  -D \
  -e

# declare \
#   time_to_quit \
#   sshd_pid

# # Start the SSHD Service
# {
#   declare time_to_quit=0
#   trap "declare -g time_to_quit=1" QUIT
#   trace "${SSHD_CONFIG}"
#   while [[ "${time_to_quit}" -eq 0 ]]; do
#     "$(command -v sshd)" \
#       -f "${SSHD_CONFIG}" \
#       -D \
#       -e
#     warn "SSH Server exit on '$?'"
#   done
# } &

# sshd_pid="$(jobs -p %%)"

# {
#   sleep infinity
# } &

# declare \
#   time_to_quit

# time_to_quit="$(jobs -p %%)"

# trap "declare -g time_to_quit; kill -INT ${time_to_quit}" INT TERM QUIT

# wait -f "${time_to_quit}"

# kill -QUIT "${sshd_pid}"
# kill -INT "${sshd_pid}"
# wait -f "${sshd_pid}"
