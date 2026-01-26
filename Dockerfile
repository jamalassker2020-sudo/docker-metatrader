# Step 1: Use a base with a built-in Web-VNC desktop
FROM accetto/ubuntu-vnc-xfce-g3

USER root

# Step 2: Install Wine and download tools
RUN apt-get update && apt-get install -y wine64 wget curl

# Step 3: Set up the MT5 folder and add your strategy
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"
COPY ./hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Step 4: Download and Silent Install MT5
# This script downloads the official installer and runs it in the background
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# Step 5: Fix permissions for the VNC user
RUN chown -R 1000:0 /home/headless/.wine
USER 1000

# Step 6: Expose the port for your mobile browser to connect
EXPOSE 6901

# Step 7: Launch the Web-Desktop + MT5 in Portable Mode
CMD ["sh", "-c", "/dockerstartup/vnc_startup.sh && wine64 '/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe' /portable"]
