#!/bin/bash
# backup-immich.sh
# Rsyncs Immich's own nightly Postgres dumps to the Hetzner Storagebox.
# Immich writes the dumps itself (Admin > Database Dump Settings, 2am);
# this script's ONLY job is to carry them offsite.

# Where Immich writes its dumps (the source we're backing up FROM)
IMMICH_BACKUP_DIR="/mnt/HC_Volume_105148208/immich-app/uploads/backups"
RSYNC_DESTINATION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --immich-backup-dir)
            IMMICH_BACKUP_DIR="$2"
            shift 2
            ;;
        --rsync-destination)
            RSYNC_DESTINATION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--immich-backup-dir DIR] [--rsync-destination DEST]"
            echo "  --immich-backup-dir DIR   Where Immich writes its dumps (default: $IMMICH_BACKUP_DIR)"
            echo "  --rsync-destination DEST  Storagebox destination for offsite copies"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Sanity: the source dir must exist and be READABLE (we read from it, not write to it)
if [[ ! -d "$IMMICH_BACKUP_DIR" ]]; then
    echo "Error: Immich backup dir $IMMICH_BACKUP_DIR does not exist."
    exit 1
fi
if [[ ! -r "$IMMICH_BACKUP_DIR" ]]; then
    echo "Error: Immich backup dir $IMMICH_BACKUP_DIR is not readable."
    exit 1
fi

# Carry the dumps offsite.
if [[ -n "$RSYNC_DESTINATION" ]]; then
    rsync -avz --delete -e "ssh -p 23" "$IMMICH_BACKUP_DIR/" "$RSYNC_DESTINATION/" || {
        echo "Error: Immich rsync failed!"
        exit 1
    }
else
    echo "Warning: no --rsync-destination given; nothing sent offsite."
fi
