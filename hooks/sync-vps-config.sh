#!/bin/bash
# Auto-sync Claude config from MAC to VPS after any settings change
# Triggered manually or by cron

VPS_IP="187.77.15.168"
VPS_PASS="7c8;mnJ9Fn3d5FXP"
SSH_CMD="sshpass -p '$VPS_PASS' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$VPS_IP"

# Sync settings.json
scp -o StrictHostKeyChecking=no ~/.claude/settings.json root@$VPS_IP:/home/claude/.claude/settings.json 2>/dev/null
# Sync settings.local.json
scp -o StrictHostKeyChecking=no ~/.claude/settings.local.json root@$VPS_IP:/home/claude/.claude/settings.local.json 2>/dev/null
# Fix ownership
$SSH_CMD "chown claude:claude /home/claude/.claude/settings.json /home/claude/.claude/settings.local.json" 2>/dev/null

echo "Config synced to VPS"
