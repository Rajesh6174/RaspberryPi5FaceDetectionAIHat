#!/usr/bin/env bash
# Setup for Raspberry Pi 5 + AI HAT+ 2 (Hailo-10H) face detection.
# Run from inside a clone of this repo, as the normal user (not root):
#   git clone <repo-url> ~/.local/share/face-detect-aihat
#   cd ~/.local/share/face-detect-aihat
#   ./install.sh
#
# UNTESTED ON PHYSICAL HARDWARE - see README.md/SETUP.md for why, and
# please open an issue with what happened if any step here doesn't match
# reality on your actual board.
#
# Idempotent where possible - safe to re-run.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/face-detect-aihat"
UNIT_DIR="$HOME/.config/systemd/user"
HAILO_APPS_DIR="$HOME/.local/share/hailo-apps"

echo "==> Installing DKMS (required before the Hailo packages on Trixie)"
sudo apt-get update
sudo apt-get install -y dkms

echo "==> Installing the AI HAT+ 2 (Hailo-10H) package: hailo-h10-all"
echo "    NOTE: this is deliberately NOT 'hailo-all' - that's for the"
echo "    original AI HAT+ (Hailo-8/8L) and cannot coexist with hailo-h10-all."
sudo apt-get install -y hailo-h10-all git

echo
echo "==> A reboot is required before the Hailo device will be usable."
echo "    After rebooting, verify with:"
echo "        hailortcli fw-control identify"
echo "        dmesg | grep -i hailo"
echo "    If either of those doesn't show the device, see SETUP.md's"
echo "    troubleshooting section before continuing."
echo

echo "==> Cloning hailo-apps (Hailo's own official app repo) to $HAILO_APPS_DIR"
if [ ! -d "$HAILO_APPS_DIR" ]; then
    git clone https://github.com/hailo-ai/hailo-apps.git "$HAILO_APPS_DIR"
else
    echo "    $HAILO_APPS_DIR already exists, leaving it alone (git pull it yourself to update)"
fi

echo "==> Running hailo-apps' own install script"
(cd "$HAILO_APPS_DIR" && ./install.sh --all)

echo "==> Setting up config directory: $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/detect.env" ]; then
    cp "$REPO_DIR/config/detect.env.example" "$CONFIG_DIR/detect.env"
    echo "    created $CONFIG_DIR/detect.env from template - edit CAMERA_SOURCE if not using a USB webcam"
else
    echo "    $CONFIG_DIR/detect.env already exists, leaving it alone"
fi

echo "==> Installing the systemd user unit (not starting it yet - see next steps)"
mkdir -p "$UNIT_DIR"
cp "$REPO_DIR/systemd/face-detect.service" "$UNIT_DIR/"
systemctl --user daemon-reload

echo "==> Enabling lingering (service can survive logout/reboot without login, once started)"
sudo loginctl enable-linger "$USER"

echo
echo "============================================================"
echo "Next steps:"
echo "  1. Reboot now if you haven't since installing hailo-h10-all: sudo reboot"
echo "  2. Verify the Hailo device is detected:"
echo "       hailortcli fw-control identify"
echo "  3. Edit $CONFIG_DIR/detect.env if you're not using a USB webcam"
echo "     (uncomment and set CAMERA_SOURCE=rpi or CAMERA_SOURCE=libcamera)"
echo "  4. Do a manual dry run FIRST, before enabling the background service -"
echo "     this is the step most likely to need troubleshooting on first setup:"
echo "       $REPO_DIR/scripts/run-face-detect.sh"
echo "     Confirm you see live detection output/video before continuing."
echo "  5. Once step 4 works, enable it as a persistent background service:"
echo "       systemctl --user enable --now face-detect.service"
echo "       systemctl --user status face-detect.service --no-pager"
echo "============================================================"
