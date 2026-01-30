# Step 1: Base Image
FROM ubuntu:22.04

# Step 2: Env Vars
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080

USER root

# Step 3: Dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 xvfb x11vnc websockify openbox \
    wget ca-certificates git python3 python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Step 4: Python Setup
RUN pip3 install --no-cache-dir flask flask-cors mt5linux pytz rpyc requests

# Step 5: noVNC Setup
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Step 6: App Files
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY reciever.py webhook.json index.html /root/
RUN mkdir -p /root/templates && cp /root/index.html /root/templates/index.html

# Step 7: Startup Script
RUN printf "#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
# Initialize Wine\n\
wine64 wineboot --init &\n\
sleep 10\n\
\n\
# Start Bridge - the 'python' arg is the key fix\n\
python3 -m mt5linux python &\n\
sleep 5\n\
\n\
# Install/Run MT5 in background\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
( \n\
  if [ ! -f \"\$MT5_PATH/terminal64.exe\" ]; then\n\
    wine64 /root/mt5setup.exe /portable /auto\n\
    sleep 40\n\
  fi\n\
  wine64 \"\$MT5_PATH/terminal64.exe\" /portable &\n\
) &\n\
\n\
# Start the Webhook Receiver\n\
python3 /root/reciever.py\n\
" > /start.sh && chmod +x /start.sh

# Step 8: Ports
EXPOSE 8080 6080 5900
CMD ["/bin/bash", "/start.sh"]


