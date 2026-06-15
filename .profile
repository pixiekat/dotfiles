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
