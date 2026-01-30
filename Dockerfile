# Step 1: Use official Ubuntu 22.04
FROM ubuntu:22.04

# Step 2: Environment Setup
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PATH="/usr/lib/wine:/usr/bin:/usr/local/bin:$PATH" \
    PORT=8080

USER root

# Step 3: Install Wine, Python, and UI tools
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine64 wine32 xvfb x11-utils x11vnc websockify \
    openbox python3-xdg wget ca-certificates unzip git python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Install Python packages
RUN pip3 install --no-cache-dir flask flask-cors mt5linux pytz rpyc requests

# Step 5: Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    git clone https://github.com/novnc/websockify /usr/share/novnc/utils/websockify && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Step 6: Setup Application Files
WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe

# Copy your files
COPY reciever.py /root/reciever.py
COPY webhook.json /root/webhook.json
COPY index.html /root/index.html

# Setup templates for Flask
RUN mkdir -p /root/templates && cp /root/index.html /root/templates/index.html

# Step 7: The Final Corrected Startup Script
RUN printf "#!/bin/bash\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
\n\
# 1. Start Virtual Display\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 3\n\
openbox-session &\n\
\n\
# 2. Start VNC (5900) & noVNC (6080)\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
# 3. Initialize Wine\n\
wine64 wineboot --init &\n\
sleep 5\n\
\n\
# 4. Start the MT5 Bridge (FIXED COMMAND)\n\
# We use 'python3' to run the bridge on the linux side\n\
python3 -m mt5linux python & \n\
sleep 5\n\
\n\
# 5. Background MT5 Launch\n\
MT5_PATH=\"/root/.wine/drive_c/Program Files/MetaTrader 5\"\n\
( \n\
  sleep 10\n\
  if [ ! -f \"\$MT5_PATH/terminal64.exe\" ]; then\n\
    echo 'Installing MetaTrader 5...'\n\
    wine64 /root/mt5setup.exe /portable /auto\n\
    sleep 30\n\
  fi\n\
  echo 'Launching MetaTrader 5...'\n\
  wine64 \"\$MT5_PATH/terminal64.exe\" /portable &\n\
) &\n\
\n\
# 6. FINAL: Launch Webserver with a small delay to ensure bridge is up\n\
echo \"🚀 Webhook Receiver & Dashboard Live on Port: \$PORT\"\n\
sleep 5\n\
python3 /root/reciever.py\n\
" > /start.sh && \
    chmod +x /start.sh

# Step 8: Final Config
EXPOSE 8080 6080 5900
CMD ["/bin/bash", "/start.sh"]

