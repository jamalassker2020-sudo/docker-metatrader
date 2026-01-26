# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Set non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720

USER root

# Step 3: Install Wine + VNC tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
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
rm -f /tmp/.X1-lock\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
for i in {1..10}; do if xdpyinfo -display :1 >/dev/null 2>&1; then break; fi; sleep 1; done\n\
openbox & \n\
x11vnc -display :1 -nopw -listen localhost -forever -bg &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
\n\
WINE_EXE=$(command -v wine64 || command -v wine)\n\
\n\
# Force permissions on the installer\n\
chmod 777 /root/mt5setup.exe\n\
\n\
# Initialize Wine Prefix\n\
winecfg /v win10 >/dev/null 2>&1\n\
sleep 10\n\
\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  echo "Installing MT5..."\n\
  $WINE_EXE /root/mt5setup.exe /portable /auto\n\
  # Wait for files to actually appear\n\
  timeout 60s bash -c "until [ -f \"$MT5_PATH/terminal64.exe\" ]; do sleep 2; done"\n\
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
$WINE_EXE "$MT5_PATH/terminal64.exe" /portable' > /start.sh && \
    chmod +x /start.sh

# Step 6: Final config
EXPOSE 6901
CMD ["/bin/bash", "/start.sh"]
