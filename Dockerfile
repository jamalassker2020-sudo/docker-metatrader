# =========================
# BASE IMAGE
# =========================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720 \
    WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64

USER root

# =========================
# INSTALL DEPENDENCIES
# =========================
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine \
    wine64 \
    wine32 \
    xvfb \
    x11-utils \
    x11vnc \
    novnc \
    websockify \
    openbox \
    python3-xdg \
    wget \
    unzip \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =========================
# DOWNLOAD MT5 + EA
# =========================
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY hft.mq5 /root/hft.mq5

# =========================
# STARTUP SCRIPT
# =========================
RUN cat << 'EOF' > /start.sh
#!/bin/bash
set -e

echo "=== CLEANUP X LOCKS ==="
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

echo "=== START XVFB ==="
Xvfb :1 -screen 0 1280x720x24 &
sleep 3

echo "=== START OPENBOX ==="
openbox-session &
sleep 2

echo "=== START VNC + NOVNC ==="
x11vnc -display :1 -nopw -listen localhost -forever -bg
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &

echo "=== INIT WINE ==="
if [ ! -d "/root/.wine" ]; then
  wineboot --init
  sleep 10
fi

MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "=== INSTALL MT5 IF NEEDED ==="
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then
  wine /root/mt5setup.exe /portable /auto
  for i in {1..60}; do
    [ -f "$MT5_PATH/terminal64.exe" ] && break
    sleep 2
  done
fi

echo "=== COPY EA ==="
mkdir -p "$MT5_PATH/MQL5/Experts"
cp /root/hft.mq5 "$MT5_PATH/MQL5/Experts/"

echo "=== START MT5 ==="
wine "$MT5_PATH/terminal64.exe" /portable

sleep infinity
EOF

RUN chmod +x /start.sh

# =========================
# EXPOSE NOVNC
# =========================
EXPOSE 6901

CMD ["/bin/bash", "/start.sh"]
