# ~/dotfiles/bin/pixiekat-dotfiles-restore-firefox-policies
#
# Nightly's updater rewrites /lib/firefox-nightly/distribution/ on update,
# which removes our policies symlink. Re-create it after an update.
#
# Requires sudo for the symlink itself; the target stays user-owned so the
# policy file can be edited (and version-controlled) without root.

#set -euo pipefail

DOTFILES_POLICY="$HOME/webdev/projects/codeberg/pixiekat/dotfiles/firefox/policies.json"
NIGHTLY_DIST="/lib/firefox-nightly/distribution"
TARGET="$NIGHTLY_DIST/policies.json"

# Fail early with a clear message rather than creating a dangling link
if [ ! -f "$DOTFILES_POLICY" ]; then
    echo "ERROR: $DOTFILES_POLICY not found" >&2
    exit 1
fi

if [ ! -d "$NIGHTLY_DIST" ]; then
    echo "ERROR: $NIGHTLY_DIST missing — is Nightly installed at /lib?" >&2
    exit 1
fi

# -f replaces an existing link or file; -n avoids following an existing
# symlink-to-directory (a classic ln footgun)
sudo ln -sfn "$DOTFILES_POLICY" "$TARGET"

echo "Linked $TARGET -> $DOTFILES_POLICY"
echo "Restart Nightly, then check about:policies to confirm."
