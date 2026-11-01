# Loaded with fish --init-command after the user's normal configuration.
status is-interactive; or return
set -g __shrun_fish_path (status fish-path)
set -g __shrun_integration_path (status filename)

function __shrun_restart
    history save
    exec "$__shrun_fish_path" --interactive --init-command "source "(string escape -- "$__shrun_integration_path")
end

function __shrun_preexec --on-event fish_preexec
    # The trailing space preserves newlines through command substitution.
    set -l escaped (string replace --all '\\' '\\\\' -- "$argv[1] " | string collect)
    set escaped (string replace --all ';' '\\x3b' -- "$escaped" | string collect)
    set escaped (string replace --all \t '\\x09' -- "$escaped" | string collect)
    set escaped (string replace --all \n '\\x0a' -- "$escaped" | string collect)
    set escaped (string replace --all \r '\\x0d' -- "$escaped" | string collect)
    set escaped (string replace --all \e '\\x1b' -- "$escaped" | string collect)
    set escaped (string replace --all \a '\\x07' -- "$escaped" | string collect)
    printf '\e]633;E;%s\e\\' (string sub --end -1 -- "$escaped")
    # Replace the launcher before the submitted command can execute here.
    __shrun_restart
end

function __shrun_on_exit --on-event fish_exit
    # EOF or a disconnected terminal must end the launcher, not restart it.
    printf '\e]633;P;ShrunExit\e\\'
end
