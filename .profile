# Executed by login shells. Shell agnostic - no bash or zsh specific syntax.
# Sourced by ~/.zprofile for zsh login shells.

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# Add user's private bin directories to PATH if they exist
if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/webdev/projects/codeberg/pixiekat/dotfiles/bin" ]; then
    PATH="$HOME/webdev/projects/codeberg/pixiekat/dotfiles/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/.cargo/bin" ]; then
    PATH="$HOME/.cargo/bin:$PATH"
fi

if [ -d "$HOME/.config/composer/vendor/bin" ]; then
    PATH="$HOME/.config/composer/vendor/bin:$PATH"
fi

if [ -d "$HOME/.symfony5/bin" ]; then
    PATH="$HOME/.symfony5/bin:$PATH"
fi

if [ -d "$HOME/.yarn/bin" ]; then
    PATH="$HOME/.yarn/bin:$PATH"
fi

# Rust/Cargo environment
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Deno environment
if [ -f "$HOME/.deno/env" ]; then
    . "$HOME/.deno/env"
fi

# Add symfonycli to PATH
if [ -d "$HOME/.symfony5/bin" ]; then
    PATH="$HOME/.symfony5/bin:$PATH"
fi

if [ -d "$HOME/.config/symfony-cli/bin" ]; then
    PATH="$HOME/.config/symfony-cli/bin:$PATH"
fi

# Add bash-games to PATH, if they exist.
if [ -d "$HOME/webdev/projects/codeberg/pixiekat/bash-games" ]; then
    PATH="$HOME/webdev/projects/codeberg/pixiekat/bash-games:$PATH"
fi

# Shell-agnostic aliases and functions, sourced from one place so both shells
# inherit them (zsh pulls this via `source ~/.profile` in .zshrc; bash reaches
# its own copies via .bashrc).
#
# Guarded to INTERACTIVE shells only ($- contains 'i'). Two reasons:
#   1. aliases/functions are meaningless non-interactively, so there's nothing
#      to gain from loading them in a script or one-shot.
#   2. it keeps a non-interactive /bin/sh -- e.g. the display manager sourcing
#      ~/.profile at graphical login -- from parsing bash/zsh-only syntax such
#      as hyphenated function names (pixiekat-*), which dash rejects outright.
# Interactive zsh/bash accept that syntax fine, so our names stay ergonomic.
case "$-" in
  *i*)
    [ -f "$HOME/.aliases" ]           && . "$HOME/.aliases"
    [ -f "$HOME/.functions" ]         && . "$HOME/.functions"
    [ -f "$HOME/.aliases_private" ]   && . "$HOME/.aliases_private"
    [ -f "$HOME/.functions_private" ] && . "$HOME/.functions_private"
    ;;
esac
