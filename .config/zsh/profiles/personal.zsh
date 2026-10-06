# Like PHP's include_once
source "${0:A:h}/shared.zsh"
# ${0:A:h} = "the directory this file lives in" (absolute path, :h = head/dirname),
# so it works no matter where you run the shell from.

# hyfetch, if exists, aliases
if [ -x "$(command -v hyfetch)" ]; then
    alias blahajfetch='hyfetch -p transgender'
    alias hy-effable-husbands='hyfetch -p nonbinary'
    alias ineffable-husbands='hy-effable-husbands'
    alias hyclexa='hyfetch -p bisexual'
    alias clexa-forever='hyclexa'
    alias team-free-will='hyfetch -p queer'
    alias destiel-will-never-die='hyfetch -p omnisexual'
    alias baby-its-klaine-outside='hyfetch -p rainbow'
fi

###
# Jellyfin aliases & functions
###
if [ -x "$(command -v jellyfin)" ]; then

    # ── Database backup ─────────────────────────────────────────────
    # Usage: jellyfin-backup-db [label]
    #   jellyfin-backup-db              -> jellyfin-db-20261006-1432.db
    #   jellyfin-backup-db GOOD-511eps  -> jellyfin-db-GOOD-511eps-20261006-1432.db
    #
    # Uses sqlite3's .backup command, which takes a consistent snapshot
    # even while Jellyfin is running (it understands WAL; plain cp doesn't).
    # Needs: sudo apt install sqlite3
    if [ -d /mnt/storage/katy ]; then
        # Where Jellyfin DB backups live; change it here and everything follows
        typeset -g JELLYFIN_BACKUP_DIR="/mnt/storage/katy"

        jellyfin-backup-db() {
            local db="/var/lib/jellyfin/data/jellyfin.db"
            local stamp="$(date +%Y%m%d-%H%M)"

            # ${1:+$1-} means: "if $1 is set and non-empty, insert '$1-', else nothing"
            local dest="$JELLYFIN_BACKUP_DIR/jellyfin-db-${1:+$1-}${stamp}.db"

            sudo sqlite3 "$db" ".backup '$dest'" \
                && echo "Backed up to $dest" \
                || echo "Backup failed :(" >&2
        }

        # just open up the backup folder
        alias jellyfin-open-backups='xdg-open /mnt/storage/katy'

        # List backups, newest first, with human-readable sizes
        alias jellyfin-list-backups='ls -lht "$JELLYFIN_BACKUP_DIR"/jellyfin-db-*.db'
    fi

    # ── Logs ────────────────────────────────────────────────────────
    if [ -d /var/log/jellyfin ]; then
        # Open the logs folder in your file manager (Dolphin, on KDE)
        alias jellyfin-open-logs='xdg-open /var/log/jellyfin'

        # Follow the newest log; -F keeps following across rotation
        alias jellyfin-tail-logs='tail -F "$(ls -t /var/log/jellyfin/*.log | head -n 1)"'
    fi

    # ── Service control ─────────────────────────────────────────────
    if service_exists jellyfin; then
        alias jellyfin-start='sudo systemctl start jellyfin'
        alias jellyfin-stop='sudo systemctl stop jellyfin'
        alias jellyfin-restart='sudo systemctl restart jellyfin'
        alias jellyfin-status='systemctl status jellyfin'   # read-only, no sudo needed

        # Bonus: systemd's own view (startup crashes show up here
        # even when Jellyfin dies before writing its own log)
        alias jellyfin-journal='journalctl -u jellyfin -f'
    fi

fi

# does docker exist with a container named 'ersatztv'?
if [ -x "$(command -v docker)" ] \
    && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^ersatztv$'; then
    typeset -g ERSATZTV_DOCKER_CONTAINER_NAME="ersatztv"
    typeset -g ERSATZTV_DOCKER_FOLDER="$HOME/webdev/projects/docker/ersatztv"

    # tail the logs for the past 3 minutes
    alias ersatztv-tail-logs='docker logs -f --since 3m "$ERSATZTV_DOCKER_CONTAINER_NAME" 2>&1'

    # Restart the whole compose stack: down, then up -d
    ersatztv-ups-and-downs() {
        # The ( ) runs this in a SUBSHELL: the cd happens in a child process,
        # so your terminal never leaves the directory you were in. No need
        # to save and restore $PWD by hand.
        (
            cd "$ERSATZTV_DOCKER_FOLDER" || exit 1
            docker compose down && docker compose up -d
        ) || { echo "Something went wrong :(" >&2; return 1; }

        echo "Done! Run 'ersatztv-tail-logs' to watch it come up."
    }

    # bash into the ersatztv container (for debugging, etc)
    alias ersatztv-bash='docker exec -it "$ERSATZTV_DOCKER_CONTAINER_NAME" sh -c "command -v bash >/dev/null && exec bash || exec sh"'

    # open the docker folder
    alias ersatztv-open-folder='xdg-open "$ERSATZTV_DOCKER_FOLDER"'

    # edit the docker-compose.yml file
    alias ersatztv-edit-compose='${EDITOR:-nano} "$ERSATZTV_DOCKER_FOLDER/docker-compose.yml"'
fi

# Note: package-manager judgement moved to default.zsh so every profile
# (work included >:3) gets roasted, not just this one.
