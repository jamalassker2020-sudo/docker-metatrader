# Step 1: Use the VNC desktop base
FROM accetto/ubuntu-vnc-xfce-g3

USER root

# FIX FOR RAILWAY PERMISSION ERRORS
# These lines stop the container from trying to modify /etc/group at startup
ENV REFRESHED_AT=2026-01-26
ENV STARTUP_WAIT=1
ENV VNC_COL_DEPTH=24
ENV VNC_RESOLUTION=1280x720

# Step 2: Install Wine and tools
RUN apt-get update && apt-get install -y wine64 wget curl

# Step 3: Copy your file to a simple folder first
COPY hft.mq5 /tmp/hft.mq5

# Step 4: Install MT5
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# Step 5: Move file to MT5 folder
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/" && \
    cp /tmp/hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Step 6: Set permissions for the built-in user (1000)
RUN chown -R 1000:0 /home/headless/.wine
USER 1000

# Step 7: Launch with the specific VNC startup script
EXPOSE 6901
CMD ["/dockerstartup/vnc_startup.sh", "--wait", "wine64", "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe", "/portable"]
