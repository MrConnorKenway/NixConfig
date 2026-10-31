# Native fish 4.7+ port of p10k-config/p10k.zsh (core segments plus direnv).
# Audited against Powerlevel10k 1.20.15; see test_prompt.py for source/PTY tests.
# Home Manager loads this for interactive shells.
# To preview: source ./p10k-config/p10k.fish
# Requires a Nerd Font; optional environments are displayed only when active.
# Git is queried locally and synchronously; no prompt command contacts a server.
# Powerlevel10k's asynchronous Git loading/stale-display timing is not emulated.
# Cloud, version-manager, VPN and task-tool segments are intentionally omitted.
# User override: show user@hostname only in SSH/Rex/root sessions.

set -g fish_transient_prompt 1

# Match p10k 1.20.15's P9K_TTY lifecycle (internal/p10k.zsh:6877, 7050).
# Keep state across re-sourcing and export it for nested fish/zsh shells.
function __p10k_init_tty
    set -l tty_name (command tty 2>/dev/null)
    if not string match --quiet '/dev/*' -- "$tty_name"
        set -gx P9K_TTY old
        return
    end
    if test -z "$P9K_TTY"; or begin
            test "$P9K_TTY" = old; and test "$_P9K_TTY" != "$tty_name"
        end
        set -gx P9K_TTY old
        set -l changed
        switch (uname -s)
            case Darwin FreeBSD
                set changed (command stat -f %c -- "$tty_name" 2>/dev/null)
            case '*'
                set changed (command stat -c %Z -- "$tty_name" 2>/dev/null)
        end
        if string match --quiet --regex '^[0-9]+$' -- "$changed"
            if test (math (date +%s) - $changed) -lt 5
                set -gx P9K_TTY new
            end
        end
    end
    set -gx _P9K_TTY "$tty_name"
end

function __p10k_preexec --on-event fish_preexec
    set -gx P9K_TTY old
end

function __p10k_postexec --on-event fish_postexec
    set -l last_status $status
    if test $last_status -eq 0; and string match --quiet --regex '^\s*(clear(\s+-(x?(T[a-zA-Z0-9_\x27\x22-]*)?))*|reset)\s*$' -- "$argv[1]"
        set -g __p10k_cleared 1
    end
end

function __p10k_clear_screen
    set -gx P9K_TTY new
    commandline -f clear-screen repaint
end

function __p10k_before_prompt --on-event fish_prompt
    if not set -q __p10k_prompt_seen
        __p10k_init_tty
    else if set -q __p10k_cleared
        set -gx P9K_TTY new
    else
        set -gx P9K_TTY old
    end
    set -g __p10k_prompt_seen 1
    set -e __p10k_cleared
    # Augment only fish's standard preset. User bindings continue to take priority.
    # Retain fish's scrollback handling, and install again after a keymap change.
    if status is-interactive
        for mode in (bind --list-modes)
            set -l binding (bind --preset --mode $mode ctrl-l 2>/dev/null)
            if string match --quiet '*scrollback-push* clear-screen' -- "$binding"
                bind --preset --mode $mode ctrl-l \
                    'status test-terminal-feature scroll-content-up && commandline -f scrollback-push' \
                    __p10k_clear_screen
            end
        end
    end
end

function __p10k_text --description 'Keep external text on one safe terminal line'
    # Match zsh's (V) rendering for ASCII control characters; never emit them raw.
    if not string match --quiet --regex '[[:cntrl:]]' -- "$argv[1]"
        printf '%s' "$argv[1]"
        return
    end
    for char in (string split '' -- "$argv[1]")
        set -l code (printf %d "'$char")
        switch $code
            case 9
                printf '%s' '\t'
            case 10
                printf '%s' '\n'
            case 127
                printf '^?'
            case '*'
                if test $code -lt 32
                    printf '^%b' \\(printf '%03o' (math $code + 64))
                else
                    printf '%s' "$char"
                end
        end
    end
end

function __p10k_os
    switch (uname -s)
        case Darwin
            printf ''
        case Linux
            if test (command uname -o 2>/dev/null) = Android
                printf ''
                return
            end
            set -l distro ''
            if test -r /etc/os-release
                while read -l line
                    if string match --quiet 'ID=*' -- "$line"
                        set distro (string sub --start 4 -- "$line" | string trim --chars '\'"')
                    end
                end </etc/os-release
            else if test -e /etc/artix-release
                set distro artix
            end
            if string match --quiet '*debian*' -- "$distro"; and test -f /etc/apt/sources.list.d/raspi.list
                set distro raspbian
            end
            __p10k_linux_icon "$distro"
        case FreeBSD OpenBSD DragonFly
            printf ''
        case 'CYGWIN*' 'MSYS*' 'MINGW*'
            printf ''
        case SunOS
            printf ''
        case '*'
            printf ''
    end
end

function __p10k_linux_icon --argument-names distro
    # Nerd Font v2 table selected by MODE=nerdfont-complete in the zsh config.
    set -l ids arch raspbian debian ubuntu elementary fedora coreos gentoo mageia \
        centos opensuse tumbleweed sabayon slackware linuxmint alpine aosc nixos \
        devuan manjaro rhel amzn guix
    set -l icons                       
    set -l i 0
    for id in $ids
        set i (math $i + 1)
        if string match --quiet "*$id*" -- "$distro"
            printf '%s' "$icons[$i]"
            return
        end
    end
    printf ''
end

function __p10k_dir --argument-names limit
    set -l markers .bzr .citc .git .hg .node-version .python-version .go-version \
        .ruby-version .lua-version .java-version .perl-version .php-version \
        .tool-version .shorten_folder_marker .svn .terraform CVS Cargo.toml \
        composer.json go.mod package.json stack.yaml
    set -l base /
    set -l display /
    set -l relative "$PWD"
    if test "$PWD" = "$HOME"
        set display '~'
        set relative ''
        set base "$HOME/"
    else if string match --quiet -- "$HOME/*" "$PWD"
        set display '~/'
        set relative (string sub --start (math (string length -- "$HOME") + 2) -- "$PWD")
        set base "$HOME/"
    end
    set -l parts (string split --no-empty / -- "$relative")
    set -l names
    set -l anchors
    set -l parents
    # Iterate actual components: at ~ and / this list is empty. In particular,
    # do not use `seq 0`, which emits 1 and 0 with macOS's BSD seq.
    set -l indices
    for part in $parts
        set -l i (math (count $indices) + 1)
        set -a indices $i
        set -a parents "$base"
        set -a names (__p10k_text "$part")
        set -l anchor 0
        if begin
                test $i -eq 1; and test "$display" = /
            end; or test $i -eq (count $parts)
            set anchor 1
        end
        for marker in $markers
            if test -e "$base$part/$marker"
                set anchor 1
                break
            end
        end
        set -a anchors $anchor
        set base "$base$part/"
    end
    set -l short $names
    # Only shorten when needed, and retain the shortest unambiguous directory prefix.
    for i in $indices
        set -l plain "$display"(string join / -- $short)
        if test (string length --visible -- "$plain") -le $limit
            break
        end
        test $anchors[$i] -eq 0; or continue
        set -l siblings $parents[$i]*/ $parents[$i].*/
        # A hidden directory keeps its leading dots plus its first non-dot char.
        set -l first (string match --regex '(?s)^\.*.' -- "$parts[$i]")
        set -l size (string length -- "$first")
        set -l size_limit (string length -- "$parts[$i]")
        while test $size -le $size_limit
            set -l prefix (string sub --length $size -- "$parts[$i]")
            set -l matches 0
            for sibling in $siblings
                set -l name (path basename -- "$sibling")
                if test (string sub --length $size -- "$name") = "$prefix"
                    set matches (math $matches + 1)
                end
            end
            if test $matches -eq 1
                set short[$i] (__p10k_text "$prefix")
                break
            end
            set size (math $size + 1)
        end
    end
    set -l icon ''
    if not test -w "$PWD"
        set icon ''
    else if test "$PWD" = /etc; or string match --quiet '/etc/*' -- "$PWD"
        set icon ''
    else if test "$PWD" = "$HOME"
        set icon ''
    else if test "$display" = '~/'
        set icon ''
    end
    printf '%s%s ' (set_color 0087af) "$icon"
    set_color normal
    if test "$display" = /
        set_color 0087af
        printf /
    else
        set_color --bold 00afff # p10k 39
        printf '~'
        if test "$display" = '~/'
            set_color normal
            set_color 0087af
            printf /
        end
    end
    for i in $indices
        set_color normal
        if test $anchors[$i] -eq 1
            set_color --bold 00afff
        else if test "$short[$i]" != "$names[$i]"
            set_color 8787af # 103
        else
            set_color 0087af # 31
        end
        printf '%s' "$short[$i]"
        if test $i -lt (count $short)
            set_color normal
            set_color 0087af
            printf /
        end
    end
    set_color normal
end

function __p10k_git
    command -q git; or return
    set -l root (command git rev-parse --show-toplevel 2>/dev/null | string collect)
    test -n "$root"; or return
    test "$root" != (path resolve -- "$HOME"); or return
    # gitstatus counts a staged rename as delete+add and an untracked directory
    # as one entry. Respect the same repository-local visibility settings.
    set -l untracked_mode normal
    for key in status.showUntrackedFiles bash.showUntrackedFiles
        if contains -- (command git config --get "$key" 2>/dev/null) false no 0
            set untracked_mode no
        end
    end
    set -l records (command git --no-optional-locks status --porcelain=v2 --branch --show-stash --no-renames --untracked-files=$untracked_mode -z 2>/dev/null | string split0)
    set -q records[1]; or return
    set -l branch ''
    set -l oid ''
    set -l upstream ''
    set -l ahead 0
    set -l behind 0
    set -l stashes 0
    set -l staged 0
    set -l unstaged 0
    set -l untracked 0
    set -l conflicts 0
    set -l skip 0
    for record in $records
        if test $skip -eq 1
            set skip 0
            continue
        end
        switch (string sub --length 2 -- "$record")
            case '# '
                set -l header (string split --max 2 ' ' -- "$record")
                switch "$header[2]"
                    case branch.head
                        set branch "$header[3]"
                    case branch.oid
                        set oid "$header[3]"
                    case branch.upstream
                        set upstream "$header[3]"
                    case branch.ab
                        set -l ab (string split ' ' -- "$header[3]")
                        set ahead (string sub --start 2 -- "$ab[1]")
                        set behind (string sub --start 2 -- "$ab[2]")
                    case stash
                        set stashes "$header[3]"
                end
            case '1 ' '2 '
                test (string sub --start 3 --length 1 -- "$record") = .; or set staged (math $staged + 1)
                test (string sub --start 4 --length 1 -- "$record") = .; or set unstaged (math $unstaged + 1)
                if string match --quiet '2 *' -- "$record"
                    set skip 1 # A rename has a second NUL-delimited path.
                end
            case 'u '
                set conflicts (math $conflicts + 1)
            case '? '
                set untracked (math $untracked + 1)
        end
    end
    set -l normal (set_color normal)
    set -l green (set_color 5fd700)
    set -l yellow (set_color d7af00)
    set -l blue (set_color 00afff)
    set -l red (set_color ff0000)
    set -l icon ' '
    set -l local_branch "$branch"
    if test "$branch" = '(detached)'
        set -l tags (command git tag --points-at HEAD --sort=refname 2>/dev/null)
        set branch "$tags[-1]"
        set icon '#'
        if test -z "$branch"
            set branch (string sub --length 8 -- "$oid")
            set icon '@'
        end
    end
    if test (string length -- "$branch") -gt 32
        set branch (string sub --length 12 -- "$branch")'…'(string sub --start -12 -- "$branch")
    end
    set -l remote ''
    if test "$local_branch" != '(detached)'
        set remote (command git for-each-ref --format='%(upstream:remotename)' "refs/heads/$local_branch")
    end
    test -n "$remote"; or set remote origin
    set -l remote_url (command git config --get "remote.$remote.url" 2>/dev/null)
    set -l provider (__p10k_git_icon "$remote_url")
    printf '%son %s%s ' "$normal" "$green" "$provider"
    if test "$icon" != ' '
        printf '%s' "$normal"
    end
    printf '%s%s%s' "$icon" "$green" (__p10k_text "$branch")
    if test -n "$upstream"
        set -l remote_branch (command git for-each-ref --format='%(upstream:remoteref)' "refs/heads/$local_branch")
        set remote_branch (string replace 'refs/heads/' '' -- "$remote_branch")
        if test -n "$remote_branch"; and test "$remote_branch" != "$local_branch"
            printf '%s:%s%s' "$normal" "$green" (__p10k_text "$remote_branch")
        end
    end
    if test $behind -gt 0
        printf ' %s⇣%s' "$green" $behind
    end
    if test $ahead -gt 0
        test $behind -gt 0; or printf ' '
        printf '%s⇡%s' "$green" $ahead
    end
    set -l push_ref (command git rev-parse --symbolic-full-name '@{push}' 2>/dev/null)
    set -l upstream_ref (command git rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null)
    if test -n "$push_ref"; and test "$push_ref" != "$upstream_ref"
        set -l counts (command git rev-list --left-right --count "HEAD...$push_ref" 2>/dev/null | string split --no-empty \t)
        if test (count $counts) -eq 2
            if test $counts[2] -gt 0
                printf ' %s⇠%s' "$green" $counts[2]
            end
            if test $counts[1] -gt 0
                test $counts[2] -gt 0; or printf ' '
                printf '%s⇢%s' "$green" $counts[1]
            end
        end
    end
    test $stashes -eq 0; or printf ' %s*%s' "$green" $stashes
    set -l gitdir (command git rev-parse --absolute-git-dir 2>/dev/null | string collect)
    set -l action ''
    if test -d "$gitdir/rebase-merge"
        set action rebase-m
        test ! -f "$gitdir/rebase-merge/interactive"; or set action rebase-i
    else if test -d "$gitdir/rebase-apply"
        set action am/rebase
        test ! -f "$gitdir/rebase-apply/rebasing"; or set action rebase
        test ! -f "$gitdir/rebase-apply/applying"; or set action am
    else if test -f "$gitdir/MERGE_HEAD"
        set action merge
    else if test -f "$gitdir/CHERRY_PICK_HEAD"
        set action cherry-pick
    else if test -f "$gitdir/REVERT_HEAD"
        set action revert
    else if test -f "$gitdir/BISECT_LOG"
        set action bisect
    end
    set -l step_file "$gitdir/rebase-merge/msgnum"
    set -l total_file "$gitdir/rebase-merge/end"
    if test -d "$gitdir/rebase-apply"
        set step_file "$gitdir/rebase-apply/next"
        set total_file "$gitdir/rebase-apply/last"
    end
    if test -r "$step_file"; and test -r "$total_file"
        read -l step <"$step_file"
        read -l total <"$total_file"
        if string match --quiet --regex '^[0-9]+$' -- "$step"; and string match --quiet --regex '^[0-9]+$' -- "$total"
            set action "$action $step/$total"
        end
    end
    test -z "$action"; or printf ' %s%s' "$red" "$action"
    if contains -- (command git config --get bash.showDirtyState 2>/dev/null) false no 0
        set conflicts 0
        set staged 0
        set unstaged 0
    end
    test $conflicts -eq 0; or printf ' %s~%s' "$red" $conflicts
    test $staged -eq 0; or printf ' %s+%s' "$yellow" $staged
    test $unstaged -eq 0; or printf ' %s!%s' "$yellow" $unstaged
    test $untracked -eq 0; or printf ' %s?%s' "$blue" $untracked
    printf '%s' "$normal"
end

function __p10k_git_icon --argument-names remote_url
    # Same host matching and Nerd Font v2 icons as _p9k_vcs_icon.
    set -l host (string replace --regex '^[A-Za-z0-9+.-]+://' '' -- "$remote_url" | string replace --regex '^[^/@]*@' '' | string replace --regex '[:/].*$' '' | string lower)
    switch "$host[1]"
        case github.com
            printf ''
        case bitbucket.org
            printf ''
        case gitlab.com freedesktop.org gnome.org kde.org
            printf ''
        case dev.azure.com '*.visualstudio.com' visualstudio.com
            printf ﴃ
        case archlinux.org
            printf ''
        case debian.org
            printf ''
        case freebsd.org
            printf ''
        case gnu.org
            printf ''
        case kernel.org
            printf ''
        case sr.ht '*.sr.ht'
            printf ''
        case '*'
            printf ''
    end
end

function __p10k_duration --argument-names milliseconds
    test "$milliseconds" -ge 3000 2>/dev/null; or return
    set -l seconds (math "round($milliseconds / 1000)")
    printf '%stook %s ' (set_color normal) (set_color 87875f)
    if test $milliseconds -lt 60000
        printf '%ss' $seconds
    else
        set -l units d h m s
        set -l divisors 86400 3600 60 1
        set -l started 0
        for i in 1 2 3 4
            set -l value (math "floor($seconds / $divisors[$i])")
            set seconds (math "$seconds % $divisors[$i]")
            if test $value -gt 0; or test $started -eq 1
                set started 1
                printf '%s%s' $value $units[$i]
                test $i -eq 4; or printf ' '
            end
        end
    end
    set_color normal
end

function __p10k_virtualenv
    set -l name (path basename -- "$VIRTUAL_ENV")
    set -l configured 0
    if test -r "$VIRTUAL_ENV/pyvenv.cfg"
        while read -l line
            if string match --quiet --regex '^prompt[ \t]*=' -- "$line"
                set name (string replace --regex '^prompt[ \t]*=[ \t]*' '' -- "$line" | string trim | string collect)
                set configured 1
                # p10k treats quoted pyvenv prompts as literal text with C escapes.
                if string match --quiet --regex '^([\x27\x22]).*\1$' -- "$name"
                    set name (string sub --start 2 --length (math (string length -- "$name") - 2) -- "$name")
                    set name (printf '%b' "$name" | string collect)
                end
            end
        end <"$VIRTUAL_ENV/pyvenv.cfg"
    end
    if test $configured -eq 0
        if string match --quiet --regex '^\(.+\) $' -- "$VIRTUAL_ENV_PROMPT"; and test "$VIRTUAL_ENV_PROMPT" != "($name) "
            set name (string sub --start 2 --length (math (string length -- "$VIRTUAL_ENV_PROMPT") - 3) -- "$VIRTUAL_ENV_PROMPT")
        else if contains -- "$name" virtualenv venv .venv env
            set name (path basename -- (path dirname -- "$VIRTUAL_ENV"))
        end
    end
    __p10k_text "$name"
end

function __p10k_right --argument-names last_status duration
    set -l pipes $argv[3..]
    set -l segments
    set -l failed 0
    for code in $pipes
        test $code -eq 0; or set failed 1
    end
    if test (count $pipes) -gt 1; and test $failed -eq 1
        set -l color 5faf00
        set -l icon ✔
        if test $last_status -ne 0
            set color d70000
            set icon ✘
        end
        set -a segments (set_color $color)"$icon "(string join '|' -- (fish_status_to_signal $pipes | string replace --regex '^SIG' ''))
    else if test $last_status -gt 128
        set -a segments (set_color d70000)'✘ '(fish_status_to_signal $last_status | string replace --regex '^SIG' '')
    end
    set -l elapsed (__p10k_duration "$duration")
    test -z "$elapsed"; or set -a segments "$elapsed"
    if jobs --query
        set -a segments (set_color 5faf00)''
    end
    if test -n "$DIRENV_DIR"
        set -a segments (set_color d7af00)'▼'
    end
    if set -q VIRTUAL_ENV; and test -n "$VIRTUAL_ENV"
        set -l name (__p10k_virtualenv | string collect)
        set -l segment (set_color 00afaf)''
        test -z "$name"; or set segment "$segment $name"
        set -a segments "$segment"
    end
    set -l conda "$CONDA_PREFIX"
    test -n "$conda"; or set conda "$CONDA_ENV_PATH"
    if test -n "$conda"
        set -a segments (set_color 00afaf)' '(__p10k_text (path basename -- "$conda"))
    end
    # Show context only for SSH, Rex terminals, or root; use a short hostname.
    # Rex supplies REX_SESSION and REX_BLOCK when it opens a terminal.
    set -l short_hostname (string split --max 1 . -- "$hostname")
    if fish_is_root_user
        set -a segments (set_color normal)'with '(set_color --bold d7af00)(__p10k_text "$USER@$short_hostname[1]")
    else if test -n "$SSH_CONNECTION$SSH_CLIENT$SSH_TTY$REX_SESSION$REX_BLOCK"
        set -a segments (set_color normal)'with '(set_color d7af87)(__p10k_text "$USER@$short_hostname[1]")
    end
    if test -n "$IN_NIX_SHELL"; and test "$IN_NIX_SHELL" != 0
        set -l segment (set_color 5fafd7)''
        if contains -- "$IN_NIX_SHELL" pure impure
            set segment "$segment $IN_NIX_SHELL"
        end
        set -a segments "$segment"
    end
    printf '%s' (string join (set_color normal)' ' -- $segments)
    set_color normal
end

function __p10k_symbol --argument-names last_status mode
    set -q argv[2]; or set mode "$fish_bind_mode"
    set -l color 5fd700
    test $last_status -eq 0; or set color ff0000
    set_color $color
    switch "$mode"
        case default
            if contains -- "$fish_key_bindings" fish_vi_key_bindings fish_hybrid_key_bindings
                printf '❮'
            else
                printf '❯'
            end
        case visual
            printf Ⅴ
        case replace replace_one
            printf '▶'
        case '*'
            printf '❯'
    end
    printf '%s ' (set_color normal)
end

function fish_mode_prompt
    # The mode is represented by the prompt symbol, without changing bindings.
end

function __p10k_wrap --argument-names text columns
    # Unlike zsh, fish clips an overlong prompt line from the left. Insert hard
    # wraps at display-cell boundaries to preserve p10k's anchored path/content.
    set -l used 0
    for token in (string match --all --regex '\e\[[0-9;]*m|.' -- "$text")
        set -l width (string length --visible -- "$token")
        if test $width -gt 0; and test (math $used + $width) -gt $columns
            printf '\n'
            set used 0
        end
        printf '%s' "$token"
        set used (math $used + $width)
    end
end

function fish_prompt
    set -l last_pipestatus $pipestatus
    set -l last_status $status
    if contains -- --final-rendering $argv
        # p10k's transient prompt always uses the insert-mode symbol.
        __p10k_symbol $last_status insert
        return
    end
    if not set -q __p10k_prompt_seen
        __p10k_before_prompt
    end
    set -l columns 80
    set -q COLUMNS; and set columns $COLUMNS
    set -l gray (set_color 808080)
    set -l normal (set_color normal)
    set -l right (__p10k_right $last_status "$CMD_DURATION" $last_pipestatus | string collect)
    set -l vcs (__p10k_git | string collect)
    set -l dir_limit 80
    set -l directory (__p10k_dir $dir_limit | string collect)
    set -l prefix "$gray╭─ $normal"(__p10k_os)' '
    set -l left "$prefix$directory"
    test -z "$vcs"; or set left "$left $vcs"
    set -l width (string length --visible -- "$left")
    set -l right_width (string length --visible -- "$right")
    # zsh's default ZLE_RPROMPT_INDENT leaves the final terminal column empty.
    set -l gap (math "$columns - $width - $right_width - 4")
    if test $gap -lt 1
        # p10k shortens the directory to make room for the right-hand segments
        # before hiding them. Keep anchors even if they exceed the soft limit.
        set dir_limit (math "max(1, min(80, "(string length --visible -- "$directory")" + $gap - 1))")
        set directory (__p10k_dir $dir_limit | string collect)
        set left "$prefix$directory"
        test -z "$vcs"; or set left "$left $vcs"
        set width (string length --visible -- "$left")
        set gap (math "$columns - $width - $right_width - 4")
    end
    test "$P9K_TTY" = new; or printf '\n'
    if test $gap -ge 1
        printf '%s%s%s%s ─╮%s\n' "$left" (string repeat --count $gap ' ') "$right" "$gray" "$normal"
    else
        # p10k hides the whole right prompt, including its frame, on overlap.
        # Anchored directories and Git content remain intact and can wrap.
        if test $width -gt $columns
            __p10k_wrap "$left" $columns
        else
            printf '%s' "$left"
        end
        printf '%s\n' "$normal"
    end
    printf '%s╰─%s' "$gray" "$normal"
    __p10k_symbol $last_status
end

function fish_right_prompt
    contains -- --final-rendering $argv; and return
    printf '%s─╯%s ' (set_color 808080) (set_color normal)
end
