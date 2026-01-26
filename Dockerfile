# Step 1: Use official Ubuntu
FROM ubuntu:22.04

# Step 2: Set environment to be completely non-interactive
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    HOME=/root \
    SCREEN_RESOLUTION=1280x720

USER root

# Step 3: Install system essentials + VNC tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    gnupg \
    software-properties-common \
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

# Step 4: Setup Wine and MT5
# We use 'yes' to auto-confirm any prompts from the script
COPY hft.mq5 /tmp/hft.mq5
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh && \
    chmod +x mt5ubuntu.sh && \
    yes "" | ./mt5ubuntu.sh && \
    rm mt5ubuntu.sh

# Step 5: Organize the EA
RUN mkdir -p "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    mv /tmp/hft.mq5 "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

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
