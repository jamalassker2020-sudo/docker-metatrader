# Step 1: Use the official slim Ubuntu to save massive space
FROM ubuntu:22.04

# Step 2: Set non-interactive and environment
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720

USER root

# Step 3: Install Wine + Minimal Desktop (Openbox) + VNC in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    openbox \
    wget \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Install MT5 and clean up immediately
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh && \
    chmod +x mt5ubuntu.sh && \
    ./mt5ubuntu.sh && \
    rm mt5ubuntu.sh

# Step 5: Add your HFT strategy
COPY hft.mq5 /tmp/hft.mq5
RUN mkdir -p "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    cp /tmp/hft.mq5 "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/" && \
    rm /tmp/hft.mq5

# Step 6: Create the Startup Script
RUN echo '#!/bin/bash\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox & \n\
x11vnc -display :1 -nopw -forever -bg &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
wine64 "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable' > /start.sh && \
    chmod +x /start.sh

EXPOSE 6901

CMD ["/bin/bash", "/start.sh"]
