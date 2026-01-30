# Step 1: Base Imag## Step 1: Base Image
FROM ubuntu:22.04

# Step 2: Env Vars
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080 \
    PATH="/usr/lib/wine:/usr/bin:/usr/local/bin:$PATH"

USER root

# Step 3: Install Wine and Dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 xvfb x11vnc websockify openbox \
    wget ca-certificates git python3 python3-pip python3-xdg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Step 4: Fix Wine pathing - Use -sf to FORCE the link
RUN ln -sf /usr/bin/wine64 /usr/bin/wine

# Step 5: Python Setup
RUN pip3 install --no-cache-dir flask flask-cors mt5linux pytz rpyc requests

# Step 6: noVNC Setup
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Step 7: App Files
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY reciever.py webhook.json index.html /root/
RUN mkdir -p /root/templates && cp /root/index.html /root/templates/index.html

# Step 8: Final Startup Script
RUN printf "#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 3\n\
openbox-session &\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
# Initialize Wine\n\
wine wineboot --init &\n\
sleep 15\n\
\n\
# Start Bridge\n\
python3 -m mt5linux python &\n\
sleep 10\n\
\n\
# Install/Run MT5\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
( \n\
  if [ ! -f \"\$MT5_PATH/terminal64.exe\" ]; then\n\
    echo '--- INSTALLING MT5 ---'\n\
    wine /root/mt5setup.exe /portable /auto\n\
    sleep 60\n\
  fi\n\
  echo '--- LAUNCHING MT5 ---'\n\
  wine \"\$MT5_PATH/terminal64.exe\" /portable &\n\
) &\n\
\n\
# Start the Webhook Receiver\n\
echo '--- STARTING WEB SERVER ---'\n\
python3 /root/reciever.py\n\
" > /start.sh && chmod +x /start.sh

# Step 9: Ports
EXPOSE 8080 6080 5900
CMD ["/bin/bash", "/start.sh"]
"/bin/bash", "/start.sh"]



