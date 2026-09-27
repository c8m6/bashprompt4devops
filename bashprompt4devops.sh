#!/bin/bash
###########################################################
#
#  bash-prompt4devops.sh
#
#  This little bash script make your bash much more pretty
#  and show you some information about kubelet, git and
#  much more.
#
#  Missing some fonts:
#    sudo apt-get install ttf-ancient-fonts
#
#                      ___              __
#                     / _ \            / /
#                  __| (_) |_ __ ___  / /
#                 / __> _ <| '_ ` _ \| '_ \
#                | (_| (_) | | | | | | (_) |
#                 \___\___/|_| |_| |_|\___/
#
#                 https://github.com/c8m6/
#
# Configure with environment variables:
# export BP_DISABLE_CLOCK=true
# export BP_DISABLE_EXITSTATUS=true
# export BP_DISABLE_GITFETCH=true
###########################################################

# Only configure interactive Bash or zsh sessions, once per shell.
case $- in *i*) ;; *) return 0 2> /dev/null || exit 0 ;; esac
if [ -z "${BASH_VERSION}${ZSH_VERSION}" ] || [ "${_bp_loaded}" = true ] ; then
  return 0
fi
_bp_loaded=true
_bp_ready=false
_bp_exitstatus=0
execution_time=0

# color definitions
if [ "${TERM}" = 'xterm-256color' ] ; then
  grey='\e[38;5;235m'
else
  grey='\e[90m'
fi
green='\e[32m'
red='\e[31m'
cyan='\e[36m'
reset='\e[0m'
yellow='\e[33m'
blue='\e[35m'

# Mark terminal escapes as zero-width for the shell's line editor.
for _bp_color in grey green red cyan reset yellow blue ; do
  eval "_bp_value=\${${_bp_color}}"
  if [ "${TERM}" = dumb ] ; then
    _bp_value=''
  elif [ -n "${ZSH_VERSION}" ] ; then
    _bp_value="%{$(printf '%b' "${_bp_value//\\e/\\033}")%}"
  else
    _bp_value=$'\001'"$(printf '%b' "${_bp_value//\\e/\\033}")"$'\002'
  fi
  printf -v "${_bp_color}" '%s' "${_bp_value}"
done
unset _bp_color _bp_value

# functions
function _bp_get_ttywidth () {
  TERM_WIDTH=${COLUMNS:-80}
  case $TERM_WIDTH in ''|*[!0-9]*) TERM_WIDTH=80 ;; esac
  if [ "$TERM_WIDTH" -lt 24 ] ; then TERM_WIDTH=24 ; fi
}

function _bp_cmd_time_start () {
  if [ "${_bp_ready}" = true ] && [ -z "${timer}" ] ; then
    timer=$SECONDS
  fi
}

function _bp_cmd_time_stop {
  execution_time=$((SECONDS - ${timer:-SECONDS}))
  if [ $execution_time -lt 60 ] ; then
    printf -v cmd_runtime '%ss' "$execution_time"
  elif [ $execution_time -lt 3600 ] ; then
    printf -v cmd_runtime '%sm %02ds' "$((execution_time / 60))" "$((execution_time % 60))"
  else
    printf -v cmd_runtime '%sh %02dm %02ds' "$((execution_time / 3600))" "$((execution_time / 60 % 60))" "$((execution_time % 60))"
  fi
  unset timer
}

function _bp_precmd () {
  _bp_exitstatus=$?
  _bp_ready=false
  _bp_cmd_time_stop
  if [ -n "${BASH_VERSION}" ] && [ -n "${HISTFILE}" ] && [ "$HISTFILE" != /dev/null ] ; then
    if [ "${BASH_VERSINFO[0]}" -lt 4 ] ; then
      # Bash 3.2 requires a cursor beyond the new entries before it can append.
      if [ "${_bp_history_initialized}" != true ] ; then
        local history_tmp=$(mktemp "${TMPDIR:-/tmp}/bp-history.XXXXXX")
        if [ -z "$history_tmp" ] ; then return "$_bp_exitstatus" ; fi
        local history_seed=$(mktemp "${TMPDIR:-/tmp}/bp-history.XXXXXX")
        if [ -z "$history_seed" ] ; then rm -f "$history_tmp"; return "$_bp_exitstatus" ; fi
        printf ':\n' > "$history_seed"
        history -w "$history_tmp"
        local HISTSIZE=$(( ${HISTSIZE:-500} > 0 ? ${HISTSIZE:-500} * 2 + 1 : 1000000 ))
        history -c
        history -r "$history_seed"
        history -r "$history_tmp"
        rm -f "$history_tmp" "$history_seed"
        _bp_history_initialized=true
      fi
      history -n /dev/null
    fi
    if history -a ; then
      history -c
      history -r
    fi
  fi
  _bp_get_ttywidth
  if [ -n "${BASH_VERSION}" ] ; then return "$_bp_exitstatus" ; fi
  return 0
}

function _bp_restore_status () {
  return "$_bp_exitstatus"
}

function _bp_cmd_time_arm () {
  _bp_ready=true
}

# Treat user-controlled text literally, including zsh's percent escapes.
function _bp_escape () {
  if [ -n "${ZSH_VERSION}" ] ; then
    printf '%s' "${1//\%/%%}"
  else
    printf '%s' "$1"
  fi
}

function _bp_lastcmdstat () {
  if [ "${BP_DISABLE_EXITSTATUS}" != true ] ; then
    if [ ! $1 -eq 0 ] ; then
      local error_color=$red
      local error_sign='⭍'
      local error_code=" ${1} "
    else
      local error_color=''
      local error_sign=''
      local error_code=''
    fi

    if [ $execution_time -gt 0 ] ; then
      local msg_time="${grey}${cmd_runtime}${reset}"
    fi

    printf '%s' "${error_color}${error_sign}${error_code}${msg_time}"
  fi
}

function _bp_pwd () {
  local path_element
  local path_part
  local current_dir=$PWD
  case $current_dir in "$HOME"|"$HOME"/*) current_dir="~${current_dir#"$HOME"}" ;; esac
  local last_dir=${current_dir##*/}
  local path_maxlength=$((${TERM_WIDTH:-80} / 3))
  local current_repo=$(git rev-parse --show-toplevel 2> /dev/null)
  local current_repo_name=${current_repo##*/}

  local path_remaining=$current_dir
  while [ -n "$path_remaining" ] ; do
    path_element=${path_remaining%%/*}
    if [ "$path_remaining" = "$path_element" ] ; then
      path_remaining=''
    else
      path_remaining=${path_remaining#*/}
    fi
    if [ ! "x${path_element}x" = "xx" ] ; then
      if [ "${path_element}" = "${current_repo_name}" ] ; then
        path_part="${path_part}/${blue}$(_bp_escape "$path_element")${cyan}"
      elif [ "${path_element}" = '~' ] ; then
        path_part='~'
      else
        if [[ ${#current_dir} -gt $path_maxlength && "${path_element}" != "${last_dir}" ]]; then
          path_part="${path_part}/$(_bp_escape "${path_element:0:1}")"
        else
          path_part="${path_part}/$(_bp_escape "$path_element")"
        fi
      fi
    fi
  done

  local dir_msg="${cyan}${path_part}/${reset}"

  printf '%s' "${dir_msg}"
}

function _bp_kubectl () {
  if command -v kubectl > /dev/null 2>&1 && { [ -n "${KUBECONFIG}" ] || [ -f "$HOME/.kube/config" ]; } ; then
    local current_context=$(kubectl config current-context 2> /dev/null)
    if [ -n "$current_context" ] ; then
      printf '%s' "${grey}|${green}☸ $(_bp_escape "$current_context")${reset}"
    fi
  fi
}

function _bp_clock () {
  if [ "${BP_DISABLE_CLOCK}" != true ] ; then
    printf '%s' "${grey}|${blue}$(date +%H:%M)${reset}"
  fi
}

function _bp_userandhost () {
  local user=$(whoami)
  local host=$(hostname)

  if [ "$user" = 'root' ] ; then
    local user_color=$red
  else
    local user_color=$green
  fi
  local part_user="${user_color}$(_bp_escape "$user")"

  if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    local part_host="${yellow}@$(_bp_escape "$host")"
  else
    local part_host="${green}@$(_bp_escape "$host")"
  fi

  printf '%s' "${part_user}${part_host}"
}

function _bp_gitfetch () {
  if [ "${BP_DISABLE_GITFETCH:-false}" = true ] ; then return ; fi
  local git_dir=$(git rev-parse --git-common-dir 2> /dev/null)
  if [ -z "$git_dir" ] ; then return ; fi
  local fetch_stamp="$git_dir/bp-fetch.last"
  local fetch_lock="$git_dir/bp-fetch.lock"
  if [ -f "$fetch_stamp" ] && [ -z "$(find "$fetch_stamp" -mmin +5 2> /dev/null)" ] ; then return ; fi
  (
    # Share the throttle and lock across all worktrees, even on fetch failure.
    mkdir "$fetch_lock" 2> /dev/null || exit 0
    trap 'rmdir "$fetch_lock"' EXIT
    trap 'exit 0' INT TERM
    if [ -f "$fetch_stamp" ] && [ -z "$(find "$fetch_stamp" -mmin +5 2> /dev/null)" ] ; then exit 0 ; fi
    touch "$fetch_stamp" || exit 0
    GIT_TERMINAL_PROMPT=0 git fetch --quiet
  ) > /dev/null 2>&1 &
}

function _bp_gitstatus () {
  local repo=$(git rev-parse --show-toplevel 2> /dev/null)
  if [ ! "${repo}" = "" ] ; then
    _bp_gitfetch
		local branch
    local fetch_a=+0
    local fetch_b=-0
		local changed=0
		local conflicts=0
    local untracked=0
		local warn=0
    local error=0

		git --no-optional-locks status --porcelain=2 --branch | (
      while IFS= read -r line ; do
      	case "${line}" in
					'# branch.head'*)		branch=${line#\# branch.head }	; ;;
          '# branch.ab'*) 		fetch_a=${line#\# branch.ab }; fetch_b=${fetch_a#* }; fetch_a=${fetch_a%% *} ; ;;
          'u'*)								((conflicts++)) 	; ;;
					'1'*)								((changed++)) 		; ;;
					'2'*)								((changed++)) 		; ;;
					'?'*)								((untracked++)) 	; ;;
        esac
      done
      local forward=${fetch_a/+/}
      local behind=${fetch_b/-/}
			local warn=$((conflicts+changed+untracked+forward+behind))
			local warn_st=$((conflicts+changed+untracked))
			local error=$conflicts

			if [ $error -gt 0 ] ; then
				local color=$red
      elif [ $warn -gt 0 ] ; then
				local color=$yellow
      else
				local color=$green
        local msg_clean="${green}✔"
			fi

      if [ $warn_st -eq 0 ] && [ "${msg_clean}" = "" ] ; then
        local msg_warn_st="✔"
      fi

      if [ $changed -gt 0 ] ; then
        local msg_changed="✎${changed}"
      fi

      if [ $untracked -gt 0 ] ; then
        local msg_untracked="⚛${untracked}"
      fi

      if [ $conflicts -gt 0 ] ; then
        local msg_conflict="☠${conflicts}"
      fi

      if [ $forward -gt 0 2>/dev/null ] ; then
        local msg_ahead="↑${forward}"
      fi
      if [ $behind -gt 0 2>/dev/null ] ; then
        local msg_behind="↓${behind}"
      fi

      local branch_maxlength=$((${TERM_WIDTH:-80} / 6))
      if [ ${#branch} -gt $branch_maxlength ] ; then
        local branch_name="${branch:0:$((branch_maxlength-3))}..."
      else
        local branch_name=$branch
      fi

      local message="${color} $(_bp_escape "$branch_name") ${msg_clean}${msg_warn_st}${msg_conflict}${msg_changed}${msg_untracked}${msg_behind}${msg_ahead}"
      printf '%s' "${grey}|${message}${reset}"
      )
  fi
}

function _bp_prompt () {
  local prompt_sign='$'
  if [ "$EUID" -eq 0 ] ; then prompt_sign='#' ; fi
  printf '%s\n%s:%s %s%s%s\n%s ' "$(_bp_lastcmdstat "$_bp_exitstatus")" \
    "$(_bp_userandhost)" "$(_bp_pwd)" "$(_bp_gitstatus)" "$(_bp_clock)" "$(_bp_kubectl)" "$prompt_sign"
}

if [ -n "${ZSH_VERSION}" ] ; then
  setopt promptsubst
  typeset -ga precmd_functions preexec_functions
  precmd_functions=(_bp_precmd "${precmd_functions[@]}" _bp_cmd_time_arm)
  preexec_functions+=( _bp_cmd_time_start )
else
  shopt -s promptvars histappend
  # Preserve existing DEBUG traps and both string and array prompt hooks.
  _bp_debug_trap=$(trap -p DEBUG)
  _bp_debug_trap=${_bp_debug_trap#trap -- }
  _bp_debug_trap=${_bp_debug_trap% DEBUG}
  eval "_bp_debug_trap=${_bp_debug_trap:-''}"
  # Bash 3.2 restores DEBUG traps on source/function return; install at the prompt.
  printf -v _bp_debug_command 'trap %q DEBUG' "${_bp_debug_trap:+${_bp_debug_trap}; }_bp_cmd_time_start"
  _bp_debug_command='if [ "${_bp_debug_installed}" != true ] ; then '"${_bp_debug_command}"'; _bp_debug_installed=true; fi; _bp_restore_status'
  unset _bp_debug_trap
  if [[ $(declare -p PROMPT_COMMAND 2> /dev/null) = 'declare -a '* ]] ; then
    PROMPT_COMMAND=(_bp_precmd "$_bp_debug_command" "${PROMPT_COMMAND[@]}" _bp_cmd_time_arm)
  else
    PROMPT_COMMAND="_bp_precmd; ${_bp_debug_command}; ${PROMPT_COMMAND:+${PROMPT_COMMAND}; }_bp_cmd_time_arm"
  fi
  unset _bp_debug_command
fi

PS1='$(_bp_prompt)'
