# Loaded with bash --rcfile; keep the user's normal prompt and completion setup.
[[ $- == *i* ]] || return
__shrun_integration_path=${BASH_SOURCE[0]}
if [[ -f ~/.bashrc ]]; then
    builtin source ~/.bashrc
fi

# History is the complete-command buffer in Bash 3.2 as well as newer versions.
# Filters must not leave us reading an older command instead of the current one.
HISTCONTROL=
HISTIGNORE=
(( HISTSIZE > 0 )) || HISTSIZE=1000
shopt -s cmdhist lithist

__shrun_prompt_commands=("${PROMPT_COMMAND[@]}")
__shrun_original_prompt=$(builtin declare -p PROMPT_COMMAND 2>/dev/null) || __shrun_original_prompt=
__shrun_ready=

__shrun_prompt() {
    local prompt_command
    for prompt_command in "${__shrun_prompt_commands[@]}"; do
        builtin eval "$prompt_command"
    done
    # Enabling history in the rcfile itself would record the integration code.
    set -o history
    __shrun_last_history=$(HISTTIMEFORMAT= builtin history 1)
    __shrun_ready=1
}

__shrun_restart() {
    builtin trap - DEBUG EXIT USR1
    builtin history -a
    # Do not pass our wrapper back through an exported PROMPT_COMMAND.
    unset PROMPT_COMMAND
    [[ -z $__shrun_original_prompt ]] || builtin eval "$__shrun_original_prompt"
    exec "$BASH" --rcfile "$__shrun_integration_path" -i
}

__shrun_preexec() {
    # Prompt hooks and prompt command substitutions are not submitted tasks.
    case $BASH_COMMAND in
        __shrun_prompt | __shrun_on_exit | __shrun_restart)
            __shrun_ready=
            return
            ;;
    esac
    [[ $__shrun_ready == 1 ]] || return
    local command
    command=$(HISTTIMEFORMAT= builtin history 1)
    [[ $command != "$__shrun_last_history" ]] || return
    __shrun_ready=
    builtin trap - DEBUG
    if (( BASH_SUBSHELL > 0 )); then
        # A parenthesized command first triggers DEBUG in its child process.
        # Only the parent reports the task, even if its signal also fires DEBUG.
        builtin trap - EXIT
        unset HISTFILE
        builtin kill -USR1 "$$"
        builtin exit
    fi
    command=${command#*[0-9]  }
    # Bash 3.2's pending history entry omits a simple here-document's body.
    # The parsed command already contains it, including the final delimiter.
    if [[ $command != *$'\n'* && $BASH_COMMAND == *'<<'*$'\n'* ]]; then
        local body=${BASH_COMMAND#*$'\n'}
        command+=$'\n'${body%$'\n'}
    fi
    command=${command//\\/\\\\}
    command=${command//;/\\x3b}
    command=${command//$'\t'/\\x09}
    command=${command//$'\n'/\\x0a}
    command=${command//$'\r'/\\x0d}
    command=${command//$'\e'/\\x1b}
    command=${command//$'\a'/\\x07}
    builtin printf '\e]633;E;%s\e\\' "$command"
    # Replace the launcher before any part of the command executes here.
    __shrun_restart
}

__shrun_on_exit() {
    # EOF or a disconnected terminal must end the launcher, not restart it.
    builtin printf '\e]633;P;ShrunExit\e\\'
}

PROMPT_COMMAND=__shrun_prompt
set -T
builtin trap '__shrun_preexec' USR1
builtin trap '__shrun_on_exit' EXIT
builtin trap '__shrun_preexec' DEBUG
