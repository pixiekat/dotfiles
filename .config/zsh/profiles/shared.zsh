###
# Shared helper functions
# Sourced once; safe to `source` from multiple files.
###

# ── Include-once guard ──────────────────────────────────────────────
# If we've already been loaded, stop here. `return` inside a sourced
# file exits just that file, not your whole shell.
[[ -n $_SHARED_ZSH_LOADED ]] && return
typeset -g _SHARED_ZSH_LOADED=1   # -g = global, even if sourced from inside a function

# ── service_exists <name> ───────────────────────────────────────────
# Returns 0 if a systemd service with that name exists, 1 otherwise.
# Usage: if service_exists jellyfin; then ...; fi
service_exists() {
    local n=$1
    [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" \
        | sed 's/^\s*//g' | cut -f1 -d' ') == "$n.service" ]]
    # The [[ ]] test's own exit status (0 or 1) becomes the function's
    # return value, so the if/return 0/else/return 1 isn't needed.
}
