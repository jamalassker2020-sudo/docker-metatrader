# Step 1: Use a base with a built-in Web-VNC desktop
FROM accetto/ubuntu-vnc-xfce-g3

USER root

# Step 2: Install Wine and download tools
RUN apt-get update && apt-get install -y wine64 wget curl

# Step 3: Create the directory
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Step 4: Copy ANY .mq5 file found in your GitHub repo (Fixes "Not Found" error)
COPY *.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Step 5: Download and Silent Install MT5
# We use the -y flag to ensure it doesn't wait for a mobile user to click 'OK'
RUN wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5ubuntu.sh \
    && chmod +x mt5ubuntu.sh \
    && ./mt5ubuntu.sh

# Step 6: Fix permissions
RUN chown -R 1000:0 /home/headless/.wine
USER 1000

# Railway uses the PORT environment variable
EXPOSE 6901

# Step 7: Launch everything
CMD ["sh", "-c", "/dockerstartup/vnc_startup.sh && wine64 '/home/headless/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe' /portable"]
