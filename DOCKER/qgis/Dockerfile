# Multi-version QGIS image for TOMs (Debian only).
# Supported: 3.22 (Debian repo only), 3.28/3.34/3.44 (qgis.org bookworm), 4.0-nightly (qgis.org trixie).
# Set QGIS_VERSION and BASE_IMAGE in .env. 3.22 does not contact qgis.org (works offline after apt).
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG QGIS_VERSION=3.22

ENV DEBIAN_FRONTEND=noninteractive

# Force IPv4 for apt (avoids IPv6 timeout issues on some networks)
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# Install bootstrap tools (wget only needed for 3.44 / 4.x when we add QGIS repo)
RUN apt-get update && apt-get install -y \
    gnupg wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Add QGIS key + repo only for versions that need qgis.org (skip for 3.22 to avoid network to qgis.org).
# 3.22: Debian bookworm packages only (no key, no repo).
# 3.28 / 3.34 / 3.44 etc.: qgis.org/debian bookworm.
# 4.x (e.g. 4.0-nightly): qgis.org/debian-nightly-release trixie.
RUN set -e; \
    if [ "${QGIS_VERSION}" = "3.22" ]; then \
      echo "QGIS ${QGIS_VERSION}: using Debian repo only (no qgis.org)."; \
    else \
      mkdir -p /usr/share/keyrings /etc/apt/sources.list.d; \
      wget -q -O /usr/share/keyrings/qgis-archive-keyring.gpg \
        https://download.qgis.org/downloads/qgis-archive-keyring.gpg; \
      MAJOR=$(echo "${QGIS_VERSION}" | cut -d'.' -f1); \
      if [ "$MAJOR" = "3" ]; then \
        echo "deb [signed-by=/usr/share/keyrings/qgis-archive-keyring.gpg] https://qgis.org/debian bookworm main" \
          > /etc/apt/sources.list.d/qgis.list; \
      else \
        echo "deb [signed-by=/usr/share/keyrings/qgis-archive-keyring.gpg] https://qgis.org/debian-nightly-release trixie main" \
          > /etc/apt/sources.list.d/qgis.list; \
      fi; \
    fi

# Version is determined by which repo was added above (no apt version pin).
# 3.22: Debian repo only → qgis 3.22. 3.44 / 3.x: qgis.org bookworm → 3.44. 4.x: qgis.org nightly → 4.x.
# Qt5 for 3.x (bookworm), Qt6 for 4.x (trixie). For Qt6 we also install Qt Quick Controls so the welcome
# screen and other QML UI pieces work (avoids 'QtQuick.Controls ... plugin not found').
RUN MAJOR=$(echo "${QGIS_VERSION}" | cut -d'.' -f1) && \
    if [ "$MAJOR" = "3" ]; then \
  VERSION_PKGS=" \
  libqt5gui5 \
  libqt5widgets5 \
  libqt5svg5 \
  libasound2 \
  libxcb-icccm4 \
  libxcb-image0 \
  libxcb-keysyms1 \
  libxcb-render-util0 \
  "; \
  EXTRA_PKGS=""; \
    else \
  VERSION_PKGS=" \
  libqt6gui6 \
  libqt6widgets6 \
  libqt6svg6 \
  libasound2t64 \
  libxcb-cursor0 \
  libxcb-xinerama0 \
  libxcb-xfixes0 \
  libdrm2 \
  libgbm1 \
  "; \
  EXTRA_PKGS=" \
  qml6-module-qtquick-controls \
  qml6-module-qtquick-layouts \
  qml6-module-qtquick-effects \
  "; \
    fi && \
    apt-get update && \
    apt-get install -y \
      qgis \
      python3-qgis \
  postgresql-client \
      libpulse0 \
      libgl1 \
  libglx-mesa0 \
  libegl1 \
  mesa-utils \
      libnss3 \
      libxkbcommon-x11-0 \
  dbus-x11 \
      xvfb \
      x11vnc \
      novnc \
      websockify \
      xterm \
      $VERSION_PKGS \
  $EXTRA_PKGS \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} qgisgroup && \
    useradd -m -u ${USER_ID} -g qgisgroup -s /bin/bash qgisuser

# Create required directories (including expressions) and ensure Xvfb can create the X11 socket
RUN mkdir -p /home/qgisuser/qgis_data/profiles/default/python/plugins && \
  mkdir -p /home/qgisuser/qgis_data/profiles/default/python/expressions && \
    mkdir -p /home/qgisuser/projects && \
    mkdir -p /home/qgisuser/log_files && \
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix && \
    chown -R qgisuser:qgisgroup /home/qgisuser

# Startup script (must use LF line endings)
COPY start.sh /start.sh
RUN chmod +x /start.sh

USER qgisuser
ENV DISPLAY=:99
ENV QT_X11_NO_MITSHM=1
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV QGIS_CUSTOM_CONFIG_PATH=/home/qgisuser/qgis_data
WORKDIR /home/qgisuser
ENTRYPOINT ["/start.sh"]
