ARG POSTGRES_VERSION=15
ARG POSTGIS_VERSION=3.5

ARG POSTGIS_BASE_IMAGE=docker.io/postgis/postgis:${POSTGRES_VERSION}-${POSTGIS_VERSION}-alpine

FROM ${POSTGIS_BASE_IMAGE}
LABEL GeoNode development team

COPY --chmod=755 ./initdb-geonode.sh /docker-entrypoint-initdb.d/geonode.sh
