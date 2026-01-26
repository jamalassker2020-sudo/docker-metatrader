# Step 1: Use a much smaller Wine base image
FROM suchy/wine:latest

USER root

# Step 2: Set environment variables
ENV DISPLAY=:1 \
    VNC_PASSWORD=headless \
    SCREEN_RESOLUTION=1280x720 \
    ACCETTO_DISABLE_USER_GENERATION=1

# Step 3: Install only essential tools and cleanup
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    wget \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Step 4: Install MT5 and cleanup installer
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh && \
    chmod +x mt5ubuntu.sh && \
    ./mt5ubuntu.sh && \
    rm mt5ubuntu.sh

# Step 5: Setup EA
COPY hft.mq5 /tmp/hft.mq5
RUN mkdir -p "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    cp /tmp/hft.mq5 "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/" && \
    rm /tmp/hft.mq5

# Step 6: Create a startup script to handle VNC and MT5
RUN echo '#!/bin/bash\n\
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
x11vnc -display :1 -nopw -forever -bg &\n\
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6901 &\n\
wine64 "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable' > /start.sh && \
    chmod +x /start.sh

EXPOSE 6901

CMD ["/start.sh"]
