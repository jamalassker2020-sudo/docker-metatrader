# Base image
FROM accetto/ubuntu-vnc-xfce-g3:latest

# Environment (Railway-safe)
ENV DISPLAY=:1 \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x720 \
    STARTUP_WAIT=1 \
    ENABLE_SUDO=0 \
    ENABLE_USER=0 \
    ACCETTO_DISABLE_USER_GENERATION=1 \
    PATH="/usr/lib/wine:/usr/bin:$PATH"

USER root

# 1. Install dependencies & clean up in ONE step to save space
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    wine32 \
    wget \
    curl \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2. Install MT5 and delete the installer immediately
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh && \
    chmod +x mt5ubuntu.sh && \
    ./mt5ubuntu.sh && \
    rm mt5ubuntu.sh

# 3. Setup EA and fix permissions
COPY hft.mq5 /tmp/hft.mq5
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    cp /tmp/hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/" && \
    rm /tmp/hft.mq5 && \
    chown -R 1001:0 /home/headless

USER 1001

# 4. Corrected Startup Command
CMD ["/dockerstartup/startup.sh", "--wait", "/usr/bin/wine64", "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe", "/portable"]
