# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# Profile selection precedence:
#   1. TERM_PROFILE from the environment (Konsole exports it) -- explicit wins.
#   2. Otherwise map by hostname -- headless boxes (Hetzner, no Konsole to
#      export the env) still pick a sensible world on their own.
#   3. Otherwise fall back to the generic default.
if [[ -z "$TERM_PROFILE" ]]; then
    case "$HOST" in                        # $HOST is a zsh builtin -- no subshell
        debian-8gb-hel1-1)  TERM_PROFILE="work" ;;   # dev server: docker, git, drush
        naelaedra|tyrande)  TERM_PROFILE="katy" ;;
        *)                  TERM_PROFILE="default" ;;
    esac
fi
print -u2 "zshrc: hostname is '$HOST'"
print -u2 "zshrc: TERM_PROFILE is set to '$TERM_PROFILE'"

# Directory holding per-profile config fragments. Keeping these as separate
# sourced files (rather than one giant if-block) means each "world" is
# self-contained and readable on its own -- easy to diff, easy to reason about.
ZSH_PROFILE_DIR="${ZDOTDIR:-$HOME}/.config/zsh/profiles"

# Default zsh plugins shared by every profile. Each profile below merges its
# own array on top of these, so the defaults are the common baseline.
default_plugins=(common-aliases you-should-use zsh-autosuggestions zsh-syntax-highlighting)
theme_name="robbyrussell"

# DRY baseline: every shell gets default.zsh first, then the profile-specific
# fragment layers its extras/overrides on top. Shared config lives in one place
# instead of being copy-pasted into work + personal. (Sourced after the plugin/
# theme defaults above so default.zsh can nudge those too if it ever needs to.)
# Guarded like .profile below: if the fragment is missing (linker drift, fresh
# box mid-setup), skip it quietly instead of erroring on every new shell.
[[ -f "$ZSH_PROFILE_DIR/default.zsh" ]] && source "$ZSH_PROFILE_DIR/default.zsh"

case "$TERM_PROFILE" in
  work)
    # Harvard/Alicanto + the Hetzner dev box: Acquia aliases, Drupal drush
    # shortcuts, docker, git -- whatever keeps you from fat-fingering a deploy.
    print -u2 "zshrc: loading work profile"
    source "$ZSH_PROFILE_DIR/work.zsh"
    work_plugins=(composer docker docker-compose drush git git-autofetch git-commit git-extras gitignore git-prompt ssh symfony sudo)
    # defaults first, then the work-only plugins appended after them.
    plugins=("${default_plugins[@]}" "${work_plugins[@]}")
    case "$HOST" in                        # distinct prompt per work machine
        debian-8gb-hel1-1)  theme_name="darkblood" ;;      # Hetzner = "you're on prod, think first"
        *)                  theme_name="clean-detailed" ;; # local work terminals
    esac
    ;;
  katy)
    # Home box energy: docker aliases (dps!), WoW-adjacent nonsense, the fun.
    print -u2 "zshrc: loading personal profile"
    source "$ZSH_PROFILE_DIR/personal.zsh"
    personal_plugins=()
    # defaults first, then the personal-only plugins appended after them.
    plugins=("${default_plugins[@]}" "${personal_plugins[@]}")

    case "$HOST" in                        # per-machine prompt flair
        naelaedra)  theme_name="hunk" ;;
        tyrande)    theme_name="M365Princess" ;;
        *)          theme_name="M365Princess" ;;
    esac
    ;;
  *)
    # Unknown value -- warn once so a typo in the profile env editor doesn't
    # silently give you the wrong world. default.zsh is already sourced above,
    # so just fall back to the base plugins.
    print -u2 "zshrc: unknown TERM_PROFILE '$TERM_PROFILE', using default only"
    plugins=("${default_plugins[@]}")
    ;;
esac

if [ -f $ZSH/oh-my-zsh.sh ]; then
    source $ZSH/oh-my-zsh.sh
else
    echo "Error: Oh My Zsh not found at $ZSH. Please check your installation."
fi

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Source .profile for PATH and environment variables on zsh login shells
[[ -f "$HOME/.profile" ]] && source "$HOME/.profile"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Note: ~/.aliases and ~/.functions are sourced from ~/.profile (pulled in
# above), so both zsh and bash share one source-of-truth. Don't re-source them
# here or they'd load twice.

# Special alias to reload .zshrc
# use omz reload if it exists.
if type omz &>/dev/null; then
    alias reload-zsh='omz reload'
else
    alias reload-zsh='source ~/.zshrc'
fi

# if oh-my-posh is installed, initialise it with the profile's theme.
# We check the theme JSON actually exists (not just that $theme_name is set) so a
# missing file -- e.g. a theme present locally but not yet on this box -- degrades
# to oh-my-posh's built-in default with a warning, instead of a broken prompt.
if [ -x "$(command -v oh-my-posh)" ]; then
    theme_file="$HOME/.cache/oh-my-posh/themes/${theme_name}.omp.json"
    if [ -n "$theme_name" ] && [ -f "$theme_file" ]; then
        print -u2 "zshrc: oh-my-posh theme set to $theme_name"
        eval "$(oh-my-posh init zsh --config "$theme_file")"
    else
        print -u2 "zshrc: oh-my-posh theme '$theme_name' not found at $theme_file -- using oh-my-posh default"
        eval "$(oh-my-posh init zsh)"
    fi
fi

# NVM environment
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
fi

# function to nuclear reset zoom folder
_zoom_reset() {
    echo -n "Are you sure you want to reset all Zoom data? This cannot be undone. (y/N) "
    read -n 1 REPLY
    echo # move to a new line after the user input
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ~/.zoom/data/*
        mkdir -p ~/.zoom/data
        echo "Zoom data has been reset."
    else
        echo "Zoom reset cancelled."
    fi
}

if [ -d $HOME/.cargo ]; then
    . "$HOME/.cargo/env"
fi

#compdef weathr

autoload -U is-at-least

_weathr() {
    typeset -A opt_args
    typeset -a _arguments_options
    local ret=1

    if is-at-least 5.2; then
        _arguments_options=(-s -S -C)
    else
        _arguments_options=(-s -C)
    fi

    local context curcontext="$curcontext" state line
    _arguments "${_arguments_options[@]}" : \
'-s+[Simulate weather condition (clear, rain, drizzle, snow, etc.)]:CONDITION:_default' \
'--simulate=[Simulate weather condition (clear, rain, drizzle, snow, etc.)]:CONDITION:_default' \
'--completions=[]:SHELL:(bash elvish fish powershell zsh)' \
'-n[Simulate night time (for testing moon, stars, fireflies)]' \
'--night[Simulate night time (for testing moon, stars, fireflies)]' \
'-l[Enable falling autumn leaves]' \
'--leaves[Enable falling autumn leaves]' \
'--auto-location[Auto-detect location via IP (uses ipinfo.io)]' \
'--hide-location[Hide location coordinates in UI]' \
'--hide-hud[Hide HUD (status line)]' \
'(--metric)--imperial[Use imperial units (°F, mph, inch)]' \
'(--imperial)--metric[Use metric units (°C, km/h, mm)]' \
'--silent[Run silently (suppress non-error output)]' \
'-h[Print help]' \
'--help[Print help]' \
'-V[Print version]' \
'--version[Print version]' \
&& ret=0
}

(( $+functions[_weathr_commands] )) ||
_weathr_commands() {
    local commands; commands=()
    _describe -t commands 'weathr commands' commands "$@"
}

if [ "$funcstack[1]" = "_weathr" ]; then
    _weathr "$@"
else
    compdef _weathr weathr
fi

typeset -U PATH
