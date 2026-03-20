#!/bin/bash
# backup-dbs.sh
# Dumps all MariaDB databases and rsyncs to Storagebox

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --date-format)
            DATE_FORMAT="$2"
            shift 2
            ;;
        --database-user)
            DATABASE_USER="$2"
            shift 2
            ;;
        --database-password)
            DATABASE_PASSWORD="$2"
            shift 2
            ;;
        --days-to-keep)
            DAYS_TO_KEEP="$2"
            shift 2
            ;;
        --rsync-destination)
            RSYNC_DESTINATION="$2"
            shift 2
            ;;

        --help|-h)
            echo "Usage: $0 [--backup-dir BACKUP_DIR] [--date-format DATE_FORMAT] [--database-user DATABASE_USER] [--database-password DATABASE_PASSWORD] [--days-to-keep DAYS_TO_KEEP] [--rsync-destination RSYNC_DESTINATION]"
            echo "  --backup-dir BACKUP_DIR     Path where backups will be stored (default: $HOME/backup/sql)"
            echo "  --date-format DATE_FORMAT   Date format for backup files (default: %Y%m%d_%H%M%S)"
            echo "  --database-user DATABASE_USER User to connect to MariaDB (default: $USER)"
            echo "  --database-password DATABASE_PASSWORD Password for MariaDB user (default: empty)"
            echo "  --days-to-keep DAYS_TO_KEEP Number of days to keep backups (default: 7)"
            echo "  --rsync-destination RSYNC_DESTINATION Destination for rsyncing backups (default: none)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

DATABASE_USER="${DATABASE_USER:-}"
DATABASE_PASSWORD="${DATABASE_PASSWORD:-}"
DATE_FORMAT=${DATE_FORMAT:-%Y%m%d_%H%M%S}
DATE=$(date +"$DATE_FORMAT")
DAYS_TO_KEEP=${DAYS_TO_KEEP:-7}
BACKUP_DIR=${BACKUP_DIR:-$HOME/backup/sql}
RSYNC_DESTINATION=${RSYNC_DESTINATION:-}

#STORAGEBOX="u123456@u123456.your-storagebox.de"

# DATABASE_USER is the only "required"; if there's no $HOME/.my.cnf. Fail with message.
if [[ -z "$DATABASE_USER" && ! -f "$HOME/.my.cnf" ]]; then
    echo "Error: No database credentials found. Please either:"
    echo "  - Create $HOME/.my.cnf with your MariaDB credentials, or"
    echo "  - Pass --database-user (leave --database-password empty to be prompted securely)"
    exit 1
fi

# If $HOME/.my.cnf doesn't exist, just warn and give the user a chance to add it before running for more secure and convenient backups (no password in process list or script)
if [[ ! -f "$HOME/.my.cnf" ]]; then
    echo "Warning: $HOME/.my.cnf not found. Recommended contents:"
    cat <<EOF
[client]
user=$USER
password=yourpassword
socket=/var/run/mysqld/mysqld.sock
EOF
    echo "You can also use --database-user and --database-password flags, but be aware this may expose credentials in the process list."
    echo "Proceeding anyway..."
fi

# Checks to see if backup directory is writable; if not, exits with an error
if [ -d "$BACKUP_DIR" ]; then
    if [ ! -w "$BACKUP_DIR" ]; then
        echo "Error: Backup directory $BACKUP_DIR is not writable."
        exit 1
    fi
else
    echo "Backup directory $BACKUP_DIR does not exist, creating it."
    mkdir -p "$BACKUP_DIR"
fi

# Build mysqldump connection args conditionally
DUMP_ARGS="--socket=/var/run/mysqld/mysqld.sock --all-databases"

# Only add --defaults-file if it exists and no user/pass provided
if [[ -z "$DATABASE_USER" && -f "$HOME/.my.cnf" ]]; then
    DUMP_ARGS="--defaults-file=$HOME/.my.cnf $DUMP_ARGS"
elif [[ -n "$DATABASE_USER" ]]; then
    DUMP_ARGS="-u $DATABASE_USER $DUMP_ARGS"
fi

# Password handling
if [[ -v DATABASE_PASSWORD && -z "$DATABASE_PASSWORD" ]]; then
    # --database-password was passed but empty, prompt
    DUMP_ARGS="$DUMP_ARGS -p"
elif [[ -n "$DATABASE_PASSWORD" ]]; then
    # password provided
    DUMP_ARGS="$DUMP_ARGS -p$DATABASE_PASSWORD"
fi
# if DATABASE_PASSWORD not set at all, no -p flag (relies on defaults file or no auth)

mysqldump $DUMP_ARGS > "$BACKUP_DIR/all-dbs_$DATE.sql"

# Compress it
gzip $BACKUP_DIR/all-dbs_$DATE.sql

if [[ -n "$RSYNC_DESTINATION" ]]; then
    rsync -avz --delete "$BACKUP_DIR/" "$RSYNC_DESTINATION"
fi

# Rsync to Storagebox
#rsync -avz --delete \
#  $BACKUP_DIR/ \
#  $STORAGEBOX:/backups/debian-hel1/

# Clean up local backups older than $DAYS_TO_KEEP days
find $BACKUP_DIR -name "*.sql.gz" -mtime +$DAYS_TO_KEEP -delete
