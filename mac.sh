#!/usr/bin/env bash
set -euo pipefail

echo "==> macOS dotfiles setup"

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$DOTFILES_DIR/.backup/$(date '+%Y%m%d_%H%M%S')"

# --- Backup existing configs ---
echo "==> Backing up existing configs to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

[ -f "$HOME/.zshrc" ]                && cp "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
[ -f "$HOME/.bashrc" ]               && cp "$HOME/.bashrc" "$BACKUP_DIR/.bashrc"
[ -f "$HOME/.config/starship.toml" ] && cp "$HOME/.config/starship.toml" "$BACKUP_DIR/starship.toml"

# Save current macOS defaults we're going to change
cat > "$BACKUP_DIR/macos_defaults.sh" << 'DEFAULTS_BACKUP'
#!/usr/bin/env bash
# Restore macOS defaults to pre-dotfiles state
DEFAULTS_BACKUP

for key in \
  "com.apple.finder AppleShowAllFiles" \
  "NSGlobalDomain AppleShowAllExtensions" \
  "com.apple.finder ShowPathbar" \
  "com.apple.finder ShowStatusBar" \
  "com.apple.finder FXDefaultSearchScope" \
  "NSGlobalDomain ApplePressAndHoldEnabled" \
  "NSGlobalDomain KeyRepeat" \
  "NSGlobalDomain InitialKeyRepeat" \
  "com.apple.screencapture location" \
  "com.apple.desktopservices DSDontWriteNetworkStores" \
  "com.apple.desktopservices DSDontWriteUSBStores" \
  "com.apple.menuextra.battery ShowPercent" \
  "com.apple.dock autohide" \
  "com.apple.dock tilesize" \
  "com.apple.dock show-recents" \
  "com.apple.dock minimize-to-application"; do
  domain=$(echo "$key" | cut -d' ' -f1)
  prop=$(echo "$key" | cut -d' ' -f2)
  val=$(defaults read "$domain" "$prop" 2>/dev/null) && \
    echo "defaults write $domain $prop '$val'" >> "$BACKUP_DIR/macos_defaults.sh" || \
    echo "defaults delete $domain $prop 2>/dev/null || true" >> "$BACKUP_DIR/macos_defaults.sh"
done

echo "  Backup saved."

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Updating Homebrew and installing packages..."
brew update

# Core CLI tools
BREW_PACKAGES=(
  # Better alternatives to built-ins
  eza           # modern ls
  bat           # modern cat with syntax highlighting
  fd            # modern find
  fzf           # fuzzy finder
  zoxide        # smarter cd
  ripgrep       # fast grep (you already have this)
  delta         # better git diffs
  tldr          # simplified man pages

  # Shell & terminal
  tmux          # terminal multiplexer
  starship      # cross-shell prompt
  neovim        # editor

  # Utilities
  htop          # process viewer (you already have this)
  jq            # JSON processor (you already have this)
  yq            # YAML processor
  tree          # directory tree viewer
  watch         # run commands periodically
  wget          # download files
  trash         # safe rm alternative (moves to Trash)
  duf           # better df (disk usage)
  dust          # better du (directory size)
  procs         # better ps
)

# for pkg in "${BREW_PACKAGES[@]}"; do
#   brew install "$pkg" 2>/dev/null || true
# done

# Set up fzf key bindings
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish 2>/dev/null || true

# --- macOS Defaults ---
echo "==> Setting macOS defaults..."

# Finder: show hidden files, extensions, path bar
# defaults write com.apple.finder AppleShowAllFiles -bool true
# defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# defaults write com.apple.finder ShowPathbar -bool true
# defaults write com.apple.finder ShowStatusBar -bool true

# Finder: search current folder by default
# defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable press-and-hold for keys in favor of key repeat
# defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Save screenshots to ~/Screenshots
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"

# Avoid creating .DS_Store files on network and USB volumes
# (requires Full Disk Access for Terminal — skipped if it fails)
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true 2>/dev/null || echo "  Skipped DSDontWriteNetworkStores (needs Full Disk Access)"
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true 2>/dev/null || echo "  Skipped DSDontWriteUSBStores (needs Full Disk Access)"

# Show battery percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

# Dock: auto-hide, minimize size, no recent apps
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true

# --- Remap Caps Lock to Tab ---
echo "==> Remapping Caps Lock to Tab..."

# Apply immediately
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000002B}]}' >/dev/null

# Persist across reboots via LaunchAgent
PLIST="$HOME/Library/LaunchAgents/com.dotfiles.capslock-to-tab.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" << 'CAPSLOCK'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dotfiles.capslock-to-tab</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000002B}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
CAPSLOCK

echo "  Caps Lock → Tab (persists across reboots)"

# --- Starship Config ---
echo "==> Installing Starship config..."
mkdir -p "$HOME/.config"
cat > "$HOME/.config/starship.toml" << 'STARSHIP'
# Minimal prompt: dirname (branch) $
format = "$directory$git_branch$git_status$character"

[directory]
truncation_length = 1
truncate_to_repo = false
style = "bold blue"

[git_branch]
format = "[$branch]($style) "
style = "dim white"

[git_status]
format = "[$all_status$ahead_behind]($style) "
style = "red"

[character]
success_symbol = "[\\$](white)"
error_symbol = "[\\$](red)"

[aws]
disabled = true
[gcloud]
disabled = true
[package]
disabled = true
[nodejs]
disabled = true
[python]
disabled = true
[ruby]
disabled = true
[rust]
disabled = true
[golang]
disabled = true
[docker_context]
disabled = true
[cmd_duration]
disabled = true
STARSHIP

# --- Shell Profile ---
echo "==> Installing shell profile..."

PROFILE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE_SOURCE="$PROFILE_DIR/profile.sh"

# Create profile.sh alongside this script
cat > "$PROFILE_SOURCE" << 'PROFILE'
# ============================================
# Quality-of-life shell profile (sourced by .zshrc / .bashrc)
# ============================================

# --- Better defaults ---
export EDITOR="nvim"
export VISUAL="nvim"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# History (zsh)
if [ -n "$ZSH_VERSION" ]; then
  HISTSIZE=100000
  SAVEHIST=100000
  HISTFILE=~/.zsh_history
  setopt HIST_IGNORE_ALL_DUPS   # no duplicate entries
  setopt HIST_SAVE_NO_DUPS
  setopt HIST_REDUCE_BLANKS
  setopt SHARE_HISTORY           # share history across sessions
  setopt INC_APPEND_HISTORY      # write immediately, not on exit
  setopt AUTO_CD                 # cd by typing directory name
  setopt CORRECT                 # suggest corrections for typos
fi

# --- Modern tool replacements ---
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -la --group-directories-first --git'
  alias lt='eza --tree --level=2'
fi

if command -v bat &>/dev/null; then
  alias cat='bat --paging=never --style=plain'
  alias catp='bat'  # cat with full pager/line numbers
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

if command -v fd &>/dev/null; then
  alias find='fd'
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init "$(basename "$SHELL")")"
  alias cd='z'
fi

if command -v delta &>/dev/null; then
  export GIT_PAGER="delta"
fi

# fzf
if command -v fzf &>/dev/null; then
  # Use fd for fzf if available
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  fi
  export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline'

  # Source fzf shell integration
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  [ -f ~/.fzf.bash ] && source ~/.fzf.bash
fi

# Starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init "$(basename "$SHELL")")"
fi

# --- Git aliases ---
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all'
alias gpull='git pull'
alias gpush='git push'
alias gmain='git checkout main'
alias gprune='git fetch origin --prune'

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# --- Safety ---
alias rm='trash'   # use trash instead of rm (brew install trash)
alias cp='cp -i'
alias mv='mv -i'

# --- Handy functions ---

# Create and cd into directory
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract any archive
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.tar.xz)  tar xJf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.tar)     tar xf "$1" ;;
      *.tbz2)    tar xjf "$1" ;;
      *.tgz)     tar xzf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.7z)      7z x "$1" ;;
      *)         echo "'$1' cannot be extracted" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Quick HTTP server in current directory
serve() { python3 -m http.server "${1:-8000}"; }

# Show top 10 most used commands
topcmd() {
  history | awk '{print $2}' | sort | uniq -c | sort -rn | head -10
}

# Quick note (appends to ~/notes.md)
note() {
  echo "$(date '+%Y-%m-%d %H:%M') — $*" >> ~/notes.md
  echo "Noted."
}

# Port usage lookup
port() { lsof -i :"$1"; }

# --- PATH additions (idempotent) ---
_add_to_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

_add_to_path "$HOME/.local/bin"
_add_to_path "/opt/homebrew/bin"
PROFILE

echo "==> Adding source line to shell configs..."

SOURCE_LINE="# Dotfiles profile"
SOURCE_CMD="[ -f \"$PROFILE_SOURCE\" ] && source \"$PROFILE_SOURCE\""

add_source_line() {
  local rc_file="$1"
  if [ -f "$rc_file" ]; then
    if ! grep -qF "source \"$PROFILE_SOURCE\"" "$rc_file" 2>/dev/null; then
      echo "" >> "$rc_file"
      echo "$SOURCE_LINE" >> "$rc_file"
      echo "$SOURCE_CMD" >> "$rc_file"
      echo "  Added to $rc_file"
    else
      echo "  Already in $rc_file"
    fi
  fi
}

add_source_line "$HOME/.zshrc"
add_source_line "$HOME/.bashrc"

# --- Restart affected services ---
echo "==> Restarting Finder and Dock to apply settings..."
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

echo ""
echo "==> Done! Restart your terminal or run: source $PROFILE_SOURCE"
