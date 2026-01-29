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

# Step 3: Install Wine, VNC tools, and Python
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 \
    wine32 \
    xvfb \
    x11-utils \
    x11vnc \
    websockify \
    openbox \
    wget \
    ca-certificates \
    unzip \
    git \
    python3 \
    python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Install Python Libraries & Latest noVNC
# This executes the "pip install" you requested during the build
RUN pip3 install flask flask-cors pytz

# Download the latest noVNC directly from GitHub
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify

# Step 5: Download MT5 and Copy your custom files
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe

# Ensure these 5 files are in the same folder as your Dockerfile on your computer
COPY hft.mq5 /root/hft.mq5
COPY index.html /root/index.html
COPY webhook.json /root/webhook.json
COPY reciever.py /root/reciever.py

# Step 6: Create Startup Script
RUN printf '#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 3\n\
openbox-session &\n\
\n\
# 2. Start VNC & noVNC (Updated for Railway $PORT)\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT:-8080} &\n\
\n\
# 3. Start your Receiver in the background\n\
python3 /root/reciever.py &\n\
\n\
# 4. Initialize Wine\n\
wine64 wineboot --init\n\
sleep 10\n\
\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
\n\
# 5. Install MT5 if not present\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 20\n\
fi\n\
\n\
# 6. Setup MQL5 and config\n\
mkdir -p "$MT5_PATH/MQL5/Experts/"\n\
mkdir -p "$MT5_PATH/config/"\n\
cp /root/hft.mq5 "$MT5_PATH/MQL5/Experts/"\n\
# Move your json file to the MT5 folder if needed\n\
cp /root/webhook.json "$MT5_PATH/MQL5/Files/" 2>/dev/null || true\n\
\n\
echo "=== STARTING MT5 TERMINAL ==="\n\
wine64 "$MT5_PATH/terminal64.exe" /portable\n\
\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 7: Final config
EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
