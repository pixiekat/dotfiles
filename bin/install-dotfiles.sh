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

# Where to store backups of any pre-existing dotfiles that get replaced
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

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
    .functions
    .gitconfig
    .gitignore_global
    .inputrc
    .local/bin/backup-home-to-storagebox.sh
    .local/bin/toggle-camera.sh
    .nanorc
    .oh-my-zsh/custom/plugins/you-should-use/you-should-use.plugin.zsh
    .oh-my-zsh/custom/plugins/you-should-use/zsh-you-should-use.plugin.zsh
    .oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
    .oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    .oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
    .oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
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

# ---------------------------------------------------------------------------


# -- Main installation loop -------------------------------------------------

for file in "${DOTFILES[@]}"; do
    src="$DOTFILES_DIR/$file"
    dest="$HOME/$file"

    # Skip if the source file doesn't exist in the repo
    if [[ ! -f "$src" ]]; then
    warn "Source not found in repo, skipping: $file"
    continue
    fi

    # If something already exists at the destination, back it up
    if [[ -e "$dest" || -L "$dest" ]]; then
    info "Backing up existing: $dest"

    # dirname strips the filename, leaving just the directory path.
    # e.g. $BACKUP_DIR/.local/bin/toggle-camera.sh -> $BACKUP_DIR/.local/bin
    backup_dest_dir="$(dirname "$BACKUP_DIR/$file")"

    # Create that subdirectory tree if it doesn't already exist.
    # -p means "create parents as needed, no error if already exists"
    if [[ ! -d "$backup_dest_dir" ]]; then
        mkdir -p "$backup_dest_dir"
        info "Created backup subdir: $backup_dest_dir"
    fi

    mv "$dest" "$BACKUP_DIR/$file"
    success "Backed up: $dest"
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
        mkdir -p "$HOME/.config/btop/themes"
        ln -sf "$src" "$HOME/.config/btop/themes/$(basename $src)"
        success "Linked btop theme: $dest -> $HOME/.config/btop/themes/$(basename $src)"
        continue
    fi

    if [[ "$src" == *.sh ]] || echo "$first_line" | grep -qE '^#!(.*)(bash|sh|zsh|ksh)'; then
        chmod u+x "$src"
        success "Marked executable: $src"
    fi

    # if $src is .nanorc, make sure the cache directory exists for it to store its compiled version
    if [[ "$src" == *".nanorc" ]]; then
        if [[ ! -d "$HOME/.cache/nano/backups" ]]; then
            info "Creating nano cache/backups directory: $HOME/.cache/nano/backups"
            mkdir -p "$HOME/.cache/nano/backups"
        fi
    fi

    # Create the symlink
    # ensure directory exists for the destination
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"

done

# ---------------------------------------------------------------------------


# -- Done -------------------------------------------------------------------

echo ""
info "Installation complete."
info "Backups (if any) are in: $BACKUP_DIR"
echo ""

info "Review your shell with: source ~/.zshrc or source ~/.bashrc"
