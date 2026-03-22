# Upgrading claude-super-setup

## v1.0.0 (Initial Release)

This is the first release. No migration needed.

### If upgrading from a manual ~/.claude/ setup:

1. Back up your existing config: `cp -r ~/.claude ~/.claude-manual-backup`
2. Run the installer: `./install.sh` (creates automatic backup too)
3. Copy personal settings to `~/.claude/settings.local.json`
4. Verify: restart Claude Code and check that commands/hooks work

### What moves to settings.local.json:

- `skipDangerousModePermissionPrompt` (personal preference)
- Custom `CLAUDE_CODE_ENABLE_TELEMETRY` settings
- Any personal `OTEL_METRICS_EXPORTER` config
- Machine-specific paths or tokens
