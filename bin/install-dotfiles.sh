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

# -- Configuration ----------------------------------------------------------

# Use webdev/projects/codeberg/pixiekat/dotfiles as the source of truth for where the dotfiles are located.
# else check to see $HOME/dotfiles else fail with an error message asking the user to clone their dotfiles
# repo to one of those locations.
if [ -d "$HOME/webdev/projects/codeberg/pixiekat/dotfiles" ]; then
    DOTFILES_DIR="$HOME/webdev/projects/codeberg/pixiekat/dotfiles"
elif [ -d "$HOME/dotfiles" ]; then
    DOTFILES_DIR="$HOME/dotfiles"
else
    echo "Error: Dotfiles directory not found at $HOME/webdev/projects/codeberg/pixiekat/dotfiles"
    echo "Please clone your dotfiles repo there first, then re-run this script."
    exit 1
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
    .config/zsh/profiles/personal.zsh
    .config/zsh/profiles/work.zsh
    .config/zsh/profiles/default.zsh
    .functions
    .gitconfig
    .inputrc
    .local/bin/backup-databases.sh
    .local/bin/backup-immich.sh
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
    .oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
    .oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    .oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
    .oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
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


# -- Helpers ----------------------------------------------------------------

# Print a status message
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }

# ---------------------------------------------------------------------------


# -- Preflight checks -------------------------------------------------------

# Make sure the dotfiles directory actually exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
    error "Dotfiles directory not found: $DOTFILES_DIR"
    error "Clone your repo there first, then re-run this script."
    exit 1
fi

# Create the backup directory (only if we'll actually need it)
mkdir -p "$BACKUP_DIR"
info "Backup directory: $BACKUP_DIR"

if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    warn ".gitconfig.local not found — copy .gitconfig.local.example and fill in your details!"
fi

# ---------------------------------------------------------------------------


# -- Main installation loop -------------------------------------------------

# if there is a dotfiles-private directory onelevel up from the dotfiles directory, then we should also look for files in there and link them as well
# this allows us to keep sensitive files like .gitconfig.local out of the main repo, while still having them installed by this script
if [[ -d "$DOTFILES_DIR/../dotfiles-private" ]]; then
    info "Found dotfiles-private directory, including those files in the installation process."
    # we can use the same DOTFILES array since the paths will be relative to the main dotfiles directory, so .gitconfig.local will be in the list and we'll just need to check for it in both places when we go to link it
    DOTFILES+=(
        ../dotfiles-private/.gitconfig.local
        ../dotfiles-private/.claude/CLAUDE.md
    )
fi

for file in "${DOTFILES[@]}"; do
    src="$DOTFILES_DIR/$file"
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

    # If something already exists at the destination, back it up
    if [[ -e "$dest" || -L "$dest" ]]; then
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

    if [[ "$src" == *"btop/themes"* && "$src" == *".theme" ]]; then
        if [[ "$IS_DRY_RUN" == "True" ]]; then
            info "[DRY RUN] Would link btop theme: $dest -> $HOME/.config/btop/themes/$(basename $src)"
        else
            mkdir -p "$HOME/.config/btop/themes"
            ln -sf "$src" "$HOME/.config/btop/themes/$(basename $src)"
            success "Linked btop theme: $dest -> $HOME/.config/btop/themes/$(basename $src)"
        fi
        continue
    fi

    if [[ "$src" == *.sh ]] || echo "$first_line" | grep -qE '^#!(.*)(bash|sh|zsh|ksh)'; then
        if [[ "$IS_DRY_RUN" == "True" ]]; then
            info "[DRY RUN] Would mark executable: $src"
        else
            chmod u+x "$src"
            success "Marked executable: $src"
        fi
    fi

    # if $src is .nanorc, make sure the cache directory exists for it to store its compiled version
    if [[ "$src" == *".nanorc" ]]; then
        if [[ ! -d "$HOME/.cache/nano/backups" ]]; then
            if [[ "$IS_DRY_RUN" == "True" ]]; then
                info "[DRY RUN] Would create nano cache/backups directory: $HOME/.cache/nano/backups"
            else
                info "Creating nano cache/backups directory: $HOME/.cache/nano/backups"
                mkdir -p "$HOME/.cache/nano/backups"
            fi
        fi
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


# -- Done -------------------------------------------------------------------

echo ""

if [[ "$IS_DRY_RUN" == "True" ]]; then
    info "DRY RUN complete. No changes were made."
else
    info "Installation complete."
    info "Backups (if any) are in: $BACKUP_DIR"
    info "Review your shell with: source ~/.zshrc or source ~/.bashrc"
fi
echo ""
