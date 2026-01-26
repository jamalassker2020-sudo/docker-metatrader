# Step 1: Web-VNC desktop base
FROM accetto/ubuntu-vnc-xfce-g3

USER root

# Step 2: Install Wine and tools
RUN apt-get update && apt-get install -y wine64 wget curl

# Step 3: Copy your HFT file to a simple folder (NO SPACES HERE)
# This prevents the "double-quote" error you are seeing
COPY hft.mq5 /tmp/hft.mq5

# Step 4: Install MT5
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# Step 5: Now move the file to the real MT5 folder using a shell command
# Shell commands handle spaces much better than the COPY command
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/" && \
    cp /tmp/hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Step 6: Final permissions
RUN chown -R 1000:0 /home/headless/.wine
USER 1000

EXPOSE 6901

# Step 7: Launch
CMD ["sh", "-c", "/dockerstartup/vnc_startup.sh && wine64 '/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe' /portable"]
