ARG POSTGRES_VERSION=17
ARG POSTGIS_VERSION=3.4

ARG POSTGIS_BASE_IMAGE=docker.io/postgis/postgis:${POSTGRES_VERSION}-${POSTGIS_VERSION}-alpine

FROM ${POSTGIS_BASE_IMAGE}

COPY --chmod=755 ./initdb-geonode.sh /docker-entrypoint-initdb.d/geonode.sh

# Repete o ARG do FROM para usá-lo no rótulo da base
ARG POSTGIS_BASE_IMAGE
# Rótulos OCI. No fim do arquivo, para que VERSION/REVISION/CREATED (que mudam a cada build) não
# invalidem o cache das camadas anteriores.
ARG VERSION=dev
ARG REVISION=unknown
ARG CREATED=unknown
LABEL org.opencontainers.image.title="OpenGeoSGB PostGIS" \
      org.opencontainers.image.description="PostgreSQL com PostGIS e a criação dos bancos do GeoNode (SGB/CPRM)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.authors="NDS CPRM" \
      org.opencontainers.image.vendor="Serviço Geológico do Brasil (SGB/CPRM)" \
      org.opencontainers.image.url="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.source="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.documentation="https://github.com/nds-cprm/geonode-docker#readme" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.base.name="${POSTGIS_BASE_IMAGE}"
