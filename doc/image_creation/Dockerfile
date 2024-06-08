# Utilitza la imatge base de Debian Bookworm amd64
FROM debian:trixie-slim

# Actualitza el repositori de paquets i instal·la paquets necessaris
RUN apt-get update && apt-get install -y --no-install-recommends \
    dialog \
    ca-certificates \
    curl \
    gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Array de paquets extra que vols instal·lar
ARG EXTRA_PACKAGES=""
ENV EXTRA_PACKAGES ${EXTRA_PACKAGES}

# Instal·la els paquets extra
RUN apt-get update && apt-get install -y --no-install-recommends ${EXTRA_PACKAGES} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Comanda per defecte
CMD ["bash"]

