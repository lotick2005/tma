#!/usr/bin/env bash
# Скачивает официальный Godot (Linux x86_64) версии из .godot-version в .tools/
# и печатает путь к бинарнику. Нужен в облаке (claude.ai/code) и в GitHub Actions.
#
#   ./tools/get_godot.sh              — только Godot
#   ./tools/get_godot.sh --templates  — ещё и шаблоны веб-экспорта (для сборки в браузер)
#
# Godot работает в self-contained режиме (файл _sc_ рядом с бинарником),
# поэтому настройки и шаблоны лежат в .tools/editor_data, а не в домашней папке.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$(tr -d '[:space:]' < .godot-version)"   # например 4.7.2-stable
TOOLS=".tools"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}"

mkdir -p "$TOOLS"

if [ ! -x "$TOOLS/godot" ]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" "$BASE/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -q -o "$tmp/godot.zip" -d "$tmp"
  mv "$tmp/Godot_v${VERSION}_linux.x86_64" "$TOOLS/godot"
  chmod +x "$TOOLS/godot"
  touch "$TOOLS/_sc_"
  rm -rf "$tmp"
fi

if [ "${1:-}" = "--templates" ]; then
  # Папка шаблонов называется по templates/version.txt, например 4.7.2.stable
  TVER="${VERSION/-/.}"
  TDIR="$TOOLS/editor_data/export_templates/$TVER"
  if [ ! -f "$TDIR/web_nothreads_release.zip" ]; then
    tmp="$(mktemp -d)"
    # Архив весит больше гигабайта, но нужны из него только веб-шаблоны
    curl -fsSL -o "$tmp/templates.tpz" "$BASE/Godot_v${VERSION}_export_templates.tpz"
    unzip -q -o "$tmp/templates.tpz" 'templates/web_nothreads_*' 'templates/version.txt' -d "$tmp"
    TVER="$(tr -d '[:space:]' < "$tmp/templates/version.txt")"
    TDIR="$TOOLS/editor_data/export_templates/$TVER"
    mkdir -p "$TDIR"
    mv "$tmp"/templates/* "$TDIR"/
    rm -rf "$tmp"
  fi
fi

echo "$TOOLS/godot"
