# default.zsh -- shared baseline sourced by EVERY profile (work, katy, and the
# unknown-profile fallback) before the profile-specific fragment layers on top.
# Put things here that every world should get. Zsh-only: this file is sourced
# from .zshrc, never from .profile/.bashrc, so zsh builtins like `print` are fine.

# Package manager judgement (corrected for Red Hat crimes).
# Lives here rather than in personal.zsh so the work profile gets judged too. >:3
if [ -x "$(command -v apt)" ]; then
    # apt = Debian family; sub-sort by the exact distro via /etc/os-release.
    # Sourcing it in $(...) runs in a subshell, so ID (and NAME/VERSION/etc.)
    # never leak into the real shell environment.
    distro_id=$(. /etc/os-release 2>/dev/null && echo "$ID")
    case "$distro_id" in
        linuxmint)  print -u2 "mint? cinnamon toast crunch. good puppygirl!" ;;
        ubuntu)     print -u2 "ubuntu. snaps and all, bless. still love you." ;;
        pop)        print -u2 "pop!_os? System76 gang. tasteful." ;;
        debian|*)   print -u2 "debian? good puppygirl!" ;;   # plain Debian + anything unlabeled
    esac
else
    # not-debian fallbacks
    if [ -x "$(command -v nix-env)" ] || [ -x "$(command -v nix)" ]; then
        print -u2 "NixOS. you've ascended. or lost your mind. possibly both."
    elif [ -x "$(command -v port)" ]; then
        print -u2 "macports?? oh you're a PURIST temu unix user. respect, kind of."
    elif [ -x "$(command -v brew)" ]; then
        print -u2 "apple tax on temu unix in this economy?"
    elif [ -x "$(command -v yum)" ]; then
        print -u2 "Oh god what is wrong with you?"
    elif [ -x "$(command -v dnf)" ]; then
        print -u2 "Oh god what is wrong with you? (but make it newer)"
    elif [ -x "$(command -v pacman)" ]; then
        print -u2 "btw i use arch (you didn't even have to tell me)"
    elif [ -x "$(command -v zypper)" ]; then
        print -u2 "openSUSE? bold choice. respect."
    elif [ -x "$(command -v apk)" ]; then
        print -u2 "Alpine. minimalist. i see you."
    elif [ "$(uname)" = "Darwin" ]; then
        print -u2 "darwin detected. condolences re: the dock."
    elif [ -x "$(command -v emerge)" ]; then
        print -u2 "...you compile everything? sir/madam/friend, your CPU is tired."
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        print -u2 "WSL? linux in a windows trenchcoat. we see you."
    fi
fi

# Trash aliases
typeset -g TRASH_DIR="/home/$USER/.local/share/Trash"
if [ -x "$(command -v gio)" ]; then
    alias trash-empty="gio trash --empty"
    alias trash-picking="gio trash --list"
else
    if [ -d "$TRASH_DIR" ]; then
        alias trash-empty="rm -rf $TRASH_DIR/*"
        alias trash-picking="find $TRASH_DIR -type f"
    fi
fi

# ── bin-it <file>... ────────────────────────────────────────────────
# Move files to the trash instead of deleting them.
# Tries, in order: gio (GNOME/KDE-friendly), trash-put (trash-cli),
# then a plain mv into $TRASH_DIR as a last resort.
# (rm is still there if you really mean it.)
bin-it() {
    # No arguments? Show usage instead of doing something odd.
    if (( $# == 0 )); then
        echo "Usage: bin-it <file>..." >&2
        return 1
    fi

    if [ -x "$(command -v gio)" ]; then
        gio trash -- "$@"
    elif [ -x "$(command -v trash-put)" ]; then
        trash-put -- "$@"
    elif [ -d "$TRASH_DIR/files" ]; then
        # -n = never overwrite something already in the trash.
        # Note: this path doesn't record the original location.
        mv -n -- "$@" "$TRASH_DIR/files/"
    else
        echo "No trash method found. Nothing was moved." >&2
        return 1
    fi

    # $? is the exit status of whichever branch ran above.
    if (( $? == 0 )); then
        echo "Moved $* to trash. Use 'trash-empty' to empty it, or 'trash-picking' to see what's in it."
    else
        echo "Something went wrong; check the files above :(" >&2
        return 1
    fi
}
