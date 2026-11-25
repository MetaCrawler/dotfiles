#!/usr/bin/env bash
# Wird von install.sh und tests/git-config.sh eingebunden.
#
# ~/.config/git/config bleibt eine lokale Datei und bindet die öffentliche
# git/config nur per include ein. Ein Link wäre bequemer, aber dann schreiben
# `git config --global` und Werkzeuge wie `gh auth setup-git` direkt in dieses
# öffentliche Repository.

dotfiles_git_setup() {
  local public="$1" target="$HOME/.config/git/config" migrated=""
  mkdir -p "$(dirname "$target")"

  # Link aus einer älteren Installation: durch eine lokale Datei ersetzen.
  if [[ -L "$target" ]]; then
    rm "$target"
    migrated=1
  fi
  [[ -f "$target" ]] || (umask 077 && : > "$target")

  if ! git config --file "$target" --get-all include.path 2>/dev/null | grep -qxF "$public"; then
    git config --file "$target" --add include.path "$public"
  fi
  [[ -n "$migrated" ]] && printf 'migriert: %s ist jetzt eine lokale Datei\n' "$target"
  return 0
}
