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

# Step 4: Install Latest noVNC
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Step 5: Copy your files into the container
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe

# Copying all necessary files
COPY index.html /root/index.html
COPY webhook.json /root/webhook.json
COPY reciever.py /root/reciever.py
COPY hft.mq5 /root/hft.mq5

# Step 6: Automated Startup Script
RUN printf '#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
# 2. Start VNC\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT:-8080} &\n\
\n\
# 3. Install Linux Dependencies\n\
pip3 install flask flask-cors mt5linux pytz rpyc\n\
\n\
# 4. Initialize Wine and Install Windows Python (The Bridge Server)\n\
wine64 wineboot --init\n\
sleep 10\n\
if [ ! -f "/root/python-3.9.msi" ]; then\n\
  wget -q https://www.python.org/ftp/python/3.9.0/amd64/core.msi -O /root/python-3.9.msi\n\
  wine64 msiexec /i /root/python-3.9.msi /qb\n\
  sleep 10\n\
  wine64 python -m pip install MetaTrader5 mt5linux rpyc\n\
fi\n\
\n\
# 5. Define MT5 Paths\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
MQL5_EXPERTS="$MT5_PATH/MQL5/Experts"\n\
\n\
# 6. Install MT5 if missing\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 20\n\
fi\n\
\n\
# 7. Copy Expert Advisor\n\
mkdir -p "$MQL5_EXPERTS"\n\
cp /root/hft.mq5 "$MQL5_EXPERTS/"\n\
\n\
# 8. Start the Bridge Server inside Wine\n\
wine64 python -m mt5linux &\n\
sleep 5\n\
\n\
# 9. Start your Linux Webhook Receiver\n\
python3 /root/reciever.py &\n\
\n\
# 10. Launch MT5\n\
wine64 "$MT5_PATH/terminal64.exe" /portable\n\
\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 7: Railway Port Exposure
EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
