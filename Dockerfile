# ===============================
# MT5 + Wine + noVNC + Webhook
# Production-ready Dockerfile
# ===============================

FROM ubuntu:22.04

# -------------------------------
# Environment
# -------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080 \
    PATH="/usr/lib/wine:/usr/bin:/usr/local/bin:$PATH"

USER root

# -------------------------------
# System + Wine + X11
# -------------------------------
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 \
    xvfb x11vnc openbox \
    websockify \
    wget ca-certificates git \
    python3 python3-pip python3-xdg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Force wine binary
RUN ln -sf /usr/bin/wine64 /usr/bin/wine

# -------------------------------
# Python deps
# -------------------------------
RUN pip3 install --no-cache-dir \
    flask flask-cors requests pytz \
    rpyc mt5linux

# -------------------------------
# noVNC
# -------------------------------
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# -------------------------------
# App files
# -------------------------------
WORKDIR /root

RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe \
    -O /root/mt5setup.exe

COPY reciever.py webhook.json index.html /root/
RUN mkdir -p /root/templates && \
    cp /root/index.html /root/templates/index.html

# -------------------------------
# Startup script
# -------------------------------
RUN printf "#!/bin/bash\n\
set -e\n\
\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
echo '=== XVFB ==='\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 3\n\
\n\
echo '=== OPENBOX ==='\n\
openbox-session &\n\
sleep 2\n\
\n\
echo '=== VNC ==='\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
\n\
echo '=== noVNC ==='\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
echo '=== WINE INIT ==='\n\
wine wineboot --init\n\
sleep 20\n\
\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
\n\
if [ ! -f \"$MT5_PATH/terminal64.exe\" ]; then\n\
  echo '=== INSTALLING MT5 ==='\n\
  wine /root/mt5setup.exe /portable /auto\n\
  sleep 60\n\
fi\n\
\n\
echo '=== STARTING MT5 ==='\n\
wine \"$MT5_PATH/terminal64.exe\" /portable &\n\
\n\
echo '=== WAITING FOR MT5 ==='\n\
sleep 40\n\
\n\
echo '=== MT5 LINUX BRIDGE ==='\n\
python3 -m mt5linux.bridge &\n\
sleep 10\n\
\n\
echo '=== WEBHOOK SERVER ==='\n\
exec python3 /root/reciever.py\n\
" > /start.sh && chmod +x /start.sh

# -------------------------------
# Ports
# -------------------------------
EXPOSE 8080 6080 5900

CMD ["/bin/bash", "/start.sh"]
