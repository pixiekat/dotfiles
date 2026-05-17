#!/usr/bin/env bash
# ============================================================================
# proton-natpmp-keepalive.sh
# ----------------------------------------------------------------------------
# Maintains a NAT-PMP port forward against a ProtonVPN WireGuard endpoint.
# Re-requests the lease every REFRESH_INTERVAL seconds so it never expires.
# Logs to a file, survives transient failures, and releases the mapping on
# clean shutdown.
#
# Requires: natpmpc (package: libnatpmp on Debian/Ubuntu/Mint)
# ============================================================================

set -u  # treat unset variables as errors; NOT -e because we handle errors ourselves

# --- Configuration ----------------------------------------------------------
GATEWAY="10.2.0.1"           # ProtonVPN WG gateway (your current value)
LEASE_LIFETIME=60            # seconds the mapping is valid
REFRESH_INTERVAL=45          # how often we re-request (must be < LEASE_LIFETIME)
MAX_CONSECUTIVE_FAILURES=5   # abort after this many back-to-back failures
RETRY_DELAY=10               # seconds to wait between failed attempts
LOG_FILE="${HOME}/.local/share/proton-natpmp/keepalive.log"
PORT_FILE="${HOME}/.local/share/proton-natpmp/current-port"

# --- Setup ------------------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")"

# log() writes to both stdout and the logfile with a timestamp.
# Using a function keeps the loop body readable.
log() {
    local msg="$*"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" | tee -a "$LOG_FILE"
}

# --- Signal handling --------------------------------------------------------
# On SIGINT/SIGTERM, try to release the mapping before exiting.
# natpmpc uses lifetime=0 to mean "delete this mapping".
cleanup() {
    log "Received shutdown signal; releasing port mappings..."
    natpmpc -a 1 0 udp 0 -g "$GATEWAY" >/dev/null 2>&1 || true
    natpmpc -a 1 0 tcp 0 -g "$GATEWAY" >/dev/null 2>&1 || true
    log "Exited cleanly."
    exit 0
}
trap cleanup INT TERM

# --- Main loop --------------------------------------------------------------
failure_count=0

log "Starting NAT-PMP keepalive (gateway=$GATEWAY, refresh=${REFRESH_INTERVAL}s)"

while true; do
    # Capture natpmpc output so we can parse the assigned port.
    # Redirecting stderr into stdout so error messages get logged too.
    udp_output=$(natpmpc -a 1 0 udp "$LEASE_LIFETIME" -g "$GATEWAY" 2>&1)
    udp_rc=$?
    tcp_output=$(natpmpc -a 1 0 tcp "$LEASE_LIFETIME" -g "$GATEWAY" 2>&1)
    tcp_rc=$?

    if [[ $udp_rc -eq 0 && $tcp_rc -eq 0 ]]; then
        # Success: extract the mapped public port from natpmpc's output.
        # The relevant line looks like: "Mapped public port 12345 ..."
        mapped_port=$(echo "$tcp_output" | awk '/Mapped public port/ {print $4; exit}')

        if [[ -n "$mapped_port" ]]; then
            # Only log on change to avoid log spam every 45 seconds.
            previous_port=$(cat "$PORT_FILE" 2>/dev/null || echo "")
            if [[ "$mapped_port" != "$previous_port" ]]; then
                log "Port assigned/changed: $mapped_port (was: ${previous_port:-none})"
                echo "$mapped_port" > "$PORT_FILE"
                # HOOK: call out to qBittorrent / transmission / whatever here
                # e.g.  update_qbittorrent_port "$mapped_port"
            fi
        fi

        failure_count=0
        sleep "$REFRESH_INTERVAL"
    else
        failure_count=$((failure_count + 1))
        log "FAILURE #$failure_count — udp_rc=$udp_rc tcp_rc=$tcp_rc"
        log "  udp output: $udp_output"
        log "  tcp output: $tcp_output"

        if (( failure_count >= MAX_CONSECUTIVE_FAILURES )); then
            log "Giving up after $MAX_CONSECUTIVE_FAILURES consecutive failures."
            exit 1
        fi

        sleep "$RETRY_DELAY"
    fi
done
