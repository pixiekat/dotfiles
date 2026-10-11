# vs code aliases, if code exists

# first check if we have code-insiders and alias it to code, if code doesn't exist.
if [ -x "$(command -v code-insiders)" ] && [ ! -x "$(command -v code)" ]; then
    alias code='code-insiders'
fi

# check to see if code is executable or if it's alised (in the case of code-insiders) before adding the rest of the aliases
if which code &>/dev/null || which code-insiders &>/dev/null; then
    export EDITOR='code'
    alias code-remote='code --remote ssh-remote+pixiekat'

    # open current directory in code
    alias open-in-vscode='code $(pwd) 2>/dev/null &'
fi

# sublime text aliases, if subl exists
if [ -x "$(command -v subl)" ]; then
    alias open-in-sublime='subl $(pwd) 2>/dev/null &'
fi

# Git Cola aliases
if [ -x "$(command -v flatpak)" ]; then
    if flatpak list --app | grep -q "git.cola" 2>/dev/null; then
        alias git-cola='flatpak run com.github.git_cola.git-cola cola 2>/dev/null'
        alias open-in-git-cola='flatpak run com.github.git_cola.git-cola cola --repo "$(pwd)" 2>/dev/null &'
    fi

    # get list of all installed flatpaks.
    # deprecated, use flatpak-list-installed
    alias list-flatpaks='flatpak list --app'
    alias flatpak-list-installed='flatpak list --app'

    # get outdated flatpaks
    alias flatpak-outdated='flatpak remote-ls --updates'
else
    # if flatpak doesn't exist, check if git-cola exists and add alias
    if [ -x "$(command -v git-cola)" ]; then
        alias git-cola='git-cola 2>/dev/null'
        alias open-in-git-cola='git-cola --repo "$(pwd)" 2>/dev/null &'
    fi
fi

if [ -x "$(command -v php)" ]; then
    alias pixiekat-switch-php='sudo update-alternatives --config php'
fi

# does composer exist? if so, add some aliases
if [ -x "$(command -v composer)" ]; then
    #does php 8.2 exist? if so, add some aliases
    if [ -x "$(command -v php8.2)" ]; then
        alias composer82='php8.2 /usr/local/bin/composer'
        if [ -x "$(command -v acli)" ]; then
            alias acli82='/usr/bin/php8.2 /usr/local/bin/acli'
        fi
    fi
    #does php 8.3 exist? if so, add some aliases
    if [ -x "$(command -v php8.3)" ]; then
        alias composer83='php8.3 /usr/local/bin/composer'
        if [ -x "$(command -v acli)" ]; then
            alias acli83='/usr/bin/php8.3 /usr/local/bin/acli'
        fi
    fi
    #does php 8.4 exist? if so, add some aliases
    if [ -x "$(command -v php8.4)" ]; then
        alias composer84='php8.4 /usr/local/bin/composer'
        if [ -x "$(command -v acli)" ]; then
            alias acli84='/usr/bin/php8.4 /usr/local/bin/acli'
        fi
    fi
    #does php 8.5 exist? if so, add some aliases
    if [ -x "$(command -v php8.5)" ]; then
        alias composer85='php8.5 /usr/local/bin/composer'
        if [ -x "$(command -v acli)" ]; then
            alias acli85='/usr/bin/php8.5 /usr/local/bin/acli'
        fi
    fi
fi

# does docker exist?
if [ -x "$(command -v docker)" ]; then
    # use docker ps -a --filter "name=ollama" to determine if ollama container is running
    if [ -n "$(docker ps -a --filter "name=ollama" --format '{{.Names}}')" ]; then
        alias ollama-ls='docker exec -it ollama ollama ls'
        alias ollama-run='docker exec -it ollama ollama run'
    fi

    alias pixiekat-docker-ps='docker ps'
    alias pixiekat-docker-compose-dev="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
    alias pixiekat-dcdev='pixiekat-docker-compose-dev'
fi

alias restart-apache='sudo systemctl reload apache2'
alias restart-php='sudo systemctl reload php8.3-fpm'

alias start-apache='sudo systemctl start apache2'
alias start-php='sudo systemctl start php8.3-fpm'

alias status-apache='sudo systemctl status apache2'
alias status-php='sudo systemctl status php8.3-fpm'

alias stop-apache='sudo systemctl stop apache2'
alias stop-php='sudo systemctl stop php8.3-fpm'

# this should exist but we still want to check
if [ -f /etc/hosts ]; then
    alias pixiekat-edit-hosts='sudo nano /etc/hosts'
fi

# ------------------------------------------------------------------
# launch-delinea: SSH into the Delinea jump host and run "launch <id>"
#
# Usage:   launch-delinea 11326
#
# $1 = the first argument passed to the function (the target ID)
# ------------------------------------------------------------------
launch-delinea() {
    # Guard clause: bail out with a friendly message if no ID was given.
    # -z tests whether a string is empty. >&2 sends the message to stderr.
    if [[ -z "$1" ]]; then
        echo "usage: launch-delinea <id>" >&2
        return 1   # non-zero = failure, so scripts/&& chains know it failed
    fi

    # delinea is found in ~/.ssh/config.d/work; see dotfiles-private/.ssh/config.d/work for details.
    ssh delinea "launch $1"
}

# --- ModSecurity audit log helpers ------------------------------------------
if [ -f "/var/log/apache2/modsec/modsec_audit.log" ]; then
    _MODSEC_AUDIT_LOG="/var/log/apache2/modsec/modsec_audit.log"
elif [ -f "/var/log/apache2/modsec_audit.log" ]; then
    _MODSEC_AUDIT_LOG="/var/log/apache2/modsec_audit.log"
else
    _MODSEC_AUDIT_LOG=""
fi
#_MODSEC_AUDIT_LOG="/var/log/apache2/modsec/modsec_audit.log"

# Only define these on machines that actually have the audit log.
if [[ -f "$_MODSEC_AUDIT_LOG" ]]; then

    # Internal helper: print every complete audit entry for one client IP,
    # across the current log AND rotated copies (.1, .2.gz, ...).
    # zcat -f decompresses .gz files and passes plain files through unchanged.
    # Rotated files are read oldest-first, so output stays in time order.
    _modsec-entries-for-ip() {
        # List old- and new-location logs, oldest first.
        # awk '!seen[$0]++' drops repeats while keeping order, because on
        # servers still using the old path, both globs match the SAME files.
        sudo bash -c 'zcat -f $(ls -1tr /var/log/apache2/modsec_audit.log* '"$_MODSEC_AUDIT_LOG"'* 2>/dev/null | awk '"'"'!seen[$0]++'"'"')' \
        | awk -v ip="$1" '
            /^--[0-9a-f]+-A--$/ { keep = 0; expect_a = 1; boundary = $0; next }
            expect_a            { expect_a = 0; if ($4 == ip) { keep = 1; print boundary } }
            keep                { print }
        '
    }

    # What did a given IP request?
    modsec-requests-by-ip() {
        local ip="$1"
        if [[ -z "$ip" ]]; then
            echo "usage: modsec-requests-by-ip <ip>" >&2
            return 1
        fi
        # Request lines look like "GET /path HTTP/2.0". Matching any
        # uppercase method keeps PATCH, CONNECT, PROPFIND, etc. too.
        _modsec-entries-for-ip "$ip" | grep -E '^[A-Z]+ [^ ]+ HTTP/[0-9.]+$'
    }

    # Which rules did a given IP trip, most frequent first?
    modsec-rules-by-ip() {
        local ip="$1"
        if [[ -z "$ip" ]]; then
            echo "usage: modsec-rules-by-ip <ip>" >&2
            return 1
        fi
        # Rule IDs appear in the H section as [id "920210"].
        # \K drops the [id " prefix so only the number is printed.
        _modsec-entries-for-ip "$ip" | grep '^Message:' | grep -oP '\[id "\K\d+' | sort | uniq -c | sort -rn
    }
fi
