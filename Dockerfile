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
# PRE-INSTALL WINE COMPONENTS
# ===============================
RUN winetricks -q corefonts vcrun2019 dotnet48 gecko mono

# ===============================
# MT5
# ===============================
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

COPY hft.mq5 /root/hft.mq5

# ===============================
# START SCRIPT
# ===============================
RUN printf '#!/bin/bash\n\
set -e\n\
echo \"=== START X ===\"\n\
rm -f /tmp/.X1-lock\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
echo \"=== VNC ===\"\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
\n\
echo \"=== NOVNC ON RAILWAY PORT ===\"\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT} &\n\
\n\
echo \"=== WINE INIT ===\"\n\
wineboot --init\n\
sleep 10\n\
\n\
MT5=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
\n\
if [ ! -f \"$MT5/terminal64.exe\" ]; then\n\
  echo \"=== INSTALL MT5 ===\"\n\
  wine /root/mt5setup.exe /auto\n\
  sleep 20\n\
fi\n\
\n\
mkdir -p \"$MT5/MQL5/Experts\"\n\
cp /root/hft.mq5 \"$MT5/MQL5/Experts/\"\n\
\n\
echo \"=== START MT5 ===\"\n\
wine \"$MT5/terminal64.exe\" /portable\n\
\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
