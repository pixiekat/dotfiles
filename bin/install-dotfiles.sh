#!/usr/bin/env bash
#
# install-dotfiles.sh
#
# Installs dotfiles from a local clone of your dotfiles repository
# into your home directory via symlinks. Backs up any existing files
# before replacing them.
#
# Usage: ./install-dotfiles.sh
#
# ---------------------------------------------------------------------------

# -- Helpers ----------------------------------------------------------------
#
# These are defined FIRST, before any other code runs. Bash resolves a function
# name at call time, not parse time, so a function must have already been
# *executed* (its definition statement run) before anything can call it.
# Defining these below the configuration block meant the info() calls down there
# fired before info() existed, and printed "info: command not found" to stderr.

# Print a status message
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }

# ---------------------------------------------------------------------------


# -- Configuration ----------------------------------------------------------

# Use webdev/projects/codeberg/pixiekat/dotfiles as the source of truth for where the dotfiles are located.
# else check to see $HOME/dotfiles else fail with an error message asking the user to clone their dotfiles
# repo to one of those locations.
if [ -d "$HOME/webdev/projects/codeberg/pixiekat/dotfiles" ]; then
    DOTFILES_DIR="$HOME/webdev/projects/codeberg/pixiekat/dotfiles"
    info "Using dotfiles directory: $DOTFILES_DIR"
elif [ -d "$HOME/dotfiles" ]; then
    DOTFILES_DIR="$HOME/dotfiles"
    info "Using dotfiles directory: $DOTFILES_DIR"
else
    echo "Error: Dotfiles directory not found at $HOME/webdev/projects/codeberg/pixiekat/dotfiles"
    echo "Please clone your dotfiles repo there first, then re-run this script."
    exit 1
fi

# Do the same but set DOTFILES_PRIVATE_DIR to the dotfiles-private directory if it exists, else set it to empty string
if [ -d "$HOME/webdev/projects/codeberg/pixiekat/dotfiles-private" ]; then
    DOTFILES_PRIVATE_DIR="$HOME/webdev/projects/codeberg/pixiekat/dotfiles-private"
    info "Using dotfiles-private directory: $DOTFILES_PRIVATE_DIR"
elif [ -d "$HOME/dotfiles-private" ]; then
    DOTFILES_PRIVATE_DIR="$HOME/dotfiles-private"
    info "Using dotfiles-private directory: $DOTFILES_PRIVATE_DIR"
else
    info "Error: Dotfiles-private directory not found at $HOME/webdev/projects/codeberg/pixiekat/dotfiles-private"
    info "Continuing without dotfiles-private directory."
    DOTFILES_PRIVATE_DIR=""
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            IS_DRY_RUN="True"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Where to store backups of any pre-existing dotfiles that get replaced
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Set IS_DRY_RUN to "False" by default if not set by arguments
IS_DRY_RUN="${IS_DRY_RUN:-False}"

# List of dotfiles to symlink into $HOME
# Add or remove entries as your repo grows
DOTFILES=(
    .aliases
    .bash_logout
    .bashrc
    .cache/oh-my-posh/themes/iranian-solidarity.omp.json
    .claude/settings.json
    .config/btop/btop.conf
    .config/btop/themes/catppuccin/themes/catppuccin_frappe.theme
    .config/btop/themes/catppuccin/themes/catppuccin_latte.theme
    .config/btop/themes/catppuccin/themes/catppuccin_macchiato.theme
    .config/btop/themes/catppuccin/themes/catppuccin_mocha.theme
    .config/btop/themes/eldritch-theme/eldritch.theme
    .config/btop/themes/rose-pine/rose-pine-dawn.theme
    .config/btop/themes/rose-pine/rose-pine-moon.theme
    .config/btop/themes/rose-pine/rose-pine.theme
    .config/Code\ -\ Insiders/User/settings.json
    .config/composer/config.json
    .config/composer/composer.json
    .config/hyfetch.json
    .config/zsh/profiles/shared.zsh
    .config/zsh/profiles/personal.zsh
    .config/zsh/profiles/work.zsh
    .config/zsh/profiles/default.zsh
    .functions
    .gitconfig
    .inputrc
    .local/bin/split-show.sh
    .local/bin/backup-databases.sh
    .local/bin/backup-immich.sh
    .local/bin/export-manual-bans.sh
    .local/bin/backup-home-to-storagebox.sh
    .local/bin/toggle-camera.sh
    .local/bin/toggle-rustdesk.sh
    .local/bin/git-check-large-files.sh
    .local/share/konsole/Katy.profile
    .local/share/konsole/Katherine.profile
    .local/share/konsole/CampbellPowershell.colorscheme
    .local/share/konsole/Catppuccin-Frappe.colorscheme
    .local/share/konsole/CelebiPMD.colorscheme
    .local/share/konsole/GNOME.colorscheme
    .local/share/konsole/PurPurNight-Konsole.colorscheme
    .nanorc
    .oh-my-zsh/custom/plugins/you-should-use/you-should-use.plugin.zsh
    .oh-my-zsh/custom/plugins/you-should-use/zsh-you-should-use.plugin.zsh
    .profile
    .var/app/org.kde.dolphin/config/dolphinrc
    .var/app/org.kde.dolphin/config/kservicemenurc
    .var/app/org.kde.dolphin/data/kio/servicemenus/open-as-root.desktop
    .var/app/org.kde.dolphin/data/servicemenu-download/open-as-root.desktop
    .vimrc
    .zprofile
    .zshrc
)

# ---------------------------------------------------------------------------


# -- Preflight checks -------------------------------------------------------

# Make sure the dotfiles directory actually exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
    error "Dotfiles directory not found: $DOTFILES_DIR"
    error "Clone your repo there first, then re-run this script."
    exit 1
fi

# Create the backup directory (only if we'll actually need it).
# A dry run must not touch the filesystem, otherwise every --dry-run leaves an
# empty timestamped directory behind in ~/.dotfiles_backup/
if [[ "$IS_DRY_RUN" == "True" ]]; then
    info "[DRY RUN] Would create backup directory: $BACKUP_DIR"
else
    mkdir -p "$BACKUP_DIR"
    info "Backup directory: $BACKUP_DIR"
fi

if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    warn ".gitconfig.local not found — copy .gitconfig.local.example and fill in your details!"
fi

# ---------------------------------------------------------------------------


# -- Main installation loop -------------------------------------------------

# we set a DOTFILES_PRIVATE_DIR variable to the dotfiles-private directory if it exists, else set it to empty string
if [[ -n "$DOTFILES_PRIVATE_DIR" ]]; then
    info "Found dotfiles-private directory, including those files in the installation process."
    info "Using dotfiles-private directory: $DOTFILES_PRIVATE_DIR"

    DOTFILES+=(
        .gitconfig.local
        .claude/CLAUDE.md
        .claude/settings.local.json
        .ssh/config.d/personal
        .ssh/config.d/work
    )
fi

for file in "${DOTFILES[@]}"; do
    src="$DOTFILES_DIR/$file"
    # src might be in the dotfiles-private directory, so we check if it exists there first
    # DOTFILES array, if its a private dir file, will have the full path to the private dir, so traverse to the private dir if it exists, else use the public dir
    #
    # We test -e OR -L, matching the "source not found" check further down.
    # -e follows a symlink and reports false for a *broken* one, so testing -e
    # alone would silently fall back to the public copy instead of warning us
    # about a dangling link in dotfiles-private.
    priv_src="$DOTFILES_PRIVATE_DIR/$file"
    if [[ -n "$DOTFILES_PRIVATE_DIR" && ( -e "$priv_src" || -L "$priv_src" ) ]]; then
        src="$priv_src"
    fi

    dest="$HOME/$file"

    # Skip if the source file doesn't exist in the repo
    if [[ ! -e "$src" && ! -L "$src" ]]; then
        if [[ "$IS_DRY_RUN" == "True" ]]; then
            info "[DRY RUN] Would skip missing source: $src"
        else
            warn "Source not found in repo, skipping: $file"
        fi
        continue
    fi

    # ------------------------------------------------------------------
    # Already-linked check: done EARLY, before anything touches $dest.
    # We only record the answer here; the per-file hooks below still need
    # to run (ssh perms, nano dirs), so we can't 'continue' yet.
    # readlink -f resolves both sides to absolute real paths so they compare cleanly.
    # ------------------------------------------------------------------
    already_linked="False"
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        already_linked="True"
    fi

    # If something already exists at the destination, back it up
    if [[ "$already_linked" == "False" && ( -e "$dest" || -L "$dest" ) ]]; then
        if [[ "$IS_DRY_RUN" == "True" ]]; then
            info "[DRY RUN] Would back up existing: $dest to $BACKUP_DIR/$file"
        else
            info "Backing up existing: $dest"
        fi

        # dirname strips the filename, leaving just the directory path.
        # e.g. $BACKUP_DIR/.local/bin/toggle-camera.sh -> $BACKUP_DIR/.local/bin
        backup_dest_dir="$(dirname "$BACKUP_DIR/$file")"

        # Create that subdirectory tree if it doesn't already exist.
        # -p means "create parents as needed, no error if already exists"
        if [[ ! -d "$backup_dest_dir" ]]; then
            if [[ "$IS_DRY_RUN" == "True" ]]; then
                info "[DRY RUN] Would create backup subdir: $backup_dest_dir"
            else
                mkdir -p "$backup_dest_dir"
                info "Created backup subdir: $backup_dest_dir"
            fi
        fi

        if [[ "$IS_DRY_RUN" == "True" ]]; then
            info "[DRY RUN] Would back up $dest to $BACKUP_DIR/$file"
        else
            mv "$dest" "$BACKUP_DIR/$file"
            success "Backed up: $dest"
        fi
    fi

    # ---------------------------------------------------------------------------
    # -- Shell script detection -------------------------------------------------
    # Check 1: Does the filename end in .sh?
    # Check 2: Does the first line contain a shell shebang? (#!/bin/bash, #!/usr/bin/env bash, etc.)
    # 'head -n 1' reads only the first line — no need to load the whole file.
    # The regex [[ "$src" == *.sh ]] matches the file extension.
    # grep -qE does a quiet (-q) extended regex (-E) match — exits 0 if found.
    first_line="$(head -n 1 "$src" 2>/dev/null)"

    # ------------------------------------------------------------------
    # Per-file hooks: extra setup specific files need.
    # case runs the FIRST pattern that matches and then stops, so each
    # file gets at most one of these sections.
    # ------------------------------------------------------------------
    case "$src" in

        # btop themes: one pattern replaces the two-part && check.
        # * matches across slashes in case patterns, so this means
        # "anything, then btop/themes/, then anything ending in .theme"
        *btop/themes/*.theme)
            theme_name="$(basename "$src")"
            theme_dest="$HOME/.config/btop/themes/$theme_name"
            if [[ "$IS_DRY_RUN" == "True" ]]; then
                info "[DRY RUN] Would link btop theme: $theme_dest -> $src"
            else
                mkdir -p "$HOME/.config/btop/themes"
                ln -sf "$src" "$theme_dest"
                success "Linked btop theme: $theme_dest -> $src"
            fi
            continue    # still skips to the next file in the loop
            ;;

        # nano: make sure the cache/backups directory exists
        *.nanorc)
            if [[ ! -d "$HOME/.cache/nano/backups" ]]; then
                if [[ "$IS_DRY_RUN" == "True" ]]; then
                    info "[DRY RUN] Would create nano cache/backups directory: $HOME/.cache/nano/backups"
                else
                    info "Creating nano cache/backups directory: $HOME/.cache/nano/backups"
                    mkdir -p "$HOME/.cache/nano/backups"
                fi
            fi
            ;;

        # ssh configs: lock down permissions.
        # ssh rejects group/world-writable configs, and Mint's umask (002)
        # plus git (which doesn't track modes) means a fresh clone is 664
        *.ssh/config*)
            if [[ "$IS_DRY_RUN" == "True" ]]; then
                info "[DRY RUN] Would chmod 600 $src and chmod 700 ~/.ssh and ~/.ssh/config.d"
            else
                info "Securing ssh permissions for: $src"
                # does ~/.ssh/config.d exist? if not, create it
                if [[ ! -d "$HOME/.ssh/config.d" ]]; then
                    info "Creating ~/.ssh/config.d directory"
                    mkdir -p "$HOME/.ssh/config.d"
                fi
                info "Setting permissions: chmod 700 ~/.ssh and ~/.ssh/config.d"
                chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"   # always enforce

                info "Setting permissions: chmod 600 $src"
                chmod 600 "$src"      # the real file in the repo, not the symlink
            fi
            ;;

    esac

    # ------------------------------------------------------------------
    # Executable check: stays outside the case because it looks at the
    # file's CONTENTS (the shebang), not just its name, and it can apply
    # to any file regardless of which hook above matched.
    # ------------------------------------------------------------------
    if [[ "$src" == *.sh || "$first_line" =~ ^\#!.*(bash|sh|zsh|ksh) ]]; then
        if [[ "$IS_DRY_RUN" == "True" ]]; then
            info "[DRY RUN] Would mark executable: $src"
        else
            if [[ ! -x "$src" ]]; then
                chmod u+x "$src"
                success "Marked executable: $src"
            else
                info "Already executable: $src"
            fi
        fi
    fi

    # Now it's safe to skip: hooks and perms have run, and the link is already correct
    if [[ "$already_linked" == "True" ]]; then
        info "Already linked, skipping: $dest"
        continue
    fi

    # Create the symlink
    # ensure directory exists for the destination
    if [[ "$IS_DRY_RUN" == "True" ]]; then
        info "[DRY RUN] Would symlink for: $dest"
    else
        mkdir -p "$(dirname "$dest")"
        ln -sf "$src" "$dest"
        success "Linked: $dest -> $src"
    fi

done

# ---------------------------------------------------------------------------


# -- KDE / Konsole post-config ----------------------------------------------
# konsolerc is NOT symlinked -- it mixes the one setting we want to share
# (DefaultProfile) with per-machine window geometry that would otherwise churn
# the repo on every window move. Instead, set just that one key surgically with
# KDE's own config writer, leaving each box's [MainWindow] state local.
KONSOLE_DEFAULT_PROFILE="Katy.profile"
kwriteconfig="$(command -v kwriteconfig6 || command -v kwriteconfig5)"

if [[ -n "$kwriteconfig" ]]; then
    if [[ "$IS_DRY_RUN" == "True" ]]; then
        info "[DRY RUN] Would set konsolerc DefaultProfile=$KONSOLE_DEFAULT_PROFILE via $(basename "$kwriteconfig")"
    else
        "$kwriteconfig" --file konsolerc --group "Desktop Entry" \
            --key DefaultProfile "$KONSOLE_DEFAULT_PROFILE"
        success "Set Konsole default profile: $KONSOLE_DEFAULT_PROFILE"
    fi
else
    warn "kwriteconfig6/5 not found -- skipping Konsole default-profile setup"
fi

# ---------------------------------------------------------------------------

# ------------------------------------------------------------------
# Post-run cleanup: remove this run's backup dir if nothing was backed up.
#
# find -mindepth 1 -print -quit prints the FIRST entry inside the dir and
# stops, so an empty result means the dir is empty (fast, no full listing).
# rmdir only ever removes EMPTY directories, so even if the check were
# wrong, real backups can't be deleted by this.
# ------------------------------------------------------------------
if [[ -d "$BACKUP_DIR" && -z "$(find "$BACKUP_DIR" -mindepth 1 -print -quit)" ]]; then
    if [[ "$IS_DRY_RUN" == "True" ]]; then
        info "[DRY RUN] Would remove empty backup dir: $BACKUP_DIR"
    else
        rmdir "$BACKUP_DIR"
        info "Nothing needed backing up; removed empty dir: $BACKUP_DIR"
    fi
else
    info "Backups are in: $BACKUP_DIR"
fi

# -- Done -------------------------------------------------------------------

echo ""

if [[ "$IS_DRY_RUN" == "True" ]]; then
    info "DRY RUN complete. No changes were made."
else
    info "Installation complete."
    # (backup location is reported by the cleanup step above)
    info "Review your shell with: source ~/.zshrc or source ~/.bashrc"
fi
echo ""
