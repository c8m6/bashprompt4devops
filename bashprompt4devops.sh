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
###########################################################

# color definitions
if [ "${TERM}" == 'xterm-256color' ] ; then
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

# functions
function _bp_get_ttywidth () {
  export TERM_WIDTH=$(stty size | awk '{print $2}')
}

function _bp_cmd_time_start () {
  timer=${timer:-$SECONDS}
}

function _bp_cmd_time_stop {
  execution_time=$(($SECONDS - $timer))
  if [ $execution_time -lt 10 ] ; then
    cmd_runtime="$(date -d@${execution_time} -u +%ss)"
  elif [ $execution_time -lt 600 ] ; then
    cmd_runtime="$(date -d@${execution_time} -u '+%mm %Ss')"
  elif [ $execution_time -lt 3600 ] ; then
    cmd_runtime="$(date -d@${execution_time} -u '+%Mm %Ss')"
  else
    cmd_runtime="$(date -d@${execution_time} -u '+%Hh %Mm %Ss')"
  fi
  unset timer
}

trap '_bp_cmd_time_start' DEBUG

PROMPT_COMMAND="_bp_cmd_time_stop ; history -a ; _bp_get_ttywidth"

function _bp_lastcmdstat () {
  if [ -z $BP_DISABLE_EXITSTATUS ] ; then
    if [ ! $1 -eq 0 ] ; then
      local error_color=$red
      local error_sign='😱'
      local error_code=" ${1} "
    else
      local error_color=''
      local error_sign=''
    fi

    if [ $execution_time -gt -0 ] ; then
      local msg_time="${grey}⌚${cmd_runtime}${reset}"
    fi

    echo -ne "${error_color}${error_sign}${error_code}${msg_time}"
  fi
}

function _bp_pwd () {
  local path_element
  local path_part
  local current_dir=$(dirs +0)
  local last_dir=$(basename ${current_dir})
  local path_maxlength=$(echo "$TERM_WIDTH / 3" | bc | cut -d '.' -f 1)
  local current_repo=$(git rev-parse --show-toplevel 2> /dev/null)
  current_repo=${current_repo/$HOME/\~}
  current_repo_name=${current_repo##*/}

  oIFS="$IFS"
  IFS='/'
  for path_element in $current_dir ; do
    if [ ! "x${path_element}x" == "xx" ] ; then
      if [ "${path_element}" == "${current_repo_name}" ] ; then
        path_part="${path_part}/${blue}${path_element}${cyan}"
      elif [ "${path_element}" == '~' ] ; then
        path_part='~'
      else
        if [[ ${#current_dir} -gt $path_maxlength && "${path_element}" != "${last_dir}" ]]; then
          path_part="${path_part}/${path_element:0:1}"
        else
          path_part="${path_part}/${path_element}"
        fi
      fi
    fi
  done
  IFS=$oIFS

  local dir_msg="${cyan}${path_part}/${reset}"

  echo -ne "${dir_msg}"
}

function _bp_kubectl () {
  if [ `which kubectl` ] && [ -f ~/.kube/config ] ; then
    local current_context=$(cat ~/.kube/config | grep "current-context:" | sed "s/current-context: //")
    if [ ! -z $current_context ] ; then
      echo -ne "${grey}|${green}☸ ${current_context}${reset}"
    fi
  fi
}

function _bp_clock () {
  if [ -z $BP_DISABLE_CLOCK ] ; then
    echo -ne "${grey}|${blue}🕑$(date +%H:%M)${reset}"
  fi
}

function _bp_userandhost () {
  local user=$(whoami)
  local host=$(hostname)

  if [ $user == 'root' ] ; then
    local user_color=$red
  else
    local user_color=$green
  fi
  local part_user="${user_color}${user}"

  if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    local part_host="${yellow}@${host}"
  else
    local part_host="${green}@${host}"
  fi

  echo -ne "${part_user}${part_host}"
}

function _bp_gitstatus () {
  local repo=$(git rev-parse --show-toplevel 2> /dev/null)
  if [ ! "${repo}" == "" ] ; then
    if test $(find ${repo}/.git/FETCH_HEAD -mmin +5 2> /dev/null) ; then
      GIT_TERMINAL_PROMPT=0 git fetch --quiet &disown
    fi
		local branch
    local fetch_rm
		local changed=0
		local conflicts=0
    local untracked=0
		local warn=0
    local error=0

		git status --porcelain=2 --branch | (
      while read line ; do
      	case "${line}" in
					'# branch.head'*)		branch=$(echo $line | cut -d" " -f3)	; ;;
          '# branch.ab'*) 		fetch_a=$(echo $line | cut -d" " -f3)	; fetch_b=$(echo $line | cut -d" " -f4) ; ;;
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

			if [ $warn -gt 0 ] ; then
				local color=$yellow
      elif [ $error -gt 0 ] ; then
				local color=$red
      else
				local color=$green
        local msg_clean="${green}✔"
			fi

      if [ $warn_st -eq 0 ] && [ "${msg_clean}" == "" ] ; then
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

      local branch_maxlength=$(echo "$TERM_WIDTH / 6" | bc | cut -d '.' -f 1)
      if [ ${#branch} -gt $branch_maxlength ] ; then
        local branch_name=$(printf "%.$[branch_maxlength-3]s..." "${branch}")
      else
        local branch_name=$branch
      fi

      local message="${color} ${branch_name} ${msg_clean}${msg_warn_st}${msg_conflict}${msg_changed}${msg_untracked}${msg_behind}${msg_ahead}"
     	echo -ne "${grey}|${message}${reset}"
      )
  fi
}

set -m

export PS1="\$(_bp_lastcmdstat \$?)\n\$(_bp_userandhost):\$(_bp_pwd) \$(_bp_gitstatus)\$(_bp_clock)\$(_bp_kubectl)\n# "

