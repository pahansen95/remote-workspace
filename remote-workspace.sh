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
CONTEXT="$(readlink -f "${BASH_SOURCE[0]}")"; CONTEXT="${CONTEXT%/*}"
UUID="$(uuidgen || uuid -v4 || cat /proc/sys/kernel/random/uuid || od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}' || echo -n 'cd259b1d-9164-d4aa-fdc5-39a6b894ee19')"
TEMP_DIR="${TMPDIR:-/tmp}/${UUID}"; mkdir -p "$TEMP_DIR"; trap "rm -rf '${TEMP_DIR}'" EXIT
declare -A OS PROC
OS["name"]="$(uname -s)"
OS["release"]="$(uname -r)"
OS["arch"]="$(uname -m)"
PROC["pid"]="$$"
PROC["ppid"]="$(awk '/PPid/ { print $2 }' "/proc/$$/status" 2> /dev/null || echo -n -1)"
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

find_config(){
  local -n fn_config_file="$1"
  fn_config_file="${WORKDIR}/config.yaml"
  if [[ ! -f "${fn_config_file}" ]]; then
    error "Config file '${fn_config_file}' doesn't exist"
    return 1
  fi
}

populate_list_from_json(){
  # Notes:
  #   key is optional
  #
  local -n \
    fn_json \
    fn_arr

  local key

  while [[ -n "${1:-}" ]]; do
    case "${1%%=*}" in
      key )
        key="${1#*=}"
        ;;
      json )
        fn_json="${1#*=}"
        ;;
      arr )
        fn_arr="${1#*=}"
        ;;
      * )
        error "Unknown kwarg passed '${1%%=*}'"
        return 1
        ;;
    esac
    shift
  done
  
  readarray -t fn_arr < <(
    # If a key is provided then iterate over the nested object
    if [[ -n "${key:-}" ]]; then
      jq -crn \
        --arg "key" "${key}" \
        --argjson "conf" "${fn_json}" \
        '$conf[$key][]'
    # If no Key is provided then iterate over the top level object
    else
      jq -crn \
        --argjson "conf" "${fn_json}" \
        '$conf[]'
    fi
  )
}

populate_map_from_json(){
  # Notes:
  #   key is optional
  #
  local -n \
    fn_json \
    fn_aarr

  local key

  while [[ -n "${1:-}" ]]; do
    case "${1%%=*}" in
      key )
        key="${1#*=}"
        ;;
      json )
        fn_json="${1#*=}"
        ;;
      aarr )
        fn_aarr="${1#*=}"
        ;;
      * )
        error "Unknown kwarg passed '${1%%=*}'"
        return 1
        ;;
    esac
    shift
  done
  
  while read -r kv; do
    fn_aarr+=(
      ["${kv%%=*}"]="${kv#*=}"
    )
  done < <(
    # If a key is provided then iterate over the nested object
    if [[ -n "${key:-}" ]]; then
      jq -rn \
        --arg key "${key}" \
        --argjson "conf" "${fn_json}" \
        '$conf[$key] | to_entries[] | "\(.key)=\(.value)"'
    # If no Key is provided then iterate over the top level object
    else
      jq -rn \
        --argjson "conf" "${fn_json}" \
        '$conf | to_entries[] | "\(.key)=\(.value)"'
    fi
  )
}

load_env(){
  local -n \
    fn_env_var
  
  local \
    env_config_json

  while [[ -n "${1:-}" ]]; do
    case "${1%%=*}" in
      var ) fn_env_var="${1#*=}";;
      json ) env_config_json="${1#*=}";;
      * ) error "Unknown key '${1%%=*}' passed to '${FUNCNAME[0]}'"; return 1;;
    esac
    shift
  done

  local -A env_config
  populate_map_from_json "json=env_config_json" "aarr=env_config"

  case "${env_config["type"],,}" in
    env )
      fn_env_var="${!env_config["var"]:-}"
      if [[ -z "${fn_env_var}" ]]; then
        warn "Env var '${env_config["var"]:-}' is empty or undefined"
      fi
      ;;
    * ) error "Env Var of type '${env_config["type"]}' is not implemented"; return 1 ;;
  esac
}

load_file_from_uri(){
  # Loads the content of a file, located at the uri, into a variable
  #
  local -n \
    fn_file_content
  
  local \
    file_uri

  while [[ -n "${1:-}" ]]; do
    case "${1%%=*}" in
      content ) fn_file_content="${1#*=}";;
      uri ) file_uri="${1#*=}";;
      * ) error "Unknown key '${1%%=*}' passed to '${FUNCNAME[0]}'"; return 1;;
    esac
    shift
  done

  local scheme="${file_uri%%:*}"

  case "${scheme,,}" in
    file ) 
      local path="${file_uri#*://}"
      if [[ ! -e "${path}" ]]; then
        error "File '${path}' not found"
        return 1
      fi
      if [[ -d "${path}" ]]; then
        error "FilePath '${path}' is a directory. Must be a file."
        return 1
      fi
      fn_file_content="$(< "${path}")"
      if [[ -z "${fn_file_content}" ]]; then
        warn "File '${path}' is empty"
      fi
      ;;
    * ) error "Scheme '${scheme}' not implemented" ; return 1 ;;
  esac
}

line_in_file(){
  local \
    path \
    line \
    state

  while [[ -n "${1:-}" ]]; do
    case "${1%%=*}" in
      path )
        path="${1#*=}"
        if [[ ! -f "${path}" ]]; then
          error "$path not found"
          return 1
        fi
        ;;
      line )
        line="${1#*=}"
        ;;
      state )
        state="${1#*=}"
        ;;
      * )
        error "Unknown kwarg passed '${1%%=*}'"
        return 1
        ;;
    esac
    shift
  done
  case "${state}" in
    "present" )
      if ! grep -q "${line}" "${path}"; then
        debug "line missing from file; inserting at head"
        # Backup the File
        if [[ ! -f "${path}.MASTER.BACKUP" ]]; then
          cp -a "${path}" "${path}.MASTER.BACKUP"
          info "Master Backup of '${path}' saved to '${path}.MASTER.BACKUP'"
        fi
        trap 'critical "Master Backup of ${path} found at ${path}.MASTER.BACKUP"' ERR
        cp -a "${path}" "${path}.BACKUP"
        trap 'cat "${path}.BACKUP" > "${path}"' ERR
        trap 'rm -f "${path}.BACKUP"' RETURN
        {
          # Header
          printf '%s\n' \
            "${line}"
          
          # Body
          cat "${path}.BACKUP"
        } > "${path}"
      fi
      ;;
    "absent" )
      if grep -q "${line}" "${path}"; then
        debug "line found in file"
        error "State '${state}' not implemented"
        return 255
      fi
      ;;
    * )
      error "Unknown state '${state}'"
      return 1
      ;;
  esac
}

### Start Main Logic ###

declare \
  WORKDIR="${PWD}"

for subdir in ".cache" ".ssh"; do
  if [[ ! -d "${WORKDIR}/${subdir}" ]]; then
    info "Creating ${WORKDIR}/${subdir}"
    mkdir -p "${WORKDIR}/${subdir}"
  fi
done

test -d "${WORKDIR}/.ssh/config.d" || mkdir -p "${WORKDIR}/.ssh/config.d"

case "${args[0],,}" in
  "up" ) # Bring Up All of the Workspaces in the config file
    check_dep \
      kubectl \
      helm \
      code \
      ssh-keygen \
      yq \
      jq

    # Notes:
    #   ALL_RUNTIME_VARS is passed as a nameref
    declare -a \
      required_runtime_keys=(
        "KUBECONFIG"
        "CONTAINER_REGISTRY_USERNAME"
        "CONTAINER_REGISTRY_PASSWORD"
        "USER_SSH_KEY"
        "USER_SSH_PUB_KEY"
      )

    declare \
      config_file \
      config_yaml \
      config_json

    find_config \
      config_file
    
    config_json="$(yq -o json "${config_file}")"

    # TODO Compare Config File against a Spec
    if [[ -z "${config_json:-}" ]]; then
      critical "Config File '${config_file}' is empty"
      exit 1
    fi

    declare -a \
      declared_projects
    
    readarray -t declared_projects < <(
      jq -rn --argjson "conf" "${config_json}" '$conf.projects | keys[]'
    )
    if [[ "${#declared_projects[@]}" -eq 0 ]]; then
      critical "No Projects Declared in the Config"
      exit 1
    fi
    
    # Generate an SSH Private/Pub Pair
    if [[ ! -f "${WORKDIR}/.ssh/server_id_ed25519" ]]; then
      rm -f "${WORKDIR}/.ssh/server_id_ed25519" "${WORKDIR}/.ssh/server_id_ed25519.pub" || true
      ssh-keygen -t ed25519 -C "$(whoami || printf vscode)@remote-workspace" -N '' -f "${WORKDIR}/.ssh/server_id_ed25519"
      chmod 600 "${WORKDIR}/.ssh/server_id_ed25519" "${WORKDIR}/.ssh/server_id_ed25519.pub"
    fi
    
    declare loop_vars=(
      project_json_config
      project_cli_env
      missing_keys
      project_vscode_settings
      project_all_files
      project_secret_files
      project_files
      project_all_ssh_keys
      project_git_keys
      project_ssh_keys
      ssh_keys_json
      project_ssh_hosts
      ssh_hosts_json
      namespace
      project_git_url
      project_git_ref
      project_git_name
      project_git_addr
      kubectl
      helm
      release_name
      public_ips
    )
    for project in "${declared_projects[@]}"; do
      # Make sure all project variables are cleared
      for var in "${loop_vars[@]}" ; do
        unset "${var}" || true
      done

      info "Bringing Up ${project}"

      ### Load the runtime environment for the project
      debug "Loading Project Config"
      declare project_json_config
      project_json_config="$(
        jq -rn --argjson 'conf' "${config_json}" \
          --arg 'proj' "${project}" \
          '$conf.projects[$proj]'
      )"
      if [[ -z "${project_json_config}" ]]; then
        error "'${project}''s Project Configuration is Empty"
        continue
      fi
      trace "$(< <(
        echo "'${project}' Config" ;
        printf '%s\n' "$(
          jq -n --argjson conf "${project_json_config}" '$conf'
        )"
      ))"

      # Load the CLI Environment Variables
      debug "Load & Merge the Global & Project CLI ENV Vars"
      declare -A project_cli_env
      populate_map_from_json "json=config_json" "key=cliEnv" "aarr=project_cli_env"
      populate_map_from_json "json=project_json_config" "key=cliEnv" "aarr=project_cli_env"
      for key in "${!project_cli_env[@]}"; do
        declare value_type
        read -r value_type < <(
          {
            { printf '%s'   "${project_cli_env["${key}"]}" | jq -cr '. | type' ; } || \
            { printf '"%s"' "${project_cli_env["${key}"]}" | jq -cr '. | type' ; }
          } 2>/dev/null
        )
        case "${value_type,,}" in
          string ) project_cli_env["${key}"]="$(eval printf "%s" "${project_cli_env["${key}"]}")" ;;
          object )
            declare env_val
            load_env "json=${project_cli_env["${key}"]}" "var=env_val"
            project_cli_env["${key}"]="$(eval printf "%s" "${env_val}")"
            unset env_val
            ;;
          * ) error "cliEnv Invalid Data Type; got '${value_type}'"; exit 1 ;;
        esac
        unset value_type
      done
      trace "$(< <(
        echo "'${project}' CLI Env" ;
        for key in "${!project_cli_env[@]}"; do
          printf '%s=%s\n' "${key}" "${project_cli_env["${key}"]}"
        done
      ))"
      
      debug "Check for Missing CLI ENV Vars"
      declare -a missing_keys=()
      for key in "${required_runtime_keys[@]}"; do
        if [[ -z "${project_cli_env["${key}"]:-}" ]]; then
          missing_keys+=("${key}")
        fi
      done
      if [[ "${#missing_keys[@]}" -gt 0 ]]; then
        error "Project '${project}' is missing the following Keys, please double check the config & the env: [$(printf '%s,' "${missing_keys[@]}")]"
        continue
      fi
      
      # Load the VSCode Workspace Settings
      debug "Load & Merge the Global & Project VSCode Workspace Settings"
      declare -A project_vscode_settings
      populate_map_from_json "json=config_json" "key=vscode" "aarr=project_vscode_settings"
      populate_map_from_json "json=project_json_config" "key=vscode" "aarr=project_vscode_settings"
      trace "$(< <(
        echo "'${project}' VSCode Workspace Settings";
        for key in "${!project_vscode_settings[@]}"; do
          printf '%s=%s\n' "${key}" "${project_vscode_settings["${key}"]}"
        done
      ))"

      # Load the Files
      debug "Load & Merge the Global & Project Extra Files"
      declare -a project_all_files project_secret_files project_files
      populate_list_from_json "json=config_json" "key=files" "arr=project_all_files"
      populate_list_from_json "json=project_json_config" "key=files" "arr=project_all_files"
      for file_obj_json in "${project_all_files[@]}"; do
        declare file_contents file_json
        declare -A file_config
        populate_map_from_json "json=file_obj_json" "aarr=file_config"
        file_config["src"]="$(eval printf '%s' "${file_config["src"]}")"
        load_file_from_uri "uri=${file_config["src"]}" "content=file_contents"
        read -r file_json < <(
          jq -cnr \
              --arg dest "${file_config["dest"]//"~"/"/home/vscode"}" \
              --arg data "${file_contents}" \
              '{ $dest, $data }'
        )
        case "${file_config["type"],,}" in
          secret ) project_secret_files+=("${file_json}") ;;
          configMap ) project_files+=("${file_json}") ;;
          * ) error "Files of type '${file_config["type"]}' is not implemented"; exit 1 ;;
        esac
        unset file_contents file_json file_config
      done
      trace "$(< <(
        echo "'${project}' Extra Files";
        for key in "${!file_config[@]}"; do
          printf '%s=%s\n' "${key}" "${file_config["${key}"]}"
        done
      ))"

      # Load the global SSH Keys & Merge the Project Defined Keys
      debug "Load & Merge the Global & Project SSH Keys"
      declare -A project_all_ssh_keys project_git_keys project_ssh_keys
      populate_map_from_json "json=config_json" "key=sshKeys" "aarr=project_all_ssh_keys"
      populate_map_from_json "json=project_json_config" "key=sshKeys" "aarr=project_all_ssh_keys"
      for key in "${!project_all_ssh_keys[@]}"; do
        declare sshkey_json="${project_all_ssh_keys["${key}"]}"
        declare -A sshkey_conf
        populate_map_from_json "json=sshkey_json" "aarr=sshkey_conf"
        case "${sshkey_conf["type"],,}" in
          generic ) project_ssh_keys+=(["${key}"]="$(eval printf '%s' "${sshkey_conf["src"]}")") ;;
          git ) project_git_keys+=(["${key}"]="$(eval printf '%s' "${sshkey_conf["src"]}")") ;;
          * ) error "sshKeys of type '${sshkey_conf["type"]}' is not implemented"; exit 1 ;;
        esac
        unset sshkey_json sshkey_conf
      done
      trace "$(< <(
        echo "'${project}' Remote Git Server SSH Keys";
        for key in "${!project_git_keys[@]}"; do
          printf '%s=%s\n' "${key}" "${project_git_keys["${key}"]}"
        done
      ))"
      trace "$(< <(
        echo "'${project}' Generic SSH Keys";
        for key in "${!project_ssh_keys[@]}"; do
          printf '%s=%s\n' "${key}" "${project_ssh_keys["${key}"]}"
        done
      ))"
      # Convert SSH Keys into a JSON Object for the Helm Chart
      declare ssh_keys_json
      read -r ssh_keys_json < <(
        {
          for key in "${!project_ssh_keys[@]}"; do
            if [[ ! -f "${project_ssh_keys["$key"]}" ]]; then
              error "SSH Key '${project_ssh_keys["$key"]}' not found"
            fi
            jq -ncr \
              --arg key "${key}" \
              --arg value "$(< "${project_ssh_keys["$key"]}")" \
              '{$key, $value}'
          done
          for key in "${!project_git_keys[@]}"; do
            if [[ ! -f "${project_git_keys["$key"]}" ]]; then
              error "SSH Key '${project_git_keys["$key"]}' not found"
            fi
            jq -ncr \
              --arg key "${key}" \
              --arg value "$(< "${project_git_keys["$key"]}")" \
              '{$key, $value}'
          done
        } | jq -rsc 'from_entries'
      )
      # Load the global SSH Hosts & Merge the Project Defined Hosts
      debug "Load & Merge the Global & Project SSH Hosts"
      declare -A project_ssh_hosts
      populate_map_from_json "json=config_json" "key=sshHosts" "aarr=project_ssh_hosts"
      populate_map_from_json "json=project_json_config" "key=sshHosts" "aarr=project_ssh_hosts"
      trace "$(< <(
        echo "'${project}' SSH Hosts";
        for key in "${!project_ssh_hosts[@]}"; do
          printf '%s=%s\n' "${key}" "${project_ssh_hosts["${key}"]}"
        done
      ))"
      
      declare ssh_hosts_json
      # Add the SSH Remote Host Configs
      read -r ssh_hosts_json < <(
        {
          # The SSH Hosts for Remote Git Servers
          for key in "${!project_git_keys[@]}"; do
            jq -ncr \
              --arg host "${key}" \
              '{
                "\($host)": {
                  "AddKeysToAgent": "yes",
                  "IdentityFile": "~/.ssh/\($host)"
                }
              }'
          done 
          # The SSH Hosts for Generic SSH Servers
          # Notes:
          #   The jq filter '{} * {}' recursively merges the two JSON objects, with the right object overwritting the left if a key's value is a scalar.
          for key in "${!project_ssh_hosts[@]}"; do
            jq -ncr \
              --arg host "${key}" \
              --argjson conf "${project_ssh_hosts["${key}"]}" \
              '{
                "\($host)": {
                  "AddKeysToAgent": "yes",
                  "IdentityFile": "~/.ssh/\($host)"
                }
              } * {
                "\($host)": $conf
              }'
          done
        } | jq -rsc 'add'
      )

      declare \
        namespace="remote-workspace-${project,,}" \
        project_git_url \
        project_git_ref \
        project_git_name \
        project_git_addr

      read -r project_git_url < <(
        jq -rn \
          --argjson "conf" "${project_json_config}" \
          '$conf.git.url'
      )
      read -r project_git_ref < <(
        jq -rn \
          --argjson "conf" "${project_json_config}" \
          '$conf.git.ref'
      )        
      project_git_name="${project_git_url}"
      project_git_name="${project_git_name##*/}"
      project_git_name="${project_git_name%.*}"
      project_git_addr="${project_git_url%:*}"
      project_git_addr="${project_git_addr#*@}"

      trace "project_git_url=${project_git_url}"
      trace "project_git_ref=${project_git_ref}"
      trace "project_git_name=${project_git_name}"
      trace "project_git_addr=${project_git_addr}"

      ### Check Connection to the K8s Cluster
      declare kubectl helm
      kubectl="kubectl --kubeconfig ${project_cli_env["KUBECONFIG"]}"
      helm="helm --kubeconfig ${project_cli_env["KUBECONFIG"]}"
      debug "$(${kubectl} config current-context)"
      ${kubectl} cluster-info

      ### Build the Values File
      # TODO Don't inject SSH Keys into the values file; instead (re)create Kubernetes Secrets
      jq -n -c \
        --arg userPubKey "$(< "${project_cli_env["USER_SSH_PUB_KEY"]}")" \
        --argjson sshKeys "${ssh_keys_json}" \
        --argjson sshHosts "${ssh_hosts_json}" \
        --argjson secretFiles "$(jq -scr < <(printf "%s\n" "${project_secret_files[@]}"))" \
        --argjson files "$(jq -scr < <(printf "%s\n" "${project_files[@]}"))" \
        --arg cntrReg "${project_cli_env["CONTAINER_REGISTRY_URL"]}" \
        --arg cntrPath "${project_cli_env["CONTAINER_IMAGE_PATH"]}" \
        --arg cntrTag "${project_cli_env["CONTAINER_IMAGE_TAG"]}" \
        --arg cntrUser "${project_cli_env["CONTAINER_REGISTRY_USERNAME"]}" \
        --arg cntPass "${project_cli_env["CONTAINER_REGISTRY_PASSWORD"]}" \
        --arg serverPrivKey "$(< "${WORKDIR}/.ssh/server_id_ed25519")" \
        --arg serverPubKey "$(< "${WORKDIR}/.ssh/server_id_ed25519.pub")" \
        '{
          workspace: {
            files: {
              secrets: $secretFiles,
              configMaps: $files
            },
            ssh: {
              authorizedKeys: [
                $userPubKey
              ],
              keys: $sshKeys,
              config: {
                hosts: $sshHosts
              }
            }
          },
          container: {
            image: {
              registry: $cntrReg,
              path: $cntrPath,
              tag: $cntrTag,
              username: $cntrUser,
              password: $cntPass
            }
          },
          services: {
            ssh: {
              keyPair: {
                pub: $serverPubKey,
                priv: $serverPrivKey
              }
            }
          }
        }' | \
      yq -P > "${TEMP_DIR}/values.yaml"
      trace "$(< <(
        echo ;
        cat "${TEMP_DIR}/values.yaml"
      ))"

      ### Deploy the Helm Chart
      declare release_name="${project,,}"
      debug "helm install dry-run..."
      trace "$(< <(
        echo ;
        ${helm} install \
          "${release_name}" \
          "${CONTEXT}/helm/remote-workspace" \
          --dry-run \
          --debug \
          --namespace "${namespace}" \
          --values "${TEMP_DIR}/values.yaml" \
          2>&1
      ))"
      info "Deploying Remote Workspace; this could take up to 15 minutes. Press Ctrl-C at any time to cancel."
      ${helm} upgrade \
        "${release_name}" \
        "${CONTEXT}/helm/remote-workspace" \
        --install \
        --namespace "${namespace}" \
        --create-namespace \
        --values "${TEMP_DIR}/values.yaml" \
        --atomic \
        --timeout 15m0s
      
      ### Setup the Remote Workspace

      ## Get the LoadBalancer IP      
      declare -a \
        public_ips
      readarray -t public_ips < <(
        ${kubectl} -o json \
          -n "${namespace}" \
          get service "${release_name}-workspace-ssh-svc" \
        | jq -r '.status.loadBalancer.ingress[].ip'
      )
      trace "public_ips=[$(printf '%s,' "${public_ips[@]}")]"
      if [[ "${#public_ips[@]}" -eq 0 ]]; then
        error "No Publically Routable Ips available for Project '${project}'"
        continue
      fi
      
      ## Setup SSH Access to the Remote Workspace
      if [[ ! -f "${HOME}/.ssh/known_hosts" ]]; then
        : > "${HOME}/.ssh/known_hosts"
      fi
      for public_ip in "${public_ips[@]}"; do
        ssh-keyscan -H "${public_ip}" 2>/dev/null >> "${HOME}/.ssh/known_hosts"
        ssh -i "${project_cli_env["USER_SSH_KEY"]}" "vscode@${public_ip}" echo 'SSH connection successful'
      done

      ## Clone the Repository in the Remote Workspace
      ssh -i "${project_cli_env["USER_SSH_KEY"]}" "vscode@${public_ips[0]}" bash < <(echo "
        set -xEeuo pipefail
        cd '/home/vscode/workspace'
        if [[ ! -f ~/.ssh/known_hosts ]]; then
          : > ~/.ssh/known_hosts
        fi
        if [[ ! -d '${project_git_name}' ]]; then
          ssh-keyscan -H '${project_git_addr}' >> ~/.ssh/known_hosts
          ssh -T 'git@${project_git_addr}'
          git clone \
            -b '${project_git_ref}' \
            '${project_git_url}' \
            '${project_git_name}'
        else
          echo \"'\${HOME}/${project_git_name}' already found so skipping clone\" >&2
        fi
      ")

      ## Add the Remote Host to the SSH config  
      if [[ ! -f "${WORKDIR}/.ssh/config.d/${release_name}" ]]; then
        echo -n "\
        Host ${release_name}
          Hostname ${public_ip[0]}
          User vscode
          IdentityFile ${project_cli_env["USER_SSH_KEY"]}" \
        >> "${WORKDIR}/.ssh/config.d/${release_name}"
      fi

      # Add this Config to the Users Config
      line_in_file \
        "path=${HOME}/.ssh/config" \
        "line=Include ${WORKDIR}/.ssh/config.d/*" \
        "state=present"

      ### Build the VsCode Workspace File ###
      
      jq -n \
        --arg remoteAuthority "ssh-remote+${release_name}" \
        --arg defaultProfile "${project_vscode_settings["defaultProfile"]:-"bash"}" \
        --arg workspaceUri "vscode-remote://ssh-remote+${release_name}/home/vscode/workspace" \
        '{
          "folders": [
            {
              uri: $workspaceUri
            }
          ],
          "remoteAuthority": $remoteAuthority,
          "settings": {
            "terminal.integrated.env.linux": {
              "PATH": "/home/linuxbrew/.linuxbrew/bin:${env:PATH}"
            },
            "terminal.integrated.profiles.linux": {
              "fish": {
                "path": "/home/linuxbrew/.linuxbrew/bin/fish",
              },
              "bash": {
                "path": "/home/linuxbrew/.linuxbrew/bin/bash",
                "icon": "terminal-bash"
              }
            },
            "terminal.integrated.defaultProfile.linux": $defaultProfile
          }
        }' \
      > "${WORKDIR}/.cache/${release_name}.code-workspace"
    done
    ;;
  "add" ) # Add a new workspace by name to the config file
    critical "'add' currently Not Implemented"
    exit 1
    ;;
  "down" )
    critical "'down' currently Not Implemented"
    exit 1
    check_dep \
      kubectl \
      helm

    check_env \
      KUBECONFIG

    ### Teardown the Workspace on the K8s Cluster
    declare \
      remote_project="${args[1]}"
    
    # Get the path of the url & replace "/" with "-"
    project_slug="${remote_project}"
    project_slug="${project_slug#*:}"
    project_slug="${project_slug%.*}"
    project_slug="${project_slug//\//\-}"
    trace "${project_slug}"
    test -n "${project_slug}"

    declare \
      namespace="${project_slug}" \
      release_name="${project_slug}"

    info "Retrieve the LoadBalancer IP"
    declare -a public_ip
    public_ip=("$(${kubectl} -n "${namespace}" get service "${release_name}-workspace-ssh-svc" -o json | jq -r '.status.loadBalancer.ingress[].ip')")
    trace "public_ip=[$(printf "'%s', " "${public_ip[@]}")]"
    test "${#public_ip[@]}" -gt 0


    info "Uninstall Release ${release_name}"
    helm uninstall \
      "${release_name}" \
      --namespace "${namespace}" || true

    info "Removing Old State Files"
    rm \
      "${WORKDIR}/.ssh/config.d/${release_name}" \
      "${WORKDIR}/.cache/${release_name}.code-workspace" \
    || true

    info "Clean Up Known Hosts"
    for pub_ip in "${public_ip[@]}"; do
      ssh-keygen \
        -R "${pub_ip}" \
      || true
    done
    ;;
  "list" )
    ### List all of the currently available remote workspaces
    echo "Currently Available Remote Workspaces"
    for workspace in "${WORKDIR}/.cache/"*; do
      if [[ "${workspace##*.}" == "code-workspace" ]]; then
        declare workspace_file="${workspace##*/}"
        printf "  - %s\n" "${workspace_file%.code-workspace}"
      fi
    done
    ;;
  "connect" )
    check_dep \
      code
    if [[ -z "${args[1]:-}" ]]; then
      critical "Must specify a workspace to connect to."
      exit 1 
    fi
    declare workspace_file="${WORKDIR}/.cache/${args[1],,}.code-workspace"
    if [[ ! -f "${workspace_file}" ]]; then
      critical "Requested Workspace '${args[1],,}' not found"
      critical "Use the 'connect' subcommand to list remote workspaces available in the current project."
      exit 1
    fi
    # Connect VsCode to the Remote Container
    info "Connecting Now"
    if code "${workspace_file}"; then
      success "Connected Successfully"
    else
      critical "Failed to Connect"
      exit 1
    fi
    ;;
  "help" ) 
    usage
    ;;
  * )
    critical "Unknown Subcommand '${args[0]}'"
    exit 1
    ;;
esac