ARG POSTGRES_VERSION=15
ARG POSTGIS_VERSION=3.5
FROM postgis/postgis:${POSTGRES_VERSION}-${POSTGIS_VERSION}-alpine
LABEL GeoNode development team

COPY --chmod=755 ./initdb-geonode.sh /docker-entrypoint-initdb.d/geonode.sh
