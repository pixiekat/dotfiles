#!/bin/bash
# backup-home-to-storagebox.sh
# Incremental rsync backup of $HOME to Hetzner storagebox
# Place in ~/.local/bin/ and chmod +x
# Run manually first to verify before scheduling


# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mount)
            MOUNT="$2"
            shift 2
            ;;
        --device-name)
            DEVICE_NAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--mount MOUNT_POINT] [--device-name DEVICE_NAME]"
            echo "  --mount MOUNT_POINT         Path where storagebox is mounted (default: $HOME/mnt/storagebox)"
            echo "  --device-name DEVICE_NAME   Name to identify this device in the backup (default: device-$(hostname))"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set defaults AFTER parsing so flags take precedence
MOUNT="${MOUNT:-$HOME/mnt/storagebox}"
DEVICE_NAME="${DEVICE_NAME:-device-$(hostname)}"

BACKUP_DEST="$MOUNT/archives/devices/$DEVICE_NAME/home"
LOG_DIR="$HOME/.local/log"
LOG="$LOG_DIR/backup-$DEVICE_NAME-home-to-storagebox.log"

mkdir -p "$LOG_DIR"

# bail if storagebox isn't mounted
if ! mountpoint -q "$MOUNT"; then
    echo "$(date): storagebox not mounted, skipping" >> "$LOG"
    exit 1
fi

# ensure destination exists on first run
mkdir -p "$BACKUP_DEST"

echo "$(date): starting backup of $DEVICE_NAME:$HOME to $BACKUP_DEST" >> "$LOG"
echo "hostname is: $(hostname)" >> "$LOG"

# cache and junk - regenerable
# large reinstallable things
# sensitive credentials and private content
rsync -avz \
    --delete \
    --copy-links \
    --exclude='.aws/' \
    --exclude='.cache/' \
    --exclude='.config/BraveSoftware/' \
    --exclude='.config/Code - Insiders/Backups/' \
    --exclude='.config/Code - Insiders/CachedProfilesData/' \
    --exclude='.config/Code - Insiders/CachedConfigurations/' \
    --exclude='.config/Code - Insiders/CachedExtensionVSIXs/' \
    --exclude='.config/Code - Insiders/DawnGraphiteCache/' \
    --exclude='.config/Code - Insiders/DawnWebGPUCache/' \
    --exclude='.config/Code - Insiders/User/History/' \
    --exclude='.config/Code - Insiders/User/workspaceStorage/' \
    --exclude='.config/Code - Insiders/WebStorage/' \
    --exclude='.config/google-chrome*' \
    --exclude='.config/microsoft-edge*' \
    --exclude='.config/mozilla/firefox/*/datareporting/' \
    --exclude='.config/mozilla/firefox/*/extension-store/' \
    --exclude='.config/unity3d/Klei/Oxygen Not Included/RetiredColonies/' \
    --exclude='.config/unity3d/Klei/Oxygen Not Included/mods/' \
    --exclude='.config/mozilla/firefox/*/extensions/' \
    --exclude='.config/mozilla/firefox/*/storage/' \
    --exclude='.config/mozilla/firefox/Crash Reports/' \
    --exclude='.config/mozilla/firefox/Pending Pings/' \
    --exclude='.config/sublime-text/' \
    --exclude='.config/vivaldi/*/Extensions/' \
    --exclude='.config/vivaldi/AdverseAdSiteList.json' \
    --exclude='.config/vivaldi/component_crx_cache/' \
    --exclude='.config/vivaldi/Crash Reports/' \
    --exclude='.config/vivaldi/extensions_crx_cache/' \
    --exclude='.config/vivaldi/GraphiteDawnCache/' \
    --exclude='.config/vivaldi/GrShaderCache/' \
    --exclude='.config/vivaldi/Safe Browsing/' \
    --exclude='.config/vivaldi/ShaderCache/' \
    --exclude='.gnupg/' \
    --exclude='.librewolf/*/extension-dnr/' \
    --exclude='.librewolf/*/extension-store-menus/' \
    --exclude='.librewolf/*/extension-store-userscripts/' \
    --exclude='.librewolf/*/extension-store/' \
    --exclude='.librewolf/*/extensions/' \
    --exclude='.librewolf/*/storage/' \
    --exclude='.local/share/DBeaverData/install-data/' \
    --exclude='.local/share/evolution/' \
    --exclude='.local/share/flatpak/' \
    --exclude='.local/share/gvfs-metadata/' \
    --exclude='.local/share/mime/' \
    --exclude='.local/share/recently-used.xbel' \
    --exclude='.local/share/Steam/' \
    --exclude='.local/share/Trash/' \
    --exclude='.local/thunderbird/updated/' \
    --exclude='.local/thunderbird/updates/' \
    --exclude='.moonchild productions/*/storage/' \
    --exclude='.mozilla/seamonkey/*/storage/' \
    --exclude='.mozilla/seamonkey/Crash Reports/' \
    --exclude='.npm/' \
    --exclude='.nv/' \
    --exclude='.nvm/' \
    --exclude='.paradoxlauncher/' \
    --exclude='.ssh/' \
    --exclude='.steam/' \
    --exclude='.steampath' \
    --exclude='.steampid' \
    --exclude='.xsession-errors*' \
    --exclude='.zcompdump*' \
    --exclude='.zoom/' \
    --exclude='blob_storage/' \
    --exclude='cache/' \
    --exclude='Cache/' \
    --exclude='CachedData/' \
    --exclude='Code Cache/' \
    --exclude='Crashpad/' \
    --exclude='DawnCache/' \
    --exclude='Downloads/Wrestling/' \
    --exclude='GPUCache/' \
    --exclude='logs/' \
    --exclude='mnt/' \
    --exclude='Session Storage/' \
    --exclude='VideoDecodeStats/' \
    --exclude='Videos/private/' \
    --exclude='.vscode-insiders/extensions/' \
    --exclude='webdev/' \
    "$HOME/" "$BACKUP_DEST/"

RSYNC_EXIT=$?
if [ $RSYNC_EXIT -ne 0 ]; then
    echo "$(date): rsync failed with exit code $RSYNC_EXIT" >> "$LOG"
    exit $RSYNC_EXIT
fi

echo "$(date): $DEVICE_NAME:$HOME backup complete" >> "$LOG"
