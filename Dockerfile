FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720

# ===============================
# SYSTEM + WINE
# ===============================
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 \
    wine32 \
    winetricks \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    openbox \
    wget \
    unzip \
    ca-certificates \
    cabextract \
    fonts-wine && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ===============================
# WINE RUNTIME (SAFE SET)
# ===============================
RUN winetricks -q vcrun2019 gecko mono

# ===============================
# MT5
# ===============================
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

COPY hft.mq5 /root/hft.mq5

# ===============================
# START SCRIPT
# ===============================
RUN cat << 'EOF' > /start.sh
#!/bin/bash
set -e

echo "=== START X ==="
rm -f /tmp/.X1-lock
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &
sleep 3
openbox-session &

echo "=== VNC ==="
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &

echo "=== NOVNC ==="
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT} &

echo "=== WINE INIT ==="
wineboot --init
sleep 10

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

if [ ! -f "$MT5/terminal64.exe" ]; then
  echo "=== INSTALL MT5 ==="
  wine /root/mt5setup.exe /auto
  echo "=== WAITING FOR MT5 INSTALL ==="
  for i in {1..90}; do
    [ -f "$MT5/terminal64.exe" ] && break
    sleep 2
  done
fi

mkdir -p "$MT5/MQL5/Experts"
cp /root/hft.mq5 "$MT5/MQL5/Experts/"

echo "=== START MT5 ==="
wine "$MT5/terminal64.exe" /portable

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
