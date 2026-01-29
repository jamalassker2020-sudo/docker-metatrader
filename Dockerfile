# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Environment Setup
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PATH="/usr/lib/wine:/usr/bin:/usr/local/bin:$PATH"

USER root

# Step 3: Install Wine, Python, and Git
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 xvfb x11-utils x11vnc websockify \
    openbox wget ca-certificates unzip git python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Install Latest noVNC (v1.5.0+)
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Step 5: Copy your files into the container
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe

# Copying your files from your local folder to the VPS root
COPY index.html /root/index.html
COPY webhook.json /root/webhook.json
COPY reciever.py /root/reciever.py

# Step 6: Automated Startup Script
RUN printf '#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display & Window Manager\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
# 2. Start VNC & Latest noVNC\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT:-8080} &\n\
\n\
# 3. Live Install Python dependencies (Inside the session)\n\
echo "Installing Flask and tools..."\n\
pip3 install flask flask-cors metatrader5 pytz\n\
\n\
# 4. Initialize Wine Environment\n\
wine64 wineboot --init\n\
sleep 8\n\
\n\
# 5. Define MT5 Paths\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
MQL5_FILES="$MT5_PATH/MQL5/Files"\n\
MQL5_EXPERTS="$MT5_PATH/MQL5/Experts"\n\
\n\
# 6. Install MT5 if not found\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  echo "Installing MetaTrader 5..."\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 20\n\
fi\n\
\n\
# 7. AUTOMATIC ACTIVATION: Copy files to MT5 folders\n\
mkdir -p "$MQL5_FILES"\n\
mkdir -p "$MQL5_EXPERTS"\n\
cp /root/webhook.json "$MQL5_FILES/"\n\
cp /root/hft.mq5 "$MQL5_EXPERTS/"\n\
\n\
# 8. Start the Receiver Python script in the background\n\
echo "Starting Webhook Receiver..."\n\
python3 /root/reciever.py &\n\
\n\
# 9. Launch MT5\n\
echo "Launching MT5..."\n\
wine64 "$MT5_PATH/terminal64.exe" /portable\n\
\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 7: Railway Port Exposure
EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
