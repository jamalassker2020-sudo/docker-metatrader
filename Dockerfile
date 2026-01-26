# Base image
FROM accetto/ubuntu-vnc-xfce-g3:latest

# Railway-safe environment variables
ENV USER=headless \
    HOME=/home/headless \
    DISPLAY=:1 \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x720 \
    STARTUP_WAIT=1 \
    ENABLE_SUDO=0 \
    ENABLE_USER=0 \
    DISABLE_USER_GENERATION=true

USER root

# 1. Install dependencies
RUN apt-get update && apt-get install -y \
    wine64 \
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy and Prepare MetaTrader 5
COPY hft.mq5 /tmp/hft.mq5

RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# 3. Move EA to the correct Experts folder
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts" && \
    cp /tmp/hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# 4. Correct Permissions for the headless user
RUN chown -R 1000:0 /home/headless

# Use the non-privileged user
USER 1000

# 5. Corrected Startup Command
# We call the main startup.sh which handles the VNC initialization properly.
# The --wait flag ensures the desktop is ready before launching MT5.
CMD ["/dockerstartup/startup.sh", "--wait", "wine64", "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe", "/portable"]
