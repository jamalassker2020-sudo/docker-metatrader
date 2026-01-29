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

# Step 3: Install Wine, Python, and UI tools
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 xvfb x11-utils x11vnc websockify \
    openbox python3-xdg wget ca-certificates unzip git python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Install Python dependencies
RUN pip3 install --no-cache-dir flask flask-cors mt5linux pytz rpyc

# Step 5: Install noVNC (We will serve these files via Flask)
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Step 6: Setup Files
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY reciever.py /root/reciever.py
COPY hft.mq5 /root/hft.mq5

# Step 7: The Startup Script
RUN printf "#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
# 2. Start VNC (Internal only)\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
\n\
# 3. Start Websockify (Convert VNC to WebSocket on port 6080)\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
# 4. Initialize Wine & MT5\n\
wine64 wineboot --init\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
if [ ! -f \"\$MT5_PATH/terminal64.exe\" ]; then\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 20\n\
fi\n\
\n\
# 5. Start MT5 & Bridge\n\
wine64 python -m mt5linux &\n\
wine64 \"\$MT5_PATH/terminal64.exe\" /portable &\n\
\n\
# 6. FINAL: Start the Python Receiver on Railway's PORT (8080)\n\
# This will serve the webhook AND the desktop UI\n\
python3 /root/reciever.py\n\
" > /start.sh && \
    chmod +x /start.sh

EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
