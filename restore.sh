#!/usr/bin/env bash
# Restore niri + DankMaterialShell (DMS) preferences on a fresh/rebuilt machine.
#
#   git clone https://github.com/jhnhnsn/niri-config.git ~/niri-config
#   cd ~/niri-config && ./restore.sh
#
# Safe to re-run: it backs up anything it overwrites to <path>.bak.<timestamp>.
# It does NOT touch per-machine files (dms/outputs.kdl, local.kdl) if you already
# have them — they are intentionally not tracked in this repo.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
NIRI_DST="$HOME/.config/niri"
DMS_DST="$HOME/.config/DankMaterialShell"

backup() { [ -e "$1" ] && cp -a "$1" "$1.bak.$STAMP" && echo "  backed up $1 -> $1.bak.$STAMP" || true; }

echo "==> Restoring niri config to $NIRI_DST"
mkdir -p "$NIRI_DST/dms"
backup "$NIRI_DST/config.kdl"
cp "$REPO_DIR/niri/config.kdl" "$NIRI_DST/config.kdl"
for f in "$REPO_DIR"/niri/dms/*.kdl; do
  name="$(basename "$f")"
  backup "$NIRI_DST/dms/$name"
  cp "$f" "$NIRI_DST/dms/$name"
done

# Per-machine: config.kdl includes dms/outputs.kdl, but monitor layout differs
# per machine, so it is not tracked. Keep an existing one; otherwise create an
# empty file (niri then auto-detects outputs). Configure it later with `niri msg outputs`.
if [ ! -f "$NIRI_DST/dms/outputs.kdl" ]; then
  : > "$NIRI_DST/dms/outputs.kdl"
  echo "  created empty $NIRI_DST/dms/outputs.kdl (niri auto-detects; customize per machine)"
else
  echo "  kept existing $NIRI_DST/dms/outputs.kdl (per-machine; not overwritten)"
fi

# Per-machine: config.kdl includes local.kdl last, for machine-specific settings
# (e.g. render-drm-device on a hybrid-GPU laptop). Same rule as outputs.kdl.
if [ ! -f "$NIRI_DST/local.kdl" ]; then
  : > "$NIRI_DST/local.kdl"
  echo "  created empty $NIRI_DST/local.kdl (per-machine overrides)"
else
  echo "  kept existing $NIRI_DST/local.kdl (per-machine; not overwritten)"
fi

echo "==> Restoring DMS settings to $DMS_DST"
mkdir -p "$DMS_DST"
backup "$DMS_DST/settings.json"
cp "$REPO_DIR/dankshell/settings.json" "$DMS_DST/settings.json"

echo "==> Restoring Ghostty config to $HOME/.config/ghostty"
mkdir -p "$HOME/.config/ghostty"
backup "$HOME/.config/ghostty/config"
cp "$REPO_DIR/ghostty/config" "$HOME/.config/ghostty/config"

echo "==> Restoring herdr config to $HOME/.config/herdr"
mkdir -p "$HOME/.config/herdr"
backup "$HOME/.config/herdr/config.toml"
cp "$REPO_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"

echo "==> Validating niri config"
if command -v niri >/dev/null 2>&1; then
  niri validate -c "$NIRI_DST/config.kdl" 2>&1 | grep -iE 'valid|error' || true
else
  echo "  (niri not found; skipped)"
fi

echo "==> Enabling DMS service (canonical autostart)"
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user enable dms.service 2>&1 || echo "  (could not enable; is the dms package installed?)"
  # Start now only if a graphical session is active; harmless otherwise.
  systemctl --user start dms.service 2>&1 || true
else
  echo "  (systemctl not found; skipped)"
fi

echo
echo "Done. If niri is already running, it hot-reloads the config."
echo "Otherwise everything takes effect on your next login."
