FROM debian:12

# Installation des locales françaises
RUN apt-get update && \
    apt-get install -y locales && \
    sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen fr_FR.UTF-8 && \
    update-locale LANG=fr_FR.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# Configuration des locales françaises
ENV LANG=fr_FR.UTF-8 \
    LANGUAGE=fr_FR:fr \
    LC_ALL=fr_FR.UTF-8 \
    TZ=Europe/Paris

# Installation des dépendances
RUN apt-get update && \
    apt-get install -y \
    wget \
    curl \
    git \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    openbox \
    libgbm1 \
    libasound2 \
    libgtk-3-0 \
    fonts-liberation \
    fonts-dejavu \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Configuration du fuseau horaire
RUN ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime && \
    echo "Europe/Paris" > /etc/timezone

# Téléchargement et installation de GitKraken
RUN wget https://release.gitkraken.com/linux/gitkraken-amd64.deb -O /tmp/gitkraken.deb && \
    apt-get update && \
    apt-get install -y /tmp/gitkraken.deb && \
    rm /tmp/gitkraken.deb && \
    rm -rf /var/lib/apt/lists/*

# Création des dossiers nécessaires
RUN mkdir -p /root/.vnc /var/log/supervisor

# Copie du script d'entrée
COPY entrypoint.sh /entrypoint.sh
RUN chmod u+x /*.sh

# Variables d'environnement par défaut
ENV DISPLAY=:0 \
    VNC_PASSWORD=changeme \
    RESOLUTION=1920x1080 \
    GIT_NAME="Your Name" \
    GIT_MAIL="your@email.com"

# Exposition des ports
EXPOSE 5900 6080

# Point d'entrée
ENTRYPOINT ["/entrypoint.sh"]
