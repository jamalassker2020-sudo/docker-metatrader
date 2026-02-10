FROM ubuntu:22.04

# --- Environment Configuration ---
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080 \
    FLASK_PORT=8081 \
    PYTHONUNBUFFERED=1

USER root

# 1. System dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    tini wine wine64 wine32 xvfb x11vnc openbox \
    websockify wget ca-certificates git \
    python3 python3-pip python3-xdg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Python & App Setup
RUN pip3 install --no-cache-dir flask flask-cors requests pytz rpyc mt5linux openai python-dotenv

# 3. Virtual Desktop (VNC) Setup
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

WORKDIR /root

# 4. Prepare MetaTrader 5
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

# Copy your local files into the image
COPY bot.py /root/
COPY *.mq5 /root/

# 5. Final Startup Script
RUN printf "#!/bin/bash\n\
set -e\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
echo '=== STARTING GUI ==='\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 -noxdamage -ncache 10 &\n\
websockify --web /usr/share/novnc \${PORT} localhost:5900 &\n\
\n\
echo '=== INITIALIZING WINE ==='\n\
WINE_BIN=\$(which wine64 || which wine)\n\
\$WINE_BIN wineboot --init\n\
sleep 15\n\
\n\
# Define Paths clearly\n\
MT5_DIR=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
EXPERTS_DIR=\"\$MT5_DIR/MQL5/Experts\"\n\
\n\
if [ ! -f \"\$MT5_DIR/terminal64.exe\" ]; then\n\
  echo '=== INSTALLING MT5 ==='\n\
  \$WINE_BIN /root/mt5setup.exe /portable /auto\n\
  sleep 90\n\
fi\n\
\n\
echo '=== DEPLOYING MQL5 SCRIPTS ==='\n\
mkdir -p \"\$EXPERTS_DIR\"\n\
cp /root/*.mq5 \"\$EXPERTS_DIR/\"\n\
\n\
echo '=== STARTING MT5 ==='\n\
cd \"\$MT5_DIR\"\n\
\$WINE_BIN terminal64.exe /portable &\n\
sleep 45\n\
\n\
echo '=== STARTING MT5LINUX BRIDGE ==='\n\
python3 -m mt5linux 18812 &\n\
\n\
until (echo > /dev/tcp/localhost/18812) >/dev/null 2>&1; do \n\
  echo 'Waiting for bridge on port 18812...'; \n\
  sleep 5; \n\
done\n\
\n\
echo '=== BRIDGE ACTIVE - STARTING BOT ==='\n\
python3 /root/bot.py\n\
" > /start.sh && chmod +x /start.sh

EXPOSE 8080
EXPOSE 8081

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/start.sh"]
