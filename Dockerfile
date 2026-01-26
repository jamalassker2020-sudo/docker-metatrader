# Use a base that already includes Wine, Xvfb, and noVNC (web-based desktop)
FROM accetto/ubuntu-vnc-xfce-g3

USER root

# Install Wine and necessary tools
RUN apt-get update && apt-get install -y wine64 wget unzip

# Create the MT5 directory structure
RUN mkdir -p "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Copy your HFT strategy into the container
COPY ./hft.mq5 "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"

# Set the working directory
WORKDIR "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/"

# Fix permissions for the headless user
RUN chown -R 1000:0 /home/headless/.wine

USER 1000

# Railway uses the PORT environment variable; noVNC usually runs on 6901
EXPOSE 6901

# Start the desktop environment and MT5
CMD ["sh", "-c", "/dockerstartup/vnc_startup.sh && wine64 terminal64.exe /portable"]
