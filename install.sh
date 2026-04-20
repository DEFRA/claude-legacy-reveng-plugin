#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${REVENG_BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${REVENG_CONFIG_DIR:-$HOME/.config/reveng}"
PLUGIN_DIR="$CONFIG_DIR/plugin"
CONTAINER_DIR="$CONFIG_DIR/container"

# ── Usage ───────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
Usage: install.sh [--update] [-h|--help]

Installs the reveng CLI and plugin content.

Destinations:
  ~/.local/bin/reveng              CLI script (override with REVENG_BIN_DIR)
  ~/.config/reveng/plugin/         Plugin content (override with REVENG_CONFIG_DIR)
  ~/.config/reveng/container/      Devcontainer files

Options:
  --update    Overwrite existing installation without prompting
  -h, --help  Show this help message
EOF
}

# ── Flag parsing ────────────────────────────────────────────────────────────

UPDATE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      UPDATE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ── Prerequisite checks ────────────────────────────────────────────────────

errors=0

if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found on PATH." >&2
  echo "Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code" >&2
  errors=1
fi

bash_version="${BASH_VERSINFO[0]}"
if (( bash_version < 4 )); then
  echo "Error: Bash 4+ is required (found Bash $bash_version)." >&2
  errors=1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' not found on PATH." >&2
  echo "Install jq: https://jqlang.github.io/jq/download/" >&2
  errors=1
fi

if (( errors )); then
  echo "" >&2
  echo "Please install the missing prerequisites and try again." >&2
  exit 1
fi

# ── Already-installed check ─────────────────────────────────────────────────

if [[ "$UPDATE" == "false" ]]; then
  if [[ -f "$BIN_DIR/reveng" || -d "$PLUGIN_DIR" || -d "$CONTAINER_DIR" ]]; then
    echo "reveng is already installed." >&2
    echo "Use --update to overwrite the existing installation:" >&2
    echo "  ./install.sh --update" >&2
    exit 1
  fi
fi

# ── Source file checks ──────────────────────────────────────────────────────

if [[ ! -f "$SCRIPT_DIR/reveng" ]]; then
  echo "Error: 'reveng' script not found in $SCRIPT_DIR" >&2
  exit 1
fi

# ── Install ─────────────────────────────────────────────────────────────────

echo "Installing reveng..."

# CLI binary
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/reveng" "$BIN_DIR/reveng"
chmod +x "$BIN_DIR/reveng"
echo "  Installed CLI to $BIN_DIR/reveng"

# Plugin content
mkdir -p "$PLUGIN_DIR"

# Copy plugin directories
for dir in skills agents hooks .claude-plugin; do
  if [[ -d "$SCRIPT_DIR/$dir" ]]; then
    # Remove existing directory content to ensure clean copy
    rm -rf "${PLUGIN_DIR:?}/$dir"
    cp -r "$SCRIPT_DIR/$dir" "$PLUGIN_DIR/$dir"
  fi
done

# Copy CLAUDE.md
if [[ -f "$SCRIPT_DIR/CLAUDE.md" ]]; then
  cp "$SCRIPT_DIR/CLAUDE.md" "$PLUGIN_DIR/CLAUDE.md"
fi

echo "  Installed plugin content to $PLUGIN_DIR/"

# Container files
mkdir -p "$CONTAINER_DIR"
for file in Dockerfile devcontainer.json; do
  if [[ -f "$SCRIPT_DIR/container/$file" ]]; then
    cp "$SCRIPT_DIR/container/$file" "$CONTAINER_DIR/$file"
  fi
done
echo "  Installed container config to $CONTAINER_DIR/"

# ── PATH check ──────────────────────────────────────────────────────────────

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "Note: $BIN_DIR is not in your PATH."
  echo "Add it to your shell profile:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

echo ""
echo "Done. Run 'reveng version' to verify the installation."
