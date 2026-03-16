#!/bin/bash
# IMPORTANT: This file must use LF (Unix) line endings, NOT CRLF (Windows).
# If you edit this on Windows, ensure your editor saves with LF endings.
# Fix with: sed -i 's/\r//' start.sh   OR   dos2unix start.sh

set -e

# VNC is used only on macOS (no native display in Docker). On Windows/Linux set USE_VNC=0 in .env.
USE_VNC="${USE_VNC:-1}"
if [ "$USE_VNC" = "0" ] || [ "$USE_VNC" = "false" ] || [ "$USE_VNC" = "no" ]; then
  USE_VNC=0
else
  USE_VNC=1
fi

export XDG_RUNTIME_DIR=/tmp/runtime-qgisuser
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

if [ "$USE_VNC" = "1" ]; then
  # Clean up any stale Xvfb/x11vnc from a previous run (e.g. after container restart).
  rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null || true
  pkill -9 Xvfb 2>/dev/null || true
  pkill -9 x11vnc 2>/dev/null || true
  pkill -9 websockify 2>/dev/null || true
  sleep 2

  echo "======================================"
  echo "Starting virtual display (Xvfb)..."
  echo "======================================"
  Xvfb :99 -screen 0 1920x1080x24 &
  sleep 2

  echo "Starting VNC server (x11vnc) on port 5900..."
  x11vnc -display :99 -nopw -listen 0.0.0.0 -rfbport 5900 -xkb -ncache 10 \
         -ncache_cr -forever -bg \
         -o /home/qgisuser/log_files/x11vnc.log
  sleep 2

  echo "Starting noVNC..."
  NOVNC_PATH=""
  for candidate in /usr/share/novnc /usr/share/noVNC /usr/share/novnc/; do
    if [ -d "$candidate" ]; then
      NOVNC_PATH="$candidate"
      break
    fi
  done
  if [ -z "$NOVNC_PATH" ]; then
    echo "ERROR: noVNC web root not found. Check that novnc is installed."
    exit 1
  fi

  websockify --web="$NOVNC_PATH" 6080 localhost:5900 \
             --log-file=/home/qgisuser/log_files/websockify.log &
  sleep 2

  echo "======================================"
  echo "VNC is ready (Mac):"
  echo "  - Browser (noVNC): http://localhost:6080/vnc.html"
  echo "  - Direct VNC (e.g. TigerVNC): localhost:5900"
  echo "======================================"
  export DISPLAY=:99
else
  echo "======================================"
  echo "VNC disabled (Windows/Linux). Using host DISPLAY."
  echo "======================================"
fi

echo "Starting QGIS..."
exec qgis --noversioncheck 2>&1 | tee /home/qgisuser/log_files/qgis.log
