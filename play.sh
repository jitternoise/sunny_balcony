#!/usr/bin/env bash
# Flash Flood launcher: pull the latest commits, then run the game (or open the editor).
#
#   ./play.sh              update, then play
#   ./play.sh --editor     update, then open the Godot editor
#   ./play.sh --no-update  skip the git pull
#   ./play.sh --reimport   force a full asset reimport
#
# Meant to be double-clicked via the .desktop files in launchers/, so all
# messaging goes through desktop notifications and zenity dialogs, not stdout.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$REPO/game"

EDITOR_MODE=0
DO_UPDATE=1
NEEDS_IMPORT=0
for arg in "$@"; do
  case "$arg" in
    --editor)    EDITOR_MODE=1 ;;
    --no-update) DO_UPDATE=0 ;;
    --reimport)  NEEDS_IMPORT=1 ;;
  esac
done

say()  { command -v notify-send >/dev/null && notify-send -a "Flash Flood" -i "$REPO/icons/icon_source.svg" "Flash Flood" "$1"; }
die()  { command -v zenity >/dev/null && zenity --error --title="Flash Flood" --width=420 --text="$1"; exit 1; }
ask()  { command -v zenity >/dev/null && zenity --question --title="Flash Flood" --width=420 --text="$1"; }

# --- find Godot -------------------------------------------------------------
# Override with:  export GODOT=/path/to/godot
find_godot() {
  [[ -n "${GODOT:-}" && -x "${GODOT:-}" ]] && { echo "$GODOT"; return; }
  local c newest
  # Newest version wins when several are lying around (4.10 > 4.7, so sort -V).
  newest="$(for c in "$HOME"/Desktop/Godot_v4.*-stable_linux.x86_64 \
                     "$HOME"/Godot_v4.*-stable_linux.x86_64 \
                     "$HOME"/Applications/Godot_v4.*-stable_linux.x86_64; do
              [[ -x "$c" ]] && echo "$c"
            done | sort -V | tail -n 1)"
  [[ -n "$newest" ]] && { echo "$newest"; return; }
  for c in godot4 godot; do
    command -v "$c" >/dev/null && { command -v "$c"; return; }
  done
}
GODOT_BIN="$(find_godot | tail -n 1)"
[[ -x "$GODOT_BIN" ]] || die "Couldn't find the Godot editor.\n\nExpected something like:\n$HOME/Desktop/Godot_v4.7.2-stable_linux.x86_64\n\nDownload Godot 4 and drop the binary there, or set GODOT=/path/to/godot."

# --- update -----------------------------------------------------------------
if [[ "$DO_UPDATE" == 1 ]]; then
  cd "$REPO" || die "Can't open $REPO"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    say "Branch '$branch' has no remote — playing your local copy."
  else
    before="$(git rev-parse HEAD)"
    say "Checking for updates…"
    # BatchMode so a missing/locked SSH key fails fast instead of hanging on a
    # password prompt no one can see.
    out="$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' \
           timeout 90 git pull --ff-only 2>&1)"
    if [[ $? -ne 0 ]]; then
      ask "Couldn't download the latest version:\n\n<tt>$(echo "$out" | tail -n 4 | sed 's/&/\&amp;/g; s/</\&lt;/g')</tt>\n\nPlay the version already on this computer?" || exit 1
    else
      after="$(git rev-parse HEAD)"
      if [[ "$before" != "$after" ]]; then
        say "Updated — $(git rev-list --count "$before..$after") new change(s) on $branch."
        NEEDS_IMPORT=1
      fi
    fi
  fi
fi

# --- import -----------------------------------------------------------------
# Running a project with --path does NOT import assets; only the editor does.
# So a fresh clone, or a pull that added art, needs an import pass first or the
# game boots with missing-texture errors. ~4s, so only when something changed.
if [[ ! -d "$PROJECT/.godot/imported" ]]; then
  NEEDS_IMPORT=1
fi
if [[ "$NEEDS_IMPORT" == 1 ]]; then
  say "Preparing artwork…"
  "$GODOT_BIN" --headless --import --path "$PROJECT" >/dev/null 2>&1
fi

# --- launch -----------------------------------------------------------------
cd "$REPO" || exit 1
if [[ "$EDITOR_MODE" == 1 ]]; then
  exec "$GODOT_BIN" --editor --path "$PROJECT"
else
  exec "$GODOT_BIN" --path "$PROJECT"
fi
