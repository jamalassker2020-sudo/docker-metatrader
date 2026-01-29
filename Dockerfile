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

# Step 5: Install noVNC (The UI files Flask will serve)
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Step 6: Setup Files (Adding reciever, mq5, and your json)
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY reciever.py /root/reciever.py
COPY hft.mq5 /root/hft.mq5
COPY webhook.json /root/webhook.json

# Step 7: The Startup Script
# This script ensures everything launches in order when the container starts
RUN printf "#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
\n\
# 2. Start VNC (Internal display engine)\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
\n\
# 3. Start Websockify (Internal bridge for the UI)\n\
websockify 6080 localhost:5900 &\n\
\n\
# 4. Initialize Wine & MT5\n\
wine64 wineboot --init\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
if [ ! -f \"\$MT5_PATH/terminal64.exe\" ]; then\n\
  wine64 /root/mt5setup.exe /portable /auto\n\
  sleep 20\n\
fi\n\
\n\
# 5. Start MT5 Bridge & MT5 Software\n\
wine64 python -m mt5linux &\n\
wine64 \"\$MT5_PATH/terminal64.exe\" /portable &\n\
\n\
# 6. FINAL: Launch the Webhook Receiver\n\
# This launches reciever.py which will read webhook.json\n\
# It listens on port 8080 as required by Railway\n\
python3 /root/reciever.py\n\
" > /start.sh && \
    chmod +x /start.sh

# Step 8: Expose and Run
EXPOSE 8080
CMD ["/bin/bash", "/start.sh"]
