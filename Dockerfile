FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEPREFIX=/root/.wine \
    PORT=8080

USER root

# 1. Install System Dependencies & Wine
RUN dpkg --add-architecture i386 && apt-get update && \
    apt-get install -y --no-install-recommends \
    tini wine wine64 wine32 xvfb x11vnc openbox websockify wget ca-certificates \
    python3 python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Install Python for Windows (Inside Wine)
# Required because the MT5 library only works on Windows Python
RUN wget -q https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe && \
    xvfb-run -a wine python-3.10.0-amd64.exe /quiet InstallAllUsers=1 PrependPath=1 && \
    rm python-3.10.0-amd64.exe

# 3. Install Python Libraries
# Linux side:
RUN pip3 install --no-cache-dir mt5linux openai python-dotenv flask
# Wine side (Windows):
RUN xvfb-run -a wine python -m pip install MetaTrader5

# 4. App Setup
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
COPY bot.py /root/
# COPY .env /root/

# 5. Startup Script
RUN printf "#!/bin/bash\n\
Xvfb :1 -screen 0 1280x720x24 &\n\
sleep 2\n\
openbox-session &\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 &\n\
websockify --web /usr/share/novnc \${PORT} localhost:5900 &\n\
\n\
echo '=== STARTING MT5 ==='\n\
wine /root/mt5setup.exe /portable /auto & sleep 60\n\
\n\
echo '=== STARTING BRIDGE ==='\n\
# This starts the bridge server using the Windows Python inside Wine\n\
wine python -m mt5linux &\n\
sleep 10\n\
\n\
echo '=== STARTING BOT ==='\n\
python3 /root/bot.py\n\
" > /start.sh && chmod +x /start.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/start.sh"]
