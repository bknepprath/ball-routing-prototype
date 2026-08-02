#!/usr/bin/env bash
set -euo pipefail

version=4.5.1
bin="$HOME/.local/bin/godot"
if [[ ! -x "$bin" ]] || [[ "$($bin --version)" != "$version"* ]]; then
  mkdir -p "$HOME/.local/bin"
  archive="$(mktemp)"
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip" -o "$archive"
  unzip -qo "$archive" -d "$HOME/.local/bin"
  mv "$HOME/.local/bin/Godot_v${version}-stable_linux.x86_64" "$bin"
  chmod +x "$bin"
  rm -f "$archive"
fi
sudo ln -sf "$bin" /usr/local/bin/godot
