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

# Absolute path to your cloned dotfiles repository
DOTFILES_DIR="$HOME/webdev/projects/codeberg/pixiekat/dotfiles"

# Where to store backups of any pre-existing dotfiles that get replaced
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# List of dotfiles to symlink into $HOME
# Add or remove entries as your repo grows
DOTFILES=(
    .config/Code\ -\ Insiders/User/settings.json
    .aliases
    .bashrc
    .bash_aliases
    .bash_profile
    .inputrc
    .vimrc
    .gitconfig
    .gitignore_global
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
        mv "$dest" "$BACKUP_DIR/$file"
    fi

    # Create the symlink
    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"

done

# ---------------------------------------------------------------------------


# -- Done -------------------------------------------------------------------

echo ""
info "Installation complete."
info "Backups (if any) are in: $BACKUP_DIR"
echo ""
echo "Review your shell with: source ~/.bashrc"
