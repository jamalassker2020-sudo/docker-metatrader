# Step 1: Use official Ubuntu
FROM ubuntu:22.04

# Step 2: Set non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720

USER root

# Step 3: Install Wine + VNC tools (No heavy desktop)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    openbox \
    wget \
    ca-certificates \
    unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Create MT5 Directory and Download MT5 Binaries directly
# We bypass the .sh script to avoid the "Window" error
RUN mkdir -p "/root/.wine/drive_c/Program Files/MetaTrader 5"
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /tmp/mt5setup.exe

# Step 5: Add your HFT strategy
COPY hft.mq5 "/root/.wine/drive_c/Program Files/MetaTrader 5/hft.mq5"

# Step 6: Create the Startup Script
# This script starts the virtual screen FIRST, then runs the MT5 setup if needed
RUN echo '#!/bin/bash\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox & \n\
x11vnc -display :1 -nopw -forever -bg &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
# If terminal64 doesnt exist, we run the setup once inside the live container\n\
if [ ! -f "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then\n\
  wine64 /tmp/mt5setup.exe /portable /auto\n\
  sleep 10\n\
fi\n\
# Move the EA to the correct folder now that the structure exists\n\
mkdir -p "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"\n\
cp "/root/.wine/drive_c/Program Files/MetaTrader 5/hft.mq5" "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"\n\
# Start the Terminal\n\
wine64 "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable' > /start.sh && \
    chmod +x /start.sh

EXPOSE 6901

CMD ["/bin/bash", "/start.sh"]
