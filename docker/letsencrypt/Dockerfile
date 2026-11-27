ARG ALPINE_VERSION=latest
FROM docker.io/library/alpine:${ALPINE_VERSION}

# Sem versão fixa: o apk da imagem base (alpine) só mantém as versões da própria release
# hadolint ignore=DL3018
RUN apk add --no-cache certbot

# Ponto de montagem do volume de certificados compartilhado com o nginx: num volume novo, o primeiro
# container que o monta define dono e permissões pelo copy-up. Grupo 0 e g=u, sem UID fixo, para
# funcionar com qualquer UID do grupo 0 (ex.: UID aleatório do OpenShift), como na imagem do nginx.
RUN mkdir -p /geonode-certificates && \
    chgrp 0 /geonode-certificates && \
    chmod g=u /geonode-certificates

# Installing scripts
COPY --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh

# Installing cronjobs
COPY crontab /crontab
RUN /usr/bin/crontab /crontab && \
    rm /crontab

# Repete o ARG do FROM para usá-lo no rótulo da base
ARG ALPINE_VERSION
# Rótulos OCI. No fim do arquivo, para que VERSION/REVISION/CREATED (que mudam a cada build) não
# invalidem o cache das camadas anteriores.
ARG VERSION=dev
ARG REVISION=unknown
ARG CREATED=unknown
LABEL org.opencontainers.image.title="OpenGeoSGB letsencrypt" \
      org.opencontainers.image.description="Emissão e renovação de certificados (certbot) para o nginx do GeoNode (SGB/CPRM)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.authors="NDS CPRM" \
      org.opencontainers.image.vendor="Serviço Geológico do Brasil (SGB/CPRM)" \
      org.opencontainers.image.url="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.source="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.documentation="https://github.com/nds-cprm/geonode-docker#readme" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.base.name="docker.io/library/alpine:${ALPINE_VERSION}"

# Setup the entrypoint
ENTRYPOINT ["./docker-entrypoint.sh"]

# We run cron in foreground to update the certificates
CMD ["/usr/sbin/crond", "-f"]
