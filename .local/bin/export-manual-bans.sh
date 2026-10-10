#!/usr/bin/env bash
# =============================================================================
# export-manual-bans.sh
# Saves every IP/CIDR in fail2ban's "manual" jail to a plain-text list,
# so permanent bans can be restored after a rebuild (see the restore loop).
# =============================================================================
set -euo pipefail

OUTFILE="$HOME/dotfiles-private/fail2ban/manual-bans.txt"
mkdir -p "$(dirname "$OUTFILE")"

# "get <jail> banip" prints the jail's bans as one space-separated line.
# tr turns spaces into newlines so each ban gets its own line.
CURRENT="$(sudo fail2ban-client get manual banip | tr ' ' '\n')"

# Merge with any existing list instead of overwriting it, so a ban that
# was manually unbanned here is still kept in the file until you remove it.
# grep -v drops comment and blank lines from the old file before merging.
{
    echo "# fail2ban manual jail, exported $(date '+%Y-%m-%d %H:%M')"
    echo "# One IP or CIDR per line. Restore with the manual-bans restore loop."
    {
        echo "$CURRENT"
        [[ -f "$OUTFILE" ]] && grep -Ev '^[[:space:]]*(#|$)' "$OUTFILE"
    } | grep -Ev '^[[:space:]]*$' | sort -uV     # -u dedupe, -V natural IP order
} > "$OUTFILE.tmp"

# Write to a temp file first, then move it into place: if anything above
# fails, the old list is left untouched instead of half-written.
mv "$OUTFILE.tmp" "$OUTFILE"

echo "Saved $(grep -cEv '^[[:space:]]*(#|$)' "$OUTFILE") bans to $OUTFILE"
