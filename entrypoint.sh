#!/bin/bash
set -e

echo "=== Début du script d'entrypoint ==="

echo "=== Configuration Git ==="
git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_MAIL}"
echo "Git configuré pour ${GIT_NAME} <${GIT_MAIL}>"

echo "=== Configuration mot de passe VNC ==="
mkdir -p /root/.vnc
# Utiliser x11vnc directement avec le mot de passe en argument
x11vnc -storepasswd "${VNC_PASSWORD}" /root/.vnc/passwd
chmod 600 /root/.vnc/passwd
echo "Mot de passe VNC configuré (longueur: $(wc -c < /root/.vnc/passwd) octets)"

echo "=== Création de la configuration Supervisor ==="
cat > /etc/supervisor/supervisord.conf << EOF
[unix_http_server]
file=/var/run/supervisor.sock

[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[program:xvfb]
command=/usr/bin/Xvfb :0 -screen 0 ${RESOLUTION}x24
autorestart=true
priority=100
stdout_logfile=/var/log/supervisor/xvfb.log
stderr_logfile=/var/log/supervisor/xvfb.err

[program:openbox]
command=/usr/bin/openbox
environment=DISPLAY=":0"
autorestart=true
priority=200
stdout_logfile=/var/log/supervisor/openbox.log
stderr_logfile=/var/log/supervisor/openbox.err

[program:x11vnc]
command=/usr/bin/x11vnc -display :0 -rfbport 5900 -forever -shared -passwd ${VNC_PASSWORD}
autorestart=true
priority=300
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc.err

[program:novnc]
command=/usr/bin/websockify --web=/usr/share/novnc 6080 localhost:5900
autorestart=true
priority=400
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc.err

[program:gitkraken]
command=/usr/bin/gitkraken --no-sandbox --disable-gpu --disable-dev-shm-usage --disable-software-rasterizer
environment=DISPLAY=":0",HOME="/root"
autorestart=true
priority=500
startsecs=10
stdout_logfile=/var/log/supervisor/gitkraken.log
stderr_logfile=/var/log/supervisor/gitkraken.err
stopasgroup=true
killasgroup=true
EOF

echo "=== Démarrage Supervisor ==="
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
