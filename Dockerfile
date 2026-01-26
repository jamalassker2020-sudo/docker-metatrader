# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Set non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720 \
    WINEDEBUG=-all \
    WINEPREFIX=/root/.wine

USER root

# Step 3: Install Wine + VNC tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    wine32 \
    xvfb \
    x11-utils \
    x11vnc \
    novnc \
    websockify \
    openbox \
    wget \
    ca-certificates \
    unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Initialize wine (32-bit + 64-bit support)
RUN winecfg /v win10 && wineserver -k

# Step 4: Download MT5 and Copy Strategy
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY hft.mq5 /root/hft.mq5

# Step 5: Create Startup Script
RUN echo '#!/bin/bash\n\
set -x\n\
\n\
# Cleanup any leftover X locks\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# Start Xvfb\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
\n\
# Wait for Xvfb to be ready\n\
for i in {1..30}; do\n\
  if xdpyinfo -display :1 >/dev/null 2>&1; then\n\
    echo "Xvfb is ready on display :1"\n\
    break\n\
  fi\n\
  echo "Waiting for Xvfb... attempt $i/30"\n\
  sleep 1\n\
done\n\
\n\
# Start window manager\n\
openbox-session &\n\
\n\
# Start VNC server\n\
x11vnc -display :1 -nopw -listen localhost -forever -bg &\n\
\n\
# Start noVNC\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
\n\
# Initialize Wine if not already done\n\
if [ ! -f "/root/.wine/system.reg" ]; then\n\
  echo "Initializing Wine..."\n\
  wine wineboot --init\n\
  sleep 5\n\
fi\n\
\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
\n\
# Install MT5 if not present\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  echo "Installing MT5 via Wine..."\n\
  # Run the installer through Wine, not as a binary\n\
  wine /root/mt5setup.exe /portable /auto\n\
  \n\
  # Wait for installation to complete\n\
  echo "Waiting for MT5 installation..."\n\
  for i in {1..60}; do\n\
    if [ -f "$MT5_PATH/terminal64.exe" ]; then\n\
      echo "MT5 installation completed"\n\
      break\n\
    fi\n\
    echo "Waiting for MT5 files... attempt $i/60"\n\
    sleep 2\n\
  done\n\
fi\n\
\n\
# Setup MQL5 folders and Strategy\n\
mkdir -p "$MT5_PATH/MQL5/Experts/"\n\
mkdir -p "$MT5_PATH/config/"\n\
cp /root/hft.mq5 "$MT5_PATH/MQL5/Experts/"\n\
\n\
# Add Top 20 Crypto Symbols to config\n\
printf "[Charts]\nsymbol0=BTCUSD\nsymbol1=ETHUSD\nsymbol2=SOLUSD\nsymbol3=BNBUSD\nsymbol4=XRPUSD\nsymbol5=ADAUSD\nsymbol6=DOGEUSD\nsymbol7=TRXUSD\nsymbol8=DOTUSD\nsymbol9=LINKUSD\nsymbol10=AVAXUSD\nsymbol11=SHIBUSD\nsymbol12=MATICUSD\nsymbol13=LTCUSD\nsymbol14=UNIUSD\nsymbol15=BCHUSD\nsymbol16=ETCUSD\nsymbol17=ATOMUSD\nsymbol18=XMRUSD\nsymbol19=XLMUSD\n" > "$MT5_PATH/config/common.ini"\n\
\n\
echo "Starting MT5 Terminal..."\n\
# Start MT5 through Wine\n\
wine "$MT5_PATH/terminal64.exe" /portable\n\
\n\
# Keep container running\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 6: Final config
EXPOSE 6901
CMD ["/bin/bash", "/start.sh"]
