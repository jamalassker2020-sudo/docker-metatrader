# Base image
FROM accetto/ubuntu-vnc-xfce-g3:latest

# Environment (Railway-safe)
ENV DISPLAY=:1 \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x720 \
    STARTUP_WAIT=1 \
    ENABLE_SUDO=0 \
    ENABLE_USER=0 \
    ACCETTO_DISABLE_USER_GENERATION=1

# 🟢 Switch to root temporarily to fix the "Permission Denied" error
USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    wine64 \
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy Expert Advisor
COPY hft.mq5 /tmp/hft.mq5

# Install MetaTrader 5
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# Move EA to MT5 Experts folder
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    cp /tmp/hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Fix folder ownership before leaving root
RUN chown -R 1001:0 /home/headless

# 🟢 Switch back to the default headless user (G3 images use 1001)
USER 1001

# Start with correct G3 startup script
CMD ["/dockerstartup/startup.sh", "--wait", "wine64", "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe", "/portable"]
