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

# Step 4: Prepare the setup file
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /tmp/mt5setup.exe

# Step 5: Copy your HFT strategy
COPY hft.mq5 /tmp/hft.mq5

# Step 6: Create Startup Script (Fixed Execution Logic)
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
# Initialize Wine\n\
winecfg /v win10 >/dev/null 2>&1\n\
sleep 5\n\
\n\
if [ ! -f "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then\n\
  echo "Installing MT5 via Wine..."\n\
  $WINE_EXE /tmp/mt5setup.exe /portable /auto\n\
  sleep 40\n\
fi\n\
\n\
# Prepare Expert and Crypto Symbols\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
mkdir -p "$MT5_PATH/MQL5/Experts/"\n\
cp /tmp/hft.mq5 "$MT5_PATH/MQL5/Experts/"\n\
\n\
# Create a basic config to show symbols (Best effort for portable mode)\n\
echo "[Charts]\nsymbol0=BTCUSD\nsymbol1=ETHUSD\nsymbol2=SOLUSD\nsymbol3=BNBUSD\nsymbol4=XRPUSD\nsymbol5=ADAUSD\nsymbol6=DOGEUSD\nsymbol7=TRXUSD\nsymbol8=DOTUSD\nsymbol9=LINKUSD\nsymbol10=AVAXUSD\nsymbol11=SHIBUSD\nsymbol12=MATICUSD\nsymbol13=LTCUSD\nsymbol14=UNIUSD\nsymbol15=BCHUSD\nsymbol16=ETCUSD\nsymbol17=ATOMUSD\nsymbol18=XMRUSD\nsymbol19=XLMUSD" > "$MT5_PATH/config/common.ini"\n\
\n\
echo "Starting MT5 Terminal..."\n\
$WINE_EXE "$MT5_PATH/terminal64.exe" /portable' > /start.sh && \
    chmod +x /start.sh

# Step 7: Expose port
EXPOSE 6901

# Step 8: Launch
CMD ["/bin/bash", "/start.sh"]
