builtin autoload -Uz add-zsh-hook

# Prevent the script recursing when setting up
if [ -n "$SHRUN_SHELL_INTEGRATION" ]; then
	ZDOTDIR=$USER_ZDOTDIR
	builtin return
fi

# This variable allows the shell to both detect that VS Code's shell integration is enabled as well
# as disable it by unsetting the variable.
SHRUN_SHELL_INTEGRATION=1

# By default, zsh will set the $HISTFILE to the $ZDOTDIR location automatically. In the case of the
# shell integration being injected, this means that the terminal will use a different history file
# to other terminals. To fix this issue, set $HISTFILE back to the default location before ~/.zshrc
# is called as that may depend upon the value.
HISTFILE=$USER_ZDOTDIR/.zsh_history

# Only fix up ZDOTDIR if shell integration was injected (not manually installed) and has not been called yet
if [[ $options[norcs] = off  && -f $USER_ZDOTDIR/.zshrc ]]; then
	VSCODE_ZDOTDIR=$ZDOTDIR
	ZDOTDIR=$USER_ZDOTDIR
	# A user's custom HISTFILE location might be set when their .zshrc file is sourced below
	. $USER_ZDOTDIR/.zshrc
fi

# Shell integration was disabled by the shell, exit without warning assuming either the shell has
# explicitly disabled shell integration as it's incompatible or it implements the protocol.
if [ -z "$SHRUN_SHELL_INTEGRATION" ]; then
	builtin return
fi

__vsc_escape_value() {
	builtin emulate -L zsh

	# Process text byte by byte, not by codepoint.
	builtin local LC_ALL=C str="$1" i byte token out=''

	for (( i = 0; i < ${#str}; ++i )); do
		byte="${str:$i:1}"

		# Escape backslashes, semi-colons and newlines
		if [ "$byte" = "\\" ]; then
			token="\\\\"
		elif [ "$byte" = ";" ]; then
			token="\\x3b"
		elif [ "$byte" = $'\t' ]; then
			token="\\x09"
		elif [ "$byte" = $'\n' ]; then
			token="\\x0a"
		else
			token="$byte"
		fi

		out+="$token"
	done

	builtin print -r "$out"
}

__shrun_preexec() {
	printf "\033]633;E;%s\033\\" "$(__vsc_escape_value $3)"
	print -s $2
	USER_ZDOTDIR=$HOME ZDOTDIR=$HOME/.config/nvim/shell_integration exec zsh -i
}

__shrun_precmd() {
	printf "\033]133;B\a"
}

add-zsh-hook preexec __shrun_preexec
add-zsh-hook precmd __shrun_precmd

if [[ $options[login] = off && $USER_ZDOTDIR != $VSCODE_ZDOTDIR ]]; then
	ZDOTDIR=$USER_ZDOTDIR
fi
