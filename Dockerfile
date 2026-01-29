# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Set environment (Fixed PATH and Display)
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PATH="/usr/lib/wine:/usr/bin:/usr/local/bin:$PATH"

USER root

# Step 3: Install Wine, Python, VNC, and Dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 xvfb x11-utils x11vnc websockify \
    openbox wget ca-certificates unzip git python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Pre-install Linux Python packages (Speeds up deployment)
RUN pip3 install --no-cache-dir flask flask-cors mt5linux pytz rpyc

# Step 5: Install Latest noVNC
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Step 6: Setup Files
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY index.html /root/index.html
COPY webhook.json /root/webhook.json
COPY reciever.py /root/reciever.py
COPY hft.mq5 /root/hft.mq5

# Step 7: The "Magic" Startup Script
RUN printf '#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display immediately\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
# 2. Start VNC & noVNC (Railway sees this on PORT 8080)\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen ${PORT:-8080} &\n\
\n\
# 3. Initialize Wine\n\
wine64 wineboot --init\n\
sleep 5\n\
\n\
# 4. Install Windows Python if not exists (The MT5 Linux Bridge)\n\
if [ ! -d "/root/.wine/drive_c/Python39" ]; then\n\
  echo "Installing Windows Python Bridge..."\n\
  wget -q https://www.python.org/ftp/python/3.9.0/amd64/core.msi -O /root/python-3.9.msi\n\
  wine64 msiexec /i /root/python-3.9.msi /qb\n\
  sleep 5\n\
  wine64 python -m pip install MetaTrader5 rpyc\n\
fi\n\
\n\
# 5. MT5 Installation Logic\n\
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5"\n\
if [ ! -f "$MT5_PATH/terminal64.exe" ]; then\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 15\n\
fi\n\
\n\
# 6. Deploy Strategy\n\
mkdir -p "$MT5_PATH/MQL5/Experts/"\n\
cp /root/hft.mq5 "$MT5_PATH/MQL5/Experts/"\n\
\n\
# 7. Start the RPyC Bridge Server (Crucial for reciever.py)\n\
wine64 python -m mt5linux &\n\
sleep 2\n\
\n\
# 8. Start your Linux Webhook Receiver on port 5000\n\
python3 /root/reciever.py &\n\
\n\
# 9. Launch MT5 UI\n\
wine64 "$MT5_PATH/terminal64.exe" /portable\n\
\n\
sleep infinity' > /start.sh && \
    chmod +x /start.sh

# Step 8: Final Config
EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
