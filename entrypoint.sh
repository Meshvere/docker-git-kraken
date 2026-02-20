#!/bin/bash
set -e

user=$1

echo "=== Début du script d'entrypoint ==="

# Nettoyer les fichiers D-Bus résiduels
echo "Nettoyage des fichiers D-Bus..."
rm -f /run/dbus/pid
rm -f /run/dbus/system_bus_socket
mkdir -p /var/run/dbus

echo "=== Copier la clé SSH ==="
mkdir -p /home/$user/.ssh
cp -R /ssh/* ~/.ssh/
chown -R root:root ~/.ssh/*
chmod -R 700 ~/.ssh/*

cp -R /ssh/* /home/$user/.ssh/
chown -R $user:$user /home/$user/.ssh/*
chmod -R 700 /home/$user/.ssh/*

ssh-agent bash -c 'ssh-add ~/.ssh/id_rsa'
ssh-agent bash -c 'ssh-add /home/$user/.ssh/id_rsa'

echo "=== Configuration Git ==="
git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_MAIL}"
echo "Git configuré pour ${GIT_NAME} <${GIT_MAIL}>"

echo "=== Configuration mot de passe VNC (TigerVNC) ==="

mkdir -p /home/$user/.vnc
chown $user:$user /home/$user/.vnc
chmod 700 /home/$user/.vnc

if [ -n "${VNC_PASSWORD}" ]; then
  printf "%s\n%s\n\n" "${VNC_PASSWORD}" "${VNC_PASSWORD}" | \
    su - $user -c "vncpasswd /home/$user/.vnc/passwd"
  chmod 600 /home/$user/.vnc/passwd
  echo "Mot de passe VNC configuré"
else
  echo "⚠️ VNC_PASSWORD non défini : accès VNC sans mot de passe"
fi

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

[program:tigervnc]
command=/usr/bin/Xtigervnc :0 \
  -SecurityTypes None \
  -localhost no \
  -geometry 1900x950 \
  -depth 24 \
  -AlwaysShared
user=$user
autorestart=true
priority=10
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:openbox]
command=/usr/bin/openbox-session
user=$user
environment=DISPLAY=":0",HOME="/home/$user"
autorestart=true
priority=20
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:gitkraken]
command=bash -c 'sleep 5 && /usr/share/gitkraken/gitkraken --no-sandbox && sleep 5 && wmctrl -r "GitKraken" -b add,fullscreen'
user=$user
directory=/home/$user
environment=DISPLAY=":0",HOME="/home/$user",DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
autorestart=true
priority=30
startsecs=10
startretries=999
exitcodes=0,2
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true

EOF

# Démarrer D-Bus
mkdir -p /var/run/dbus
dbus-daemon --system --fork

echo "=== Démarrage Supervisor ==="
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
