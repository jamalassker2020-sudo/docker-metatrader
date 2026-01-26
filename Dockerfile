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

# 1. Install dependencies + add 32-bit architecture (Wine needs both often)
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    wine64 \
    wine32 \
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy Expert Advisor
COPY hft.mq5 /tmp/hft.mq5

# 3. Install MetaTrader 5
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# 4. Move EA to MT5 Experts folder
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    cp /tmp/hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# 5. Fix permissions
RUN chown -R 1001:0 /home/headless
USER 1001

# 6. Start using the FULL PATH to wine64 to avoid "command not found"
CMD ["/dockerstartup/startup.sh", "--wait", "/usr/bin/wine64", "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe", "/portable"]
