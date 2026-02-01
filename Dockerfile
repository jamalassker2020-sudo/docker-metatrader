FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080 \
    FLASK_PORT=8081

USER root

# -------------------------------
# System dependencies
# -------------------------------
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    tini \
    wine64 wine32 \
    xvfb x11vnc openbox \
    websockify \
    wget ca-certificates git \
    python3 python3-pip python3-xdg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

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
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
COPY receiver.py /root/

# -------------------------------
# Startup
# -------------------------------
# ... (Keep your existing Dockerfile until the Start script)

# -------------------------------
# Final Stabilized Startup Script
# -------------------------------
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
# Ensure X11 cleanup\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
echo "=== STARTING GUI SERVICES ==="\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 3\n\
openbox-session &\n\
# Enhanced VNC stability\n\
/usr/bin/x11vnc -display :1 -nopw -forever -shared -rfbport 5900 -noxdamage -ncache 10 &\n\
/usr/bin/websockify --web /usr/share/novnc ${PORT} localhost:5900 &\n\
\n\
echo "=== INITIALIZING WINE64 ==="\n\
# Use absolute paths to avoid "command not found"\n\
/usr/bin/wine64 wineboot --init\n\
sleep 20\n\
\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
if [ ! -d "$MT5_PATH" ]; then\n\
  echo "=== INSTALLING MT5 ==="\n\
  /usr/bin/wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 90\n\
fi\n\
\n\
echo "=== STARTING MT5 TERMINAL ==="\n\
/usr/bin/wine64 "$MT5_PATH/terminal64.exe" /portable &\n\
sleep 45\n\
\n\
echo "=== STARTING PYTHON BRIDGE ==="\n\
/usr/bin/python3 -m mt5linux &\n\
\n\
echo "Waiting for MT5 bridge on 18812..."\n\
until timeout 1 bash -c "echo > /dev/tcp/localhost/18812" 2>/dev/null; do \n\
  sleep 5\n\
done\n\
\n\
echo "=== STARTING WEBHOOK SERVER ON 8081 ==="\n\
/usr/bin/python3 /root/receiver.py\n\
' > /start.sh && chmod +x /start.sh

# Ensure Tini is used correctly
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/start.sh"]
