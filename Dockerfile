FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    SCREEN_RESOLUTION=1280x720 \
    PORT=8080

RUN dpkg --add-architecture i386 && apt-get update && \
    apt-get install -y --no-install-recommends tini wine64 wine32 xvfb x11vnc openbox websockify wget ca-certificates git python3 python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/wine64 /usr/bin/wine
RUN pip3 install --no-cache-dir flask flask-cors requests rpyc mt5linux

RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc && \
    cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

WORKDIR /root
RUN wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /root/mt5setup.exe
COPY reciever.py /root/

RUN printf "#!/bin/bash\n\
set -e\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\
Xvfb :1 -screen 0 \${SCREEN_RESOLUTION}x24 &\n\
sleep 2\n\
openbox-session &\n\
# OPTIMIZED VNC SETTINGS\n\
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 -noxdamage -ncache 10 &\n\
# VNC ON PORT 8080\n\
websockify --web /usr/share/novnc \${PORT} localhost:5900 &\n\
\n\
wine wineboot --init && sleep 15\n\
if [ ! -d \"/root/.wine/drive_c/Program Files/MetaTrader 5\" ]; then\n\
  wine /root/mt5setup.exe /portable /auto && sleep 60\n\
fi\n\
\n\
wine \"/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe\" /portable &\n\
sleep 30\n\
\n\
# START BRIDGE\n\
python3 -m mt5linux &\n\
while ! timeout 1s bash -c \"echo > /dev/tcp/localhost/18812\" 2>/dev/null; do sleep 2; done\n\
\n\
# START WEBHOOK ON 5000\n\
python3 /root/reciever.py &\n\
wait -n\n\
" > /start.sh && chmod +x /start.sh

EXPOSE 8080 5000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/start.sh"]
