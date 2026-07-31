#!/usr/bin/env bash
# Runs Hailo's own official face_recognition.py app in *detection-only* mode:
# no enrollment step is ever run, so the LanceDB face database stays empty
# and no detected face can ever match anyone. This is entirely Hailo's own
# maintained code (from hailo-ai/hailo-apps), invoked exactly as documented -
# nothing here reimplements any part of their detection/GStreamer pipeline.
#
# To add recognition later: run
#   python face_recognition.py --mode train
# once, pointed at a directory of labeled face images, before starting this
# script - see hailo-apps' own face_recognition README for that flow. This
# project deliberately doesn't automate that step, to keep the default
# behavior strictly detection-only.
set -euo pipefail

ENV_FILE="$HOME/.config/face-detect-aihat/detect.env"
[ -f "$ENV_FILE" ] && set -a && source "$ENV_FILE" && set +a

HAILO_APPS_DIR="${HAILO_APPS_DIR:-$HOME/.local/share/hailo-apps}"
CAMERA_SOURCE="${CAMERA_SOURCE:-usb}"

if [ ! -d "$HAILO_APPS_DIR" ]; then
    echo "hailo-apps not found at $HAILO_APPS_DIR" >&2
    echo "Set HAILO_APPS_DIR in $ENV_FILE, or install it per SETUP.md step 3." >&2
    exit 1
fi

if [ -n "${HEADLESS_DISPLAY:-}" ]; then
    export DISPLAY="$HEADLESS_DISPLAY"
fi

cd "$HAILO_APPS_DIR"
# shellcheck source=/dev/null
source setup_env.sh

FACE_APP_DIR="$HAILO_APPS_DIR/hailo_apps/python/pipeline_apps/face_recognition"
cd "$FACE_APP_DIR"

exec python face_recognition.py --input "$CAMERA_SOURCE" --mode run
