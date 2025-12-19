#!/bin/bash
set -e

echo "=== Début du script d'entrypoint ==="

# Nettoyer les fichiers D-Bus résiduels
echo "Nettoyage des fichiers D-Bus..."
rm -f /run/dbus/pid
rm -f /run/dbus/system_bus_socket
mkdir -p /var/run/dbus

echo "=== Copier la clé SSH ==="
mkdir -p /home/smanetagis/.ssh
cp -R /ssh/* ~/.ssh/
chown -R root:root ~/.ssh/*
chmod -R 700 ~/.ssh/*

ssh-agent bash -c 'ssh-add ~/.ssh/id_rsa'

echo "=== Configuration Git ==="
git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_MAIL}"
echo "Git configuré pour ${GIT_NAME} <${GIT_MAIL}>"

echo "=== Configuration mot de passe VNC ==="
mkdir -p ~/.vnc
# Utiliser x11vnc directement avec le mot de passe en argument
x11vnc -storepasswd "${VNC_PASSWORD}" ~/.vnc/passwd
chmod 600 ~/.vnc/passwd
echo "Mot de passe VNC configuré (longueur: $(wc -c < ~/.vnc/passwd) octets)"

echo "=== Configuration Openbox pour plein écran ==="
mkdir -p ~/.config/openbox
cat > ~/.config/openbox/rc.xml << 'OPENBOX_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application name="gitkraken" class="GitKraken">
      <maximized>yes</maximized>
      <fullscreen>yes</fullscreen>
    </application>
  </applications>
</openbox_config>
OPENBOX_EOF
echo "Configuration Openbox créée"

echo "=== Création de la configuration Supervisor ==="
cat > /etc/supervisor/supervisord.conf << EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor

[program:dbus]
command=/usr/bin/dbus-daemon --system --nofork --nopidfile
user=root
autorestart=true
priority=1
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true
startsecs=2

[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
user=smanetagis
autorestart=true
priority=10
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true
startsecs=5

[program:x11vnc]
command=bash -c 'sleep 3 && /usr/bin/x11vnc -display :99 -forever -shared -nopw -xkb'
user=smanetagis
autorestart=true
priority=20
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true
startsecs=3

[program:gitkraken]
command=bash -c 'sleep 5 && /usr/share/gitkraken/gitkraken --no-sandbox'
user=smanetagis
directory=/home/smanetagis
environment=DISPLAY=":99",HOME="/home/smanetagis",DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
autorestart=true
priority=30
startretries=5
startsecs=10
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true
EOF

# Démarrer D-Bus
mkdir -p /var/run/dbus
dbus-daemon --system --fork

echo "=== Démarrage Supervisor ==="
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
