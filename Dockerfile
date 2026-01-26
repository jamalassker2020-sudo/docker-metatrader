# Base image
FROM accetto/ubuntu-vnc-xfce-g3:latest

# Railway-safe environment
ENV USER=headless
ENV HOME=/home/headless
ENV DISPLAY=:1
ENV VNC_COL_DEPTH=24
ENV VNC_RESOLUTION=1280x720
ENV STARTUP_WAIT=1

# 🚫 تعطيل توليد المستخدم نهائياً
ENV ENABLE_SUDO=0
ENV ENABLE_USER=0
ENV DISABLE_USER_GENERATION=true

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

# Fix permissions (بدون user switching)
RUN chown -R headless:headless /home/headless

# Expose VNC port
EXPOSE 6901

# Start VNC + MT5 (بدون user generator)
CMD ["/dockerstartup/vnc_startup.sh", "--wait", "wine64", "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe", "/portable"]
