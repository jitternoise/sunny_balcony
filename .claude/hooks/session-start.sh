#!/bin/bash
# SessionStart hook for Claude Code on the web: installs a headless Godot
# matching game/project.godot's feature version so scripts can be
# compiled and scenes run without a display. No-op outside the web env.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.6-stable"
GODOT_BIN="/usr/local/bin/godot"

if ! "$GODOT_BIN" --version 2>/dev/null | grep -q "^4\.6\."; then
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -qo "$tmp/godot.zip" -d "$tmp"
  install -m 755 "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
  rm -rf "$tmp"
fi

# Import the project once so .godot/ (resource cache, .import files) exists;
# a scene run without this fails on missing imported assets.
cd "$CLAUDE_PROJECT_DIR/game"
timeout 300 "$GODOT_BIN" --headless --import . >/dev/null 2>&1 || true

echo "Godot $("$GODOT_BIN" --version) ready"
