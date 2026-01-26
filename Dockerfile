# Step 1: Use official Ubuntu
FROM ubuntu:22.04

# Step 2: Set non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720

USER root

# Step 3: Install Wine + VNC tools (added wine-stable for better paths)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    openbox \
    wget \
    ca-certificates \
    unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Prepare the setup file
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /tmp/mt5setup.exe

# Step 5: Copy your HFT strategy
COPY hft.mq5 /tmp/hft.mq5

# Step 6: Improved Startup Script
RUN echo '#!/bin/bash\n\
# 1. Clean up old locks to prevent "already active" errors\n\
rm -f /tmp/.X1-lock\n\
\n\
# 2. Start Virtual Screen and wait\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
for i in {1..10}; do if xdpyinfo -display :1 >/dev/null 2>&1; then break; fi; sleep 1; done\n\
\n\
# 3. Start Window Manager and VNC\n\
openbox & \n\
x11vnc -display :1 -nopw -listen localhost -forever -bg &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
\n\
# 4. Use absolute path for wine64\n\
WINE_BIN=$(which wine64 || echo "/usr/bin/wine64")\n\
\n\
# 5. Run setup if needed\n\
if [ ! -f "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then\n\
  $WINE_BIN /tmp/mt5setup.exe /portable /auto\n\
  sleep 20\n\
fi\n\
\n\
# 6. Move EA\n\
mkdir -p "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"\n\
cp /tmp/hft.mq5 "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"\n\
\n\
# 7. Final launch\n\
$WINE_BIN "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable' > /start.sh && \
    chmod +x /start.sh

EXPOSE 6901

CMD ["/bin/bash", "/start.sh"]
