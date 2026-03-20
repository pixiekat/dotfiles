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

        --help|-h)
            echo "Usage: $0 [--backup-dir BACKUP_DIR] [--date-format DATE_FORMAT] [--database-user DATABASE_USER] [--database-password DATABASE_PASSWORD] [--days-to-keep DAYS_TO_KEEP]"
            echo "  --backup-dir BACKUP_DIR     Path where backups will be stored (default: $HOME/backup/sql)"
            echo "  --date-format DATE_FORMAT   Date format for backup files (default: %Y%m%d_%H%M%S)"
            echo "  --database-user DATABASE_USER User to connect to MariaDB (default: $USER)"
            echo "  --database-password DATABASE_PASSWORD Password for MariaDB user (default: empty)"
            echo "  --days-to-keep DAYS_TO_KEEP Number of days to keep backups (default: 7)"
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
#STORAGEBOX="u123456@u123456.your-storagebox.de"

# DATABASE_USER is the only "required"; if there's no $HOME/.my.cnf. Fail with message.
if [[ -z "$DATABASE_USER" && ! -f "$HOME/.my.cnf" ]]; then
    echo "Error: No database credentials found. Please either:"
    echo "  - Create $HOME/.my.cnf with your MariaDB credentials, or"
    echo "  - Pass --database-user (leave --database-password empty to be prompted securely)"
    exit 1
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

# Dump all databases
mysqldump -u $DATABASE_USER -p"$DATABASE_PASSWORD" --socket=/var/run/mysqld/mysqld.sock \
  --all-databases > $BACKUP_DIR/all-dbs_$DATE.sql

# Compress it
gzip $BACKUP_DIR/all-dbs_$DATE.sql

# Rsync to Storagebox
#rsync -avz --delete \
#  $BACKUP_DIR/ \
#  $STORAGEBOX:/backups/debian-hel1/

# Clean up local backups older than $DAYS_TO_KEEP days
find $BACKUP_DIR -name "*.sql.gz" -mtime +$DAYS_TO_KEEP -delete
