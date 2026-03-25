#!/usr/bin/env bash
set -euo pipefail

# Darwin Cron Setup — registers daily scan and weekly deep analysis schedules
# Usage: bash scripts/darwin/setup-cron.sh [--project-dir <path>]

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[DARWIN-CRON]${NC} $1"; }
warn() { echo -e "${YELLOW}[DARWIN-CRON]${NC} $1"; }
info() { echo -e "${CYAN}[DARWIN-CRON]${NC} $1"; }

PROJECT_DIR="${1:-$(pwd)}"

# Detect environment
IS_VPS=false
if [[ "$(uname)" != "Darwin" ]] && command -v systemctl &>/dev/null; then
  IS_VPS=true
fi

echo ""
echo "========================================="
echo "  Darwin Cron Setup"
echo "========================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Environment: $(if $IS_VPS; then echo 'VPS (Linux/systemd)'; else echo 'Mac (launchd)'; fi)"
echo ""

if $IS_VPS; then
  # --- VPS: systemd timer ---
  log "Generating systemd timer for VPS..."

  TIMER_DIR="$HOME/.config/systemd/user"
  mkdir -p "$TIMER_DIR"

  # Daily scan timer
  cat > "$TIMER_DIR/darwin-scan.timer" <<EOF
[Unit]
Description=Darwin daily scan (6:00 AM)

[Timer]
OnCalendar=*-*-* 06:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

  cat > "$TIMER_DIR/darwin-scan.service" <<EOF
[Unit]
Description=Darwin daily scan

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/hooks/telegram-dispatch-runner.sh darwin scan $PROJECT_DIR cron-darwin-scan-\$(date +%%s) \$(jq -r '.allowFrom[0] // ""' $HOME/.claude/channels/telegram/access.json 2>/dev/null || echo "")
Environment=HOME=$HOME
EOF

  # Weekly deep timer
  cat > "$TIMER_DIR/darwin-deep.timer" <<EOF
[Unit]
Description=Darwin weekly deep analysis (5:00 AM Sunday)

[Timer]
OnCalendar=Sun *-*-* 05:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

  cat > "$TIMER_DIR/darwin-deep.service" <<EOF
[Unit]
Description=Darwin weekly deep analysis

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/hooks/telegram-dispatch-runner.sh darwin deep $PROJECT_DIR cron-darwin-deep-\$(date +%%s) \$(jq -r '.allowFrom[0] // ""' $HOME/.claude/channels/telegram/access.json 2>/dev/null || echo "")
Environment=HOME=$HOME
EOF

  log "Timer files created. To enable:"
  echo ""
  info "  systemctl --user daemon-reload"
  info "  systemctl --user enable --now darwin-scan.timer"
  info "  systemctl --user enable --now darwin-deep.timer"
  echo ""
  info "  # Verify:"
  info "  systemctl --user list-timers | grep darwin"

else
  # --- Mac: Use Telegram cron commands ---
  log "Darwin cron commands for Mac (run these in Claude):"
  echo ""
  info "  /telegram-cron add \"6am daily: /darwin scan\""
  info "  /telegram-cron add \"5am sunday: /darwin deep\""
  echo ""
  log "Or use CronCreate MCP tool directly in a Claude session."
  echo ""
  log "Alternative: launchd plists (if you prefer native macOS scheduling)"

  PLIST_DIR="$HOME/Library/LaunchAgents"

  cat > "$PLIST_DIR/com.darwin.daily-scan.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.darwin.daily-scan</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/hooks/telegram-dispatch-runner.sh</string>
        <string>darwin</string>
        <string>scan</string>
        <string>$PROJECT_DIR</string>
        <string>cron-darwin-scan</string>
        <string>8328233140</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>6</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    <key>StandardOutPath</key>
    <string>$HOME/.claude/logs/darwin-scan.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.claude/logs/darwin-scan-error.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

  cat > "$PLIST_DIR/com.darwin.weekly-deep.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.darwin.weekly-deep</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/hooks/telegram-dispatch-runner.sh</string>
        <string>darwin</string>
        <string>deep</string>
        <string>$PROJECT_DIR</string>
        <string>cron-darwin-deep</string>
        <string>8328233140</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>5</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    <key>StandardOutPath</key>
    <string>$HOME/.claude/logs/darwin-deep.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.claude/logs/darwin-deep-error.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

  log "launchd plists created. To enable:"
  echo ""
  info "  launchctl load $PLIST_DIR/com.darwin.daily-scan.plist"
  info "  launchctl load $PLIST_DIR/com.darwin.weekly-deep.plist"
  echo ""
  info "  # Verify:"
  info "  launchctl list | grep darwin"
fi

echo ""
log "Setup complete."
