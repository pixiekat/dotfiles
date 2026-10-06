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
# Jellyfin aliases
###
if [ -x "$(command -v jellyfin)" ]; then

    # Backup the database
    if [ -d /mnt/storage/katy ]; then
        alias jellyfin-backup-db='sudo cp -p /var/lib/jellyfin/data/jellyfin.db /mnt/storage/katy/jellyfin-db-GOOD-511eps-$(date +%Y%m%d-%H%M).db'
    fi

    # Open the logs directory
    if [ -d /var/log/jellyfin ]; then
        alias jellyfin-open-logs='xdg-open /var/log/jellyfin'
    fi

    # Tail the most recent log file
    if [ -d /var/log/jellyfin ]; then
        alias jellyfin-tail-logs='tail -f $(ls -t /var/log/jellyfin/jellyfin*.log | head -n 1)'
    fi

    # Start, stop, and restart the Jellyfin service
    if service_exists jellyfin; then
        alias jellyfin-start='sudo systemctl start jellyfin'
        alias jellyfin-stop='sudo systemctl stop jellyfin'
        alias jellyfin-restart='sudo systemctl restart jellyfin'
        alias jellyfin-status='sudo systemctl status jellyfin'
    fi

fi

# Note: package-manager judgement moved to default.zsh so every profile
# (work included >:3) gets roasted, not just this one.
