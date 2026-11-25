#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../git/setup.sh
source "$ROOT/git/setup.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Isolierte Umgebung: nur die Dotfiles-Konfiguration zählt.
export HOME="$tmp/home"
export GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL
mkdir -p "$HOME/.claude"

fail() { printf 'git-config: %s\n' "$*" >&2; exit 1; }

repo_hash() { sha256sum "$ROOT/git/config" | cut -d' ' -f1; }
before="$(repo_hash)"

dotfiles_git_setup "$ROOT/git/config"
dotfiles_git_setup "$ROOT/git/config"   # idempotent
[[ "$(git config --file "$HOME/.config/git/config" --get-all include.path | grep -cxF "$ROOT/git/config")" == 1 ]] \
  || fail "include nicht genau einmal eingetragen"

# 1. Ohne private Datei darf Git keine Identität raten.
if git var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
  fail "ohne ~/.claude/.gitconfig.local wurde eine Identität geraten"
fi

# 2. Die private Datei liefert die Identität.
printf '[user]\n\tname = Test User\n\temail = test@example.invalid\n' > "$HOME/.claude/.gitconfig.local"
ident="$(git var GIT_AUTHOR_IDENT)"
[[ "$ident" == "Test User <test@example.invalid> "* ]] || fail "unerwartete Identität: $ident"

# 3. Globale Schreibzugriffe (z. B. gh auth setup-git) landen lokal, nie im Repository.
git config --global credential.helper '!test-helper'
[[ "$(repo_hash)" == "$before" ]] || fail "git config --global hat git/config im Repository verändert"
[[ "$(git config credential.helper)" == '!test-helper' ]] || fail "globaler Wert nicht wirksam"

# 4. Ein Link aus einer älteren Installation wird ersetzt, lokale Werte bleiben.
rm "$HOME/.config/git/config"
ln -s "$ROOT/git/config" "$HOME/.config/git/config"
dotfiles_git_setup "$ROOT/git/config"
[[ ! -L "$HOME/.config/git/config" ]] || fail "alter Link wurde nicht ersetzt"
[[ "$(repo_hash)" == "$before" ]] || fail "Migration hat git/config im Repository verändert"

# 5. Eine vorhandene ~/.gitconfig (z. B. von VS Code kopiert) hat Vorrang.
printf '[user]\n\temail = host@example.invalid\n' > "$HOME/.gitconfig"
ident="$(git var GIT_AUTHOR_IDENT)"
[[ "$ident" == "Test User <host@example.invalid> "* ]] || fail "~/.gitconfig hat keinen Vorrang: $ident"

printf 'Git identity config tests passed.\n'
