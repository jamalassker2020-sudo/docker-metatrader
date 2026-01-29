# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Set non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PATH="/usr/lib/wine:/usr/bin:/usr/local/bin:$PATH"

USER root

# Step 3: Install Wine + VNC tools
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
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
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY hft.mq5 /root/hft.mq5
COPY index.html /root/index.html
COPY webhook.json /root/webhook.json
COPY reciever.py /root/reciever.py

# Step 5: Create Startup Script
RUN printf '#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 3\n\
openbox-session &\n\
\n\
# 2. Start VNC & noVNC\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT:-8080} --web /usr/share/novnc &\n\
\n\
# 3. Initialize Wine (using wine64 explicitly to be safe)\n\
wine64 wineboot --init\n\
sleep 10\n\
\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
\n\
# 4. Install MT5 if not present\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  echo "=== INSTALLING MT5 ==="\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  for i in {1..60}; do\n\
    [ -f "$MT5_PATH/terminal64.exe" ] && break\n\
    echo "Waiting for installation... $i"\n\
    sleep 3\n\
  done\n\
fi\n\
\n\
# 5. Setup MQL5 and Top 20 Crypto Symbols\n\
mkdir -p "$MT5_PATH/MQL5/Experts/"\n\
mkdir -p "$MT5_PATH/config/"\n\
cp /root/hft.mq5 "$MT5_PATH/MQL5/Experts/"\n\
\n\
printf "[Charts]\nsymbol0=BTCUSD\nsymbol1=ETHUSD\nsymbol2=SOLUSD\nsymbol3=BNBUSD\nsymbol4=XRPUSD\nsymbol5=ADAUSD\nsymbol6=DOGEUSD\nsymbol7=TRXUSD\nsymbol8=DOTUSD\nsymbol9=LINKUSD\nsymbol10=AVAXUSD\nsymbol11=SHIBUSD\nsymbol12=MATICUSD\nsymbol13=LTCUSD\nsymbol14=UNIUSD\nsymbol15=BCHUSD\nsymbol16=ETCUSD\nsymbol17=ATOMUSD\nsymbol18=XMRUSD\nsymbol19=XLMUSD\n" > "$MT5_PATH/config/common.ini"\n\
\n\
echo "=== STARTING MT5 TERMINAL ==="\n\
wine64 "$MT5_PATH/terminal64.exe" /portable\n\
\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 6: Final config
EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
