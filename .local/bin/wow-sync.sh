#!/usr/bin/env bash
# =============================================================================
#  wow-sync.sh — sync WoW Interface/AddOns + WTF between Tyrande & Naelaedra
# =============================================================================
#
#  What it does
#  ------------
#  Copies (never symlinks) AddOns and/or WTF from one machine to the other,
#  over SSH with rsync. Before ANY write it backs up the side being written
#  to, and it keeps a separate, never-pruned "TRP3 vault" of every
#  totalRP3*.lua it sees, because that's the irreplaceable stuff.
#
#  Menu
#  ----
#    1) Interface/AddOns
#    2) WTF
#    3) Both
#    4) Just backup (both machines, nothing synced)
#
#  Run it on EITHER machine. It works out which one it's on from the
#  hostname, and treats the other as the "peer", reached over SSH.
#
#  Requirements
#  ------------
#    - rsync >= 3.2.3 on both machines (for --mkpath; Mint 22 ships 3.2.7)
#    - key-based SSH from this machine to the other (a Host alias in
#      ~/.ssh/config is tidiest — see TYRANDE_SSH / NAELAEDRA_SSH)
#    - WoW CLOSED on both sides. SavedVariables are written on logout/exit,
#      so a running client will overwrite whatever we sync.
#
#  Usage
#  -----
#    ./wow-sync.sh                 # interactive menu
#    ./wow-sync.sh 3               # skip the menu, choose "Both"
#    NO_COLOR=1 ./wow-sync.sh      # plain output (screen readers / logs)
#    DRY_RUN=1 ./wow-sync.sh 2     # preview only, never write
#
#  Restoring
#  ---------
#    Full backups: $BACKUP_ROOT/<timestamp>/<machine>/<flavour>/*.tar.gz
#    TRP3 vault:   $BACKUP_ROOT/trp3-vault/<timestamp>/<machine>/<flavour>/
#    To restore TRP3: close WoW, then copy the .lua files back into
#    WTF/Account/<ACCOUNT>/SavedVariables/ on the right machine.
#
#  @see https://download.samba.org/pub/rsync/rsync.1  (rsync man page)
#  @see https://no-color.org
# =============================================================================

# -e: stop on errors, -u: unset vars are errors, -o pipefail: a failing
# command anywhere in a pipe fails the pipe, -E: ERR traps reach functions.
set -Eeuo pipefail

# -----------------------------------------------------------------------------
#  CONFIG — tweak these; everything else follows from them.
# -----------------------------------------------------------------------------

# SSH targets: a Host alias from ~/.ssh/config, or user@host.
# Tailscale MagicDNS names work fine. Overridable from the environment.
TYRANDE_SSH="${TYRANDE_SSH:-tyrande}"
NAELAEDRA_SSH="${NAELAEDRA_SSH:-naelaedra}"

# The two WoW roots (the folder holding _classic_, _retail_ etc).
TYRANDE_WOW="/mnt/storage/SteamLibrary/steamapps/compatdata/3772413630/pfx/drive_c/Program Files (x86)/World of Warcraft"
NAELAEDRA_WOW="/home/katy/.steam/steam/steamapps/compatdata/3974218138/pfx/drive_c/Program Files (x86)/World of Warcraft"

# Where backups go, on the machine RUNNING the script. Both sides get
# backed up here (the peer's files are pulled down with rsync first).
BACKUP_ROOT="${BACKUP_ROOT:-${HOME}/Backups/wow-sync}"

# How many timestamped full backups to keep. The TRP3 vault is NEVER pruned.
KEEP_BACKUPS="${KEEP_BACKUPS:-15}"

# Machine-specific WTF files that should NOT travel. Config.wtf holds
# graphics/resolution/gxApi, and the laptop and desktop want different ones.
# Patterns are rsync filter patterns, anchored to the WTF root by the "/".
WTF_EXCLUDES=(
  "/Config.wtf"
  "/Config.wtf.bak"
)

# 1 = WTF sync deletes files on the destination that the source lacks.
# Default 0: additive is the safer default for saved data.
WTF_DELETE="${WTF_DELETE:-0}"

# 1 = AddOns sync deletes addons on the destination the source lacks, so
# removed/renamed addons don't linger as ghosts. Set 0 to make it additive.
ADDONS_DELETE="${ADDONS_DELETE:-1}"

# 1 = preview everything, write nothing (backups are skipped too).
DRY_RUN="${DRY_RUN:-0}"

# Which game folder(s) to use without asking. Empty = ask (interactive).
# "all" = every flavour found (only used by option 4, the backup).
# e.g. WOW_FLAVOUR=_anniversary_   or   WOW_FLAVOUR=all
WOW_FLAVOUR="${WOW_FLAVOUR:-}"

# If set, this path MUST be a live mountpoint before we write a single
# backup. Guards against a dropped rclone mount, where the mount folder is
# just an empty local directory and backups would land there silently.
# e.g. BACKUP_REQUIRE_MOUNT="$HOME/mnt/storagebox"
BACKUP_REQUIRE_MOUNT="${BACKUP_REQUIRE_MOUNT:-}"

# Lock file so two runs (say, cron + you by hand) never overlap.
LOCK_FILE="${LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/wow-sync.lock}"

# Fail fast rather than hang forever if the peer is asleep.
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8)

# One timestamp for the whole run, so every artefact from a run lines up.
STAMP="$(date +%Y-%m-%d_%H%M%S)"

# -----------------------------------------------------------------------------
#  OUTPUT HELPERS
# -----------------------------------------------------------------------------

# Colour only on a real terminal and only if NO_COLOR isn't set. Every
# message also carries a word prefix (INFO/OK/WARNING/ERROR) so meaning
# never depends on colour alone.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_INFO=$'\e[36m'; C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'
  C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
  C_INFO=''; C_OK=''; C_WARN=''; C_ERR=''; C_BOLD=''; C_RESET=''
fi

##
# Print an informational line.
#
# @param string $* Message text.
##
info() { printf '%sINFO:%s %s\n' "$C_INFO" "$C_RESET" "$*"; }

##
# Print a success line.
#
# @param string $* Message text.
##
ok() { printf '%sOK:%s %s\n' "$C_OK" "$C_RESET" "$*"; }

##
# Print a warning to stderr.
#
# @param string $* Message text.
##
warn() { printf '%sWARNING:%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }

##
# Print an error to stderr and exit.
#
# @param string $* Message text.
# @return never (exits 1)
##
die() { printf '%sERROR:%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }

##
# Print a bold section heading with a blank line above it.
#
# @param string $* Heading text.
##
heading() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_RESET"; }

##
# Ask a yes/no question. Default is NO: just pressing Enter is always safe.
#
# @param string $1 The question.
# @return int 0 if the user typed y/yes, 1 otherwise.
##
confirm() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# -----------------------------------------------------------------------------
#  MACHINE HELPERS
#  A "side" is just the string "tyrande" or "naelaedra". These helpers turn
#  a side into paths/commands, so the rest of the script never has to care
#  whether a side is local or remote.
# -----------------------------------------------------------------------------

##
# Work out which machine we're running on.
#
# Override with LOCAL_SIDE=tyrande|naelaedra if your hostname differs.
#
# @return string "tyrande" or "naelaedra" on stdout.
##
detect_local_side() {
  local h="${LOCAL_SIDE:-$(hostname -s)}"
  h="${h,,}"
  case "$h" in
    *tyrande*)   echo "tyrande" ;;
    *naelaedra*) echo "naelaedra" ;;
    *) die "Can't tell which machine this is (hostname '$h'). Run with LOCAL_SIDE=tyrande or LOCAL_SIDE=naelaedra." ;;
  esac
}

LOCAL_SIDE="$(detect_local_side)"
if [[ "$LOCAL_SIDE" == "tyrande" ]]; then PEER_SIDE="naelaedra"; else PEER_SIDE="tyrande"; fi

##
# Is this side the machine we're running on?
#
# @param string $1 Side name.
# @return int 0 if local.
##
is_local() { [[ "$1" == "$LOCAL_SIDE" ]]; }

##
# The WoW root folder for a side.
#
# @param string $1 Side name.
# @return string Absolute path on stdout.
##
wow_root() {
  case "$1" in
    tyrande)   echo "$TYRANDE_WOW" ;;
    naelaedra) echo "$NAELAEDRA_WOW" ;;
  esac
}

##
# The SSH target for a side.
#
# @param string $1 Side name.
# @return string SSH destination on stdout.
##
ssh_target() {
  case "$1" in
    tyrande)   echo "$TYRANDE_SSH" ;;
    naelaedra) echo "$NAELAEDRA_SSH" ;;
  esac
}

##
# Turn a path on a side into something rsync understands:
# plain path if local, "host:path" if remote.
#
# Spaces in "Program Files (x86)" are safe because we call rsync with
# --protect-args (-s), which stops the remote shell splitting the path.
#
# @param string $1 Side name.
# @param string $2 Path on that side.
# @return string rsync location on stdout.
##
rsync_loc() {
  if is_local "$1"; then echo "$2"; else echo "$(ssh_target "$1"):$2"; fi
}

##
# Run a shell command on a side (locally, or over SSH).
#
# Callers must quote any paths inside the command with printf %q,
# because over SSH the string goes through the remote shell.
#
# @param string $1 Side name.
# @param string $2 Command string.
# @return int The command's exit status.
##
run_on() {
  if is_local "$1"; then
    bash -c "$2"
  else
    ssh "${SSH_OPTS[@]}" "$(ssh_target "$1")" "$2"
  fi
}

##
# Pretty name for messages, e.g. "Tyrande (this machine)".
#
# @param string $1 Side name.
# @return string Label on stdout.
##
label() {
  local name="${1^}"
  if is_local "$1"; then echo "$name (this machine)"; else echo "$name (remote)"; fi
}

# -----------------------------------------------------------------------------
#  PRE-FLIGHT CHECKS
# -----------------------------------------------------------------------------

##
# Make sure we can reach the peer, rsync exists on both ends, and both WoW
# roots exist. Dies with a readable reason if not.
##
preflight() {
  heading "Checking things over"
  command -v rsync >/dev/null || die "rsync isn't installed here (sudo apt install rsync)."

  if ! ssh "${SSH_OPTS[@]}" "$(ssh_target "$PEER_SIDE")" true 2>/dev/null; then
    die "Can't SSH to $(ssh_target "$PEER_SIDE"). Is $(label "$PEER_SIDE") awake, and is key login set up?"
  fi
  run_on "$PEER_SIDE" "command -v rsync >/dev/null" \
    || die "rsync isn't installed on $(label "$PEER_SIDE")."

  local side
  for side in tyrande naelaedra; do
    run_on "$side" "test -d $(printf %q "$(wow_root "$side")")" \
      || die "WoW folder not found on $(label "$side"): $(wow_root "$side")"
  done
  ok "Both machines reachable, both WoW folders found."
}

##
# Refuse to continue while WoW is running on a side, because the client
# rewrites SavedVariables on exit and would undo the sync.
#
# Matches Wow.exe, WowClassic.exe, WowClassicT.exe, Wow-64.exe, etc.
#
# @param string $1 Side name.
##
check_wow_closed() {
  if run_on "$1" "pgrep -if 'wow[a-z]*(-64)?\.exe' >/dev/null"; then
    die "WoW looks like it's running on $(label "$1"). Log out fully and close it first, or SavedVariables will get overwritten."
  fi
}

# -----------------------------------------------------------------------------
#  FLAVOUR PICKER (_classic_, _classic_era_, _anniversary_, _retail_, ...)
# -----------------------------------------------------------------------------

##
# List the game-flavour folders (named like _something_) on a side.
#
# @param string $1 Side name.
# @return string One folder name per line on stdout.
##
list_flavours() {
  local root
  root="$(printf %q "$(wow_root "$1")")"
  run_on "$1" "cd $root && for d in _*_; do [ -d \"\$d\" ] && echo \"\$d\"; done; true"
}

##
# Let the user choose which flavour to work on. Only flavours that exist
# on BOTH machines are offered, since there's nothing to sync otherwise.
#
# Sets the global FLAVOUR.
##
pick_flavour() {
  local -a here there common=()
  mapfile -t here  < <(list_flavours "$LOCAL_SIDE")
  mapfile -t there < <(list_flavours "$PEER_SIDE")

  # Intersection of the two lists.
  local a b
  for a in "${here[@]}"; do
    for b in "${there[@]}"; do [[ "$a" == "$b" ]] && common+=("$a"); done
  done
  (( ${#common[@]} )) || die "No game flavour folder exists on both machines."

  # Chosen up front via WOW_FLAVOUR? Check it exists on both and use it.
  if [[ -n "$WOW_FLAVOUR" && "$WOW_FLAVOUR" != "all" ]]; then
    printf '%s\n' "${common[@]}" | grep -qxF -- "$WOW_FLAVOUR" \
      || die "WOW_FLAVOUR=${WOW_FLAVOUR} isn't on both machines (shared: ${common[*]})."
    FLAVOUR="$WOW_FLAVOUR"
    info "Using ${FLAVOUR} (from WOW_FLAVOUR)"
    return
  fi

  if (( ${#common[@]} == 1 )); then
    FLAVOUR="${common[0]}"
    info "Only one shared flavour, using ${FLAVOUR}"
    return
  fi

  heading "Which game?"
  PS3="Pick a number: "
  select FLAVOUR in "${common[@]}"; do
    [[ -n "${FLAVOUR:-}" ]] && break
    warn "That's not one of the options."
  done
}

# -----------------------------------------------------------------------------
#  BACKUPS
# -----------------------------------------------------------------------------

##
# Back up a side's WTF (and optionally AddOns) into a timestamped tarball
# under BACKUP_ROOT. Remote sides are pulled down with rsync first, so all
# backups end up on the machine running the script.
#
# @param string $1 Side name.
# @param string $2 What to back up: "wtf", "addons" or "both".
##
backup_side() {
  local side="$1" what="$2"
  local base src dest stage
  base="$(wow_root "$side")/${FLAVOUR}"
  dest="${BACKUP_ROOT}/${STAMP}/${side}/${FLAVOUR}"
  stage="$(mktemp -d)"

  if (( DRY_RUN )); then
    info "[dry run] would back up ${what} from $(label "$side") to ${dest}"
    rmdir "$stage"; return
  fi
  mkdir -p "$dest"

  # Each part: stage a copy with rsync, tar.gz it, drop the staging copy.
  local part rel
  for part in wtf addons; do
    [[ "$what" == "both" || "$what" == "$part" ]] || continue
    if [[ "$part" == "wtf" ]]; then rel="WTF"; else rel="Interface/AddOns"; fi
    src="${base}/${rel}"

    if ! run_on "$side" "test -d $(printf %q "$src")"; then
      warn "No ${rel} on $(label "$side") yet, nothing to back up there."
      continue
    fi

    info "Backing up ${rel} from $(label "$side")..."
    mkdir -p "${stage}/${part}"
    rsync -a -s "$(rsync_loc "$side" "$src")/" "${stage}/${part}/"
    tar -czf "${dest}/${part}.tar.gz" -C "$stage" "$part"
    ok "Saved ${dest}/${part}.tar.gz"
  done
  rm -rf "$stage"
}

##
# Copy every TotalRP3 SavedVariables file on a side into the TRP3 vault.
#
# Grabs totalRP3.lua, totalRP3_Data.lua, any other totalRP3*.lua (some
# modules have their own) and WoW's own .lua.bak copies of them, from every
# account folder, keeping the Account/<NAME>/SavedVariables layout so
# restoring is a straight copy back. The vault is never pruned.
#
# @param string $1 Side name.
##
vault_trp3() {
  local side="$1" src dest
  src="$(wow_root "$side")/${FLAVOUR}/WTF/Account"
  dest="${BACKUP_ROOT}/trp3-vault/${STAMP}/${side}/${FLAVOUR}"

  if ! run_on "$side" "test -d $(printf %q "$src")"; then
    warn "No WTF/Account on $(label "$side"), so no TRP3 data there."
    return
  fi
  if (( DRY_RUN )); then
    info "[dry run] would vault TRP3 files from $(label "$side") to ${dest}"
    return
  fi

  mkdir -p "$dest"
  # Filter rules, read top to bottom, first match wins:
  #   */                 descend into every folder...
  #   totalRP3*.lua(.bak) keep the TRP3 files...
  #   *                  ...and skip everything else.
  # --prune-empty-dirs drops folders that ended up with nothing in them.
  rsync -a -s --prune-empty-dirs \
    --include='*/' \
    --include='totalRP3*.lua' --include='totalRP3*.lua.bak' \
    --exclude='*' \
    "$(rsync_loc "$side" "$src")/" "${dest}/"

  local count
  count="$(find "$dest" -type f -name 'totalRP3*' | wc -l)"
  if (( count )); then
    ok "TRP3 vault: ${count} file(s) from $(label "$side") in ${dest}"
  else
    warn "No totalRP3 files found on $(label "$side")."
    rmdir -p "$dest" 2>/dev/null || true
  fi
}

##
# Keep only the newest KEEP_BACKUPS timestamped backup folders.
# The trp3-vault folder is deliberately left alone.
##
prune_backups() {
  (( DRY_RUN )) && return
  [[ -d "$BACKUP_ROOT" ]] || return
  local -a old
  # Timestamp names sort correctly as text, so newest-first is a reverse sort.
  mapfile -t old < <(
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' -printf '%f\n' \
      | sort -r | tail -n +"$((KEEP_BACKUPS + 1))"
  )
  local d
  for d in "${old[@]}"; do
    rm -rf "${BACKUP_ROOT:?}/${d}"
    info "Pruned old backup ${d}"
  done
}

# -----------------------------------------------------------------------------
#  TRP3 SAFETY CHECK
# -----------------------------------------------------------------------------

##
# List TRP3 files on a side as "epoch<TAB>relative/path".
#
# @param string $1 Side name.
# @return string One line per file on stdout.
##
trp3_listing() {
  local wtf
  wtf="$(printf %q "$(wow_root "$1")/${FLAVOUR}/WTF")"
  run_on "$1" "[ -d $wtf ] && find $wtf -type f -name 'totalRP3*.lua' -printf '%T@\t%P\n'; true"
}

##
# Compare TRP3 files on source vs destination before a WTF sync. If any
# destination copy is NEWER than the source copy, that usually means you
# RP'd on the destination more recently and the sync would roll it back,
# so we stop and ask.
#
# @param string $1 Source side.
# @param string $2 Destination side.
# @return int 0 to carry on, 1 if the user backed out.
##
trp3_guard() {
  local src="$1" dst="$2"
  local -A src_time=()
  local t p newer=0

  while IFS=$'\t' read -r t p; do
    [[ -n "$p" ]] && src_time["$p"]="${t%.*}"
  done < <(trp3_listing "$src")

  heading "TotalRP3 check"
  while IFS=$'\t' read -r t p; do
    [[ -z "$p" || -z "${src_time[$p]:-}" ]] && continue
    t="${t%.*}"
    if (( t > src_time[$p] )); then
      newer=1
      warn "Destination copy is NEWER: ${p}"
      printf '         %s: %s\n' "$(label "$src")" "$(date -d "@${src_time[$p]}" '+%a %d %b %Y %H:%M')"
      printf '         %s: %s\n' "$(label "$dst")" "$(date -d "@${t}" '+%a %d %b %Y %H:%M')"
    fi
  done < <(trp3_listing "$dst")

  if (( newer )); then
    warn "Syncing will replace the newer TRP3 data above (it IS in the vault either way)."
    confirm "Carry on anyway?" || return 1
  else
    ok "No destination TRP3 file is newer than its source. Safe to go."
  fi
}

# -----------------------------------------------------------------------------
#  SYNC
# -----------------------------------------------------------------------------

##
# Preview an rsync, show what would change, ask, then run it for real.
#
# @param string $1   Human label for the job, e.g. "AddOns".
# @param string ...  rsync arguments (options, then source, then dest).
# @return int 0 on success or if the user skipped.
##
preview_and_run() {
  local what="$1"; shift
  local -a changes

  # -n = dry run, -i = itemise (one line per file it would touch).
  mapfile -t changes < <(rsync -ani -s "$@")
  if (( ${#changes[@]} == 0 )); then
    ok "${what}: already in sync, nothing to do."
    return 0
  fi

  heading "${what}: ${#changes[@]} change(s)"
  # Show the first 40 so the screen doesn't flood; the full list goes to a
  # temp file you can page through if you want.
  printf '%s\n' "${changes[@]:0:40}"
  if (( ${#changes[@]} > 40 )); then
    local full
    full="$(mktemp --suffix=.txt)"
    printf '%s\n' "${changes[@]}" > "$full"
    info "...and $(( ${#changes[@]} - 40 )) more. Full list: ${full}"
  fi
  # rsync shows '<f' when sending to a remote and '>f' when receiving.
  info "Key: '<f' / '>f' = file copied, 'cd' = new folder, '*deleting' = removed."

  (( DRY_RUN )) && { info "[dry run] not applying."; return 0; }
  confirm "Apply these ${what} changes?" || { info "Skipped ${what}."; return 0; }

  rsync -a -s "$@"
  ok "${what} synced."
}

##
# Sync Interface/AddOns from one side to the other.
#
# @param string $1 Source side.
# @param string $2 Destination side.
##
sync_addons() {
  local src dst
  src="$(wow_root "$1")/${FLAVOUR}/Interface/AddOns"
  dst="$(wow_root "$2")/${FLAVOUR}/Interface/AddOns"
  local -a opts=(--mkpath)
  (( ADDONS_DELETE )) && opts+=(--delete)
  preview_and_run "AddOns" "${opts[@]}" "$(rsync_loc "$1" "$src")/" "$(rsync_loc "$2" "$dst")/"
}

##
# Sync WTF from one side to the other, minus machine-specific files.
#
# @param string $1 Source side.
# @param string $2 Destination side.
##
sync_wtf() {
  local src dst x
  src="$(wow_root "$1")/${FLAVOUR}/WTF"
  dst="$(wow_root "$2")/${FLAVOUR}/WTF"
  local -a opts=(--mkpath)
  for x in "${WTF_EXCLUDES[@]}"; do opts+=(--exclude="$x"); done
  # --delete-excluded is NOT used, so excluded files on the destination
  # (its own Config.wtf) are always left alone even with WTF_DELETE=1.
  (( WTF_DELETE )) && opts+=(--delete)
  trp3_guard "$1" "$2" || { info "Skipped WTF."; return 0; }
  preview_and_run "WTF" "${opts[@]}" "$(rsync_loc "$1" "$src")/" "$(rsync_loc "$2" "$dst")/"
}

# -----------------------------------------------------------------------------
#  BACKUP-ONLY MODE (option 4) — safe to run unattended from cron/systemd
# -----------------------------------------------------------------------------

##
# Refuse to back up into a dropped mount. If BACKUP_REQUIRE_MOUNT is set
# and isn't a live mountpoint, stop before writing anything.
##
check_backup_target() {
  if [[ -n "$BACKUP_REQUIRE_MOUNT" ]] && ! mountpoint -q "$BACKUP_REQUIRE_MOUNT"; then
    die "${BACKUP_REQUIRE_MOUNT} isn't mounted, so no backup was written. Is the rclone mount up?"
  fi
  if (( ! DRY_RUN )); then
    mkdir -p "$BACKUP_ROOT" || die "Can't create ${BACKUP_ROOT}."
    [[ -w "$BACKUP_ROOT" ]] || die "Can't write to ${BACKUP_ROOT}."
  fi
}

##
# Back up WTF + the TRP3 vault from every machine we can reach.
#
# Unlike a sync, a backup doesn't need BOTH machines: if the laptop is
# asleep, Tyrande still gets backed up (and the reverse). A side is also
# skipped if WoW is running there, since SavedVariables may be mid-write.
#
# Flavours: WOW_FLAVOUR=all backs up every flavour on each side,
# WOW_FLAVOUR=<name> just that one, empty = ask (interactive only).
#
# @return int 0 if at least one machine was backed up, 1 if none were.
##
backup_all() {
  check_backup_target
  command -v rsync >/dev/null || die "rsync isn't installed here."

  local side done_any=0
  local -a flavours
  for side in "$LOCAL_SIDE" "$PEER_SIDE"; do
    heading "Backing up $(label "$side")"

    # Reachable? (Always true for the local side.)
    if ! is_local "$side" \
       && ! ssh "${SSH_OPTS[@]}" "$(ssh_target "$side")" true 2>/dev/null; then
      warn "Can't reach $(label "$side") (asleep?), skipping it this time."
      continue
    fi
    if ! run_on "$side" "test -d $(printf %q "$(wow_root "$side")")"; then
      warn "No WoW folder on $(label "$side"), skipping."
      continue
    fi
    if run_on "$side" "pgrep -if 'wow[a-z]*(-64)?\.exe' >/dev/null"; then
      warn "WoW is running on $(label "$side"), skipping so we don't catch files mid-write."
      continue
    fi

    # Which flavours for this side?
    if [[ "$WOW_FLAVOUR" == "all" ]]; then
      mapfile -t flavours < <(list_flavours "$side")
    elif [[ -n "$WOW_FLAVOUR" ]]; then
      flavours=("$WOW_FLAVOUR")
    else
      # Interactive run with no WOW_FLAVOUR: the menu has already picked one.
      flavours=("$FLAVOUR")
    fi

    for FLAVOUR in "${flavours[@]}"; do
      run_on "$side" "test -d $(printf %q "$(wow_root "$side")/${FLAVOUR}")" || continue
      info "Game folder: ${FLAVOUR}"
      backup_side "$side" "wtf"
      vault_trp3 "$side"
      done_any=1
    done
  done

  prune_backups
  heading "Done"
  if (( done_any )); then
    ok "Backups are in ${BACKUP_ROOT}"
  else
    warn "Nothing was backed up this run."
    return 1
  fi
}

# -----------------------------------------------------------------------------
#  MENU + MAIN
# -----------------------------------------------------------------------------

##
# Ask which way to sync. Sets globals SRC and DST.
##
pick_direction() {
  heading "Which way?"
  echo "  1) Push: $(label "$LOCAL_SIDE")  ->  $(label "$PEER_SIDE")"
  echo "  2) Pull: $(label "$PEER_SIDE")  ->  $(label "$LOCAL_SIDE")"
  local reply
  read -r -p "Pick 1 or 2: " reply
  case "$reply" in
    1) SRC="$LOCAL_SIDE"; DST="$PEER_SIDE" ;;
    2) SRC="$PEER_SIDE";  DST="$LOCAL_SIDE" ;;
    *) die "Didn't catch that, nothing changed." ;;
  esac
  info "Copying FROM $(label "$SRC") TO $(label "$DST")"
}

##
# Entry point.
#
# @param string $1 Optional menu choice (1-4) to skip the menu.
##
main() {
  local choice="${1:-}"

  printf '%swow-sync%s  |  here: %s  |  peer: %s\n' \
    "$C_BOLD" "$C_RESET" "$(label "$LOCAL_SIDE")" "$(label "$PEER_SIDE")"
  (( DRY_RUN )) && warn "DRY RUN: nothing will be written."

  if [[ -z "$choice" ]]; then
    heading "What shall we do?"
    echo "  1) Interface/AddOns"
    echo "  2) WTF"
    echo "  3) Both"
    echo "  4) Just backup (both machines)"
    echo "  q) Quit"
    read -r -p "Pick one: " choice
  fi
  [[ "$choice" == "q" ]] && exit 0
  [[ "$choice" =~ ^[1-4]$ ]] || die "Pick 1, 2, 3, 4 or q."

  # Only one copy of this script at a time. flock -n fails at once rather
  # than waiting if another run (e.g. the nightly one) holds the lock.
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "Another wow-sync is already running."

  # Option 4: back up whatever machines are reachable, sync nothing.
  # Doesn't need both machines up, so it skips the full preflight.
  if [[ "$choice" == "4" ]]; then
    # Interactive and no WOW_FLAVOUR? Ask once, like the other options.
    if [[ -z "$WOW_FLAVOUR" ]]; then
      [[ -t 0 ]] || die "Running unattended: set WOW_FLAVOUR=all (or a folder name)."
      preflight
      pick_flavour
    fi
    backup_all
    return
  fi

  preflight
  pick_flavour
  pick_direction
  # Both sides must be closed: the source because it could still be
  # writing, the destination because it would overwrite on exit.
  check_wow_closed "$SRC"
  check_wow_closed "$DST"

  # Back up BEFORE touching anything. TRP3 is vaulted from BOTH sides on
  # every run that touches WTF, so neither copy can ever be lost.
  heading "Backing up first"
  case "$choice" in
    1) backup_side "$DST" "addons" ;;
    2|3)
      backup_side "$DST" "$([[ "$choice" == 3 ]] && echo both || echo wtf)"
      vault_trp3 "$SRC"
      vault_trp3 "$DST"
      ;;
  esac

  case "$choice" in
    1) sync_addons "$SRC" "$DST" ;;
    2) sync_wtf "$SRC" "$DST" ;;
    3) sync_addons "$SRC" "$DST"; sync_wtf "$SRC" "$DST" ;;
  esac

  prune_backups
  heading "Done"
  ok "All finished. Backups: ${BACKUP_ROOT}"
}

main "$@"
