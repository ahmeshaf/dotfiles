#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="$DOTFILES_DIR/.backup"

# Find the most recent backup
if [ ! -d "$BACKUP_ROOT" ]; then
  echo "No backups found in $BACKUP_ROOT. Nothing to revert."
  exit 1
fi

LATEST_BACKUP=$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort | tail -1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "No backups found. Nothing to revert."
  exit 1
fi

echo "==> Reverting to backup: $LATEST_BACKUP"

# --- Restore shell configs ---
for rc in .zshrc .bashrc; do
  if [ -f "$LATEST_BACKUP/$rc" ]; then
    cp "$LATEST_BACKUP/$rc" "$HOME/$rc"
    echo "  Restored ~/$rc"
  fi
done

# --- Restore starship config ---
if [ -f "$LATEST_BACKUP/starship.toml" ]; then
  cp "$LATEST_BACKUP/starship.toml" "$HOME/.config/starship.toml"
  echo "  Restored ~/.config/starship.toml"
else
  rm -f "$HOME/.config/starship.toml"
  echo "  Removed ~/.config/starship.toml (didn't exist before)"
fi

# --- Restore macOS defaults ---
if [ -f "$LATEST_BACKUP/macos_defaults.sh" ]; then
  echo "  Restoring macOS defaults..."
  bash "$LATEST_BACKUP/macos_defaults.sh"
  killall Finder 2>/dev/null || true
  killall Dock 2>/dev/null || true
  echo "  macOS defaults restored."
fi

# --- Restore Caps Lock ---
PLIST="$HOME/Library/LaunchAgents/com.dotfiles.capslock-to-tab.plist"
if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  hidutil property --set '{"UserKeyMapping":[]}' >/dev/null
  echo "  Restored Caps Lock to default"
fi

# --- Remove generated profile.sh ---
if [ -f "$DOTFILES_DIR/profile.sh" ]; then
  rm "$DOTFILES_DIR/profile.sh"
  echo "  Removed profile.sh"
fi

echo ""
echo "==> Reverted. Restart your terminal for changes to take effect."
