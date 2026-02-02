FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080

USER root

# -------------------------------
# 1. System dependencies (Robust Wine Install)
# -------------------------------
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    tini \
    wine wine64 wine32 \
    xvfb x11vnc openbox \
    websockify wget ca-certificates git \
    python3 python3-pip python3-xdg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# -------------------------------
# 2. Python & App Setup
# -------------------------------
RUN pip3 install --no-cache-dir flask flask-cors requests pytz rpyc mt5linux

RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
COPY receiver.py /root/

# NEW: Copy MT5 Files to a staging area
RUN mkdir -p /root/mt5_staging/Experts /root/mt5_staging/Include

# Copy the EA and header files from your directory
COPY "MT5 to Telegram.ex5" /root/mt5_staging/Experts/
COPY Comment.mqh Common.mqh jason.mqh Telegram.mqh /root/mt5_staging/Include/

# -------------------------------
# 3. Final Startup Script
# -------------------------------
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
# Correcting MT5 Path for typical Wine 64-bit installations\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
\n\
if [ ! -f \"\$MT5_PATH/terminal64.exe\" ]; then\n\
  echo '=== INSTALLING MT5 ==='\n\
  \$WINE_BIN /root/mt5setup.exe /portable /auto\n\
  # Wait longer for the installer to finish background tasks\n\
  sleep 60\n\
fi\n\
\n\
# --- INSTALL STAGED FILES ---\n\
MQL5_PATH=\"\$MT5_PATH/MQL5\"\n\
echo '=== INSTALLING EA AND HEADERS ==='\n\
mkdir -p \"\$MQL5_PATH/Experts\" \"\$MQL5_PATH/Include\"\n\
cp /root/mt5_staging/Experts/* \"\$MQL5_PATH/Experts/\" || true\n\
cp /root/mt5_staging/Include/* \"\$MQL5_PATH/Include/\" || true\n\
\n\
echo '=== STARTING MT5 ==='\n\
# Use full path and start from within the directory to avoid library load errors\n\
cd \"\$MT5_PATH\"\n\
\$WINE_BIN terminal64.exe /portable &\n\
sleep 45\n\
\n\
echo '=== STARTING BRIDGE ==='\n\
# Fixed mt5linux command: it requires the path to the python interpreter\n\
python3 -m mt5linux python &\n\
\n\
until timeout 1 bash -c 'echo > /dev/tcp/localhost/18812' 2>/dev/null; do \n\
  echo 'Waiting for bridge...'; sleep 5; \n\
done\n\
\n\
echo '=== STARTING WEBHOOK ==='\n\
python3 /root/receiver.py\n\
" > /start.sh && chmod +x /start.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/start.sh"]
