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
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
\n\
# PUBLIC PORT (Railway)\n\
websockify --web /usr/share/novnc ${PORT} localhost:5900 &\n\
\n\
wine wineboot --init\n\
sleep 15\n\
\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
if [ ! -d \"$MT5_PATH\" ]; then\n\
  wine /root/mt5setup.exe /portable /auto\n\
  sleep 90\n\
fi\n\
\n\
wine \"$MT5_PATH/terminal64.exe\" /portable &\n\
sleep 40\n\
\n\
python3 -m mt5linux &\n\
\n\
echo \"Waiting for MT5 bridge...\"\n\
until timeout 1 bash -c \"echo > /dev/tcp/localhost/18812\"; do sleep 3; done\n\
\n\
# INTERNAL WEBHOOK\n\
python3 /root/receiver.py\n\
' > /start.sh && chmod +x /start.sh

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/start.sh"]
