#!/usr/bin/env bash
set -euo pipefail

# VPS Self-Healing Monitor
# Runs via cron every 3 minutes. Monitors resources, Docker services,
# and takes corrective action before things crash.

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/self-heal.log"
STATE_FILE="$LOG_DIR/self-heal-state.json"
mkdir -p "$LOG_DIR"

# --- Telegram notification ---
BOT_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$HOME/.claude/channels/telegram/.env" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//' | tr -d '[:space:]' || echo "")
CHAT_ID="8328233140"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

notify() {
  local msg="$1"
  log "NOTIFY: $msg"
  if [ -n "$BOT_TOKEN" ]; then
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${CHAT_ID}" \
      --data-urlencode "text=${msg}" > /dev/null 2>&1 || true
  fi
}

# --- 1. Memory Monitor ---
check_memory() {
  local total used available pct
  read -r total used _ _ _ available <<< "$(free -m | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}')"
  pct=$(( (used * 100) / total ))

  log "MEMORY: ${pct}% used (${used}MB / ${total}MB, ${available}MB available)"

  if [ "$pct" -gt 90 ]; then
    log "CRITICAL: Memory at ${pct}% — clearing caches and killing bloated processes"
    notify "VPS MEMORY CRITICAL: ${pct}% used (${available}MB free). Auto-cleaning..."

    # Drop caches
    sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true

    # Kill largest non-essential processes if still critical
    local after_available
    after_available=$(free -m | awk '/^Mem:/ {print $7}')
    if [ "$after_available" -lt 500 ]; then
      # Restart Docker containers that are using excessive memory
      local top_container
      top_container=$(sg docker -c "docker stats --no-stream --format '{{.Name}} {{.MemPerc}}'" 2>/dev/null | sort -k2 -t'%' -rn | head -1 | awk '{print $1}')
      if [ -n "$top_container" ] && [ "$top_container" != "agentos-postgres" ] && [ "$top_container" != "agentos-redis" ]; then
        log "Restarting memory-hungry container: $top_container"
        sg docker -c "docker restart $top_container" 2>/dev/null || true
        notify "Restarted container $top_container to free memory."
      fi
    fi

  elif [ "$pct" -gt 80 ]; then
    log "WARNING: Memory at ${pct}%"
    # Drop filesystem caches as preventive measure
    sync && echo 1 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
  fi
}

# --- 2. Disk Monitor ---
check_disk() {
  local pct
  pct=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')

  log "DISK: ${pct}% used"

  if [ "$pct" -gt 90 ]; then
    log "CRITICAL: Disk at ${pct}%"
    notify "VPS DISK CRITICAL: ${pct}% full. Auto-cleaning..."

    # Clean Docker
    sg docker -c "docker system prune -f --volumes" 2>/dev/null || true

    # Clean logs over 100MB
    find /var/log -name "*.log" -size +100M -exec truncate -s 10M {} \; 2>/dev/null || true
    find "$LOG_DIR" -name "*.log" -size +50M -exec truncate -s 5M {} \; 2>/dev/null || true

    # Clean old journal logs
    sudo journalctl --vacuum-size=100M 2>/dev/null || true

    # Clean npm/pnpm cache
    npm cache clean --force 2>/dev/null || true

    local after_pct
    after_pct=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    notify "Disk cleanup done: ${pct}% -> ${after_pct}%"

  elif [ "$pct" -gt 80 ]; then
    log "WARNING: Disk at ${pct}%"
  fi
}

# --- 3. Docker Services Monitor ---
check_docker() {
  local expected_services="agentos-backend agentos-frontend agentos-postgres agentos-redis agentos-worker agentos-nginx"
  local needs_restart=""

  for svc in $expected_services; do
    local status
    status=$(sg docker -c "docker inspect -f '{{.State.Status}}' $svc" 2>/dev/null || echo "missing")

    if [ "$status" != "running" ]; then
      log "DOCKER: $svc is $status"
      needs_restart="$needs_restart $svc"
    fi
  done

  if [ -n "$needs_restart" ]; then
    log "DOCKER: Restarting stopped services:$needs_restart"
    notify "Docker services down:$needs_restart — restarting..."

    cd /home/claude/manus-clone 2>/dev/null && \
      sg docker -c "docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d" 2>/dev/null || true

    sleep 10

    # Verify
    local still_down=""
    for svc in $needs_restart; do
      local after_status
      after_status=$(sg docker -c "docker inspect -f '{{.State.Status}}' $svc" 2>/dev/null || echo "missing")
      if [ "$after_status" != "running" ]; then
        still_down="$still_down $svc"
      fi
    done

    if [ -n "$still_down" ]; then
      notify "ALERT: Failed to restart:$still_down — may need manual intervention."
    else
      notify "All Docker services recovered successfully."
    fi
  else
    log "DOCKER: All services running"
  fi
}

# --- 4. CPU / Load Monitor ---
check_load() {
  local cores load1
  cores=$(nproc)
  load1=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')

  # Compare as integers (multiply by 100)
  local load_int cores_threshold
  load_int=$(echo "$load1" | awk '{printf "%d", $1 * 100}')
  cores_threshold=$(( cores * 200 ))  # 2x cores = high load

  log "LOAD: $load1 (cores: $cores)"

  if [ "$load_int" -gt "$cores_threshold" ]; then
    log "WARNING: High load ($load1 vs $cores cores)"
    notify "VPS HIGH LOAD: $load1 (${cores} cores). Investigating..."

    # Log top processes for debugging
    ps aux --sort=-%cpu | head -5 >> "$LOG_FILE"
  fi
}

# --- 5. Swap Check ---
check_swap() {
  # If no swap exists, create a small one as safety net
  local swap_total
  swap_total=$(free -m | awk '/^Swap:/ {print $2}')

  if [ "$swap_total" -eq 0 ]; then
    if [ ! -f /swapfile ]; then
      log "SWAP: No swap found — creating 2GB swapfile as safety net"
      sudo fallocate -l 2G /swapfile 2>/dev/null && \
        sudo chmod 600 /swapfile && \
        sudo mkswap /swapfile && \
        sudo swapon /swapfile && \
        log "SWAP: Created and enabled 2GB swapfile" || \
        log "SWAP: Failed to create swapfile"
    fi
  fi
}

# --- 6. SSH Hardening ---
check_ssh() {
  local ssh_active
  ssh_active=$(systemctl is-active ssh 2>/dev/null || echo "unknown")

  if [ "$ssh_active" != "active" ]; then
    log "CRITICAL: SSH service is $ssh_active — restarting"
    notify "ALERT: SSH service was $ssh_active — restarting..."
    sudo systemctl restart ssh 2>/dev/null || true

    sleep 3
    ssh_active=$(systemctl is-active ssh 2>/dev/null || echo "unknown")
    if [ "$ssh_active" = "active" ]; then
      notify "SSH service recovered."
    else
      notify "CRITICAL: SSH restart FAILED. VPS may become unreachable!"
    fi
  else
    log "SSH: active"
  fi
}

# --- Main ---
log "=== Self-heal check started ==="

check_memory
check_disk
check_docker
check_load
check_swap
check_ssh

log "=== Self-heal check complete ==="

# Trim log file if too large
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 10485760 ]; then
  tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
