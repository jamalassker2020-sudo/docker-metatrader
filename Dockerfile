# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Set non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720 \
    WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64

USER root

# Step 3: Install Wine + VNC tools (Added architecture support)
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
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

# Step 4: Download MT5 and Copy Strategy
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY hft.mq5 /root/hft.mq5

# Step 5: Create Startup Script
RUN echo '#!/bin/bash\n\
# Cleanup locks\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# Start Xvfb & Window Manager\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
# Start VNC server & noVNC\n\
x11vnc -display :1 -nopw -listen localhost -forever -bg &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
\n\
# Initialize Wine\n\
if [ ! -d "/root/.wine" ]; then\n\
  wine wineboot --init\n\
  sleep 10\n\
fi\n\
\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
\n\
# Install MT5 if not present\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  echo "Installing MT5 via Wine..."\n\
  wine /root/mt5setup.exe /portable /auto\n\
  \n\
  # Wait loop for installation\n\
  for i in {1..60}; do\n\
    if [ -f "$MT5_PATH/terminal64.exe" ]; then\n\
      echo "MT5 installation completed"\n\
      break\n\
    fi\n\
    sleep 2\n\
  done\n\
fi\n\
\n\
# Setup MQL5 folders and Strategy\n\
mkdir -p "$MT5_PATH/MQL5/Experts/"\n\
mkdir -p "$MT5_PATH/config/"\n\
cp /root/hft.mq5 "$MT5_PATH/MQL5/Experts/"\n\
\n\
# Inject Top 20 Crypto Symbols\n\
printf "[Charts]\nsymbol0=BTCUSD\nsymbol1=ETHUSD\nsymbol2=SOLUSD\nsymbol3=BNBUSD\nsymbol4=XRPUSD\nsymbol5=ADAUSD\nsymbol6=DOGEUSD\nsymbol7=TRXUSD\nsymbol8=DOTUSD\nsymbol9=LINKUSD\nsymbol10=AVAXUSD\nsymbol11=SHIBUSD\nsymbol12=MATICUSD\nsymbol13=LTCUSD\nsymbol14=UNIUSD\nsymbol15=BCHUSD\nsymbol16=ETCUSD\nsymbol17=ATOMUSD\nsymbol18=XMRUSD\nsymbol19=XLMUSD\n" > "$MT5_PATH/config/common.ini"\n\
\n\
echo "Starting MT5 Terminal..."\n\
wine "$MT5_PATH/terminal64.exe" /portable\n\
\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 6: Final config
EXPOSE 6901
CMD ["/bin/bash", "/start.sh"]
