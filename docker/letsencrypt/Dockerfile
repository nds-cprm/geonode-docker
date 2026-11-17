FROM alpine:latest

RUN apk add --no-cache certbot

# Ponto de montagem do volume de certificados compartilhado com o nginx: num volume novo, o primeiro
# container que o monta define dono e permissões pelo copy-up. Grupo 0 e g=u, sem UID fixo, para
# funcionar com qualquer UID do grupo 0 (ex.: UID aleatório do OpenShift), como na imagem do nginx.
RUN mkdir -p /geonode-certificates && \
    chgrp 0 /geonode-certificates && \
    chmod g=u /geonode-certificates

# Installing scripts
ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Installing cronjobs
ADD crontab /crontab
RUN /usr/bin/crontab /crontab && \
    rm /crontab

# Setup the entrypoint
ENTRYPOINT ["./docker-entrypoint.sh"]

# We run cron in foreground to update the certificates
CMD /usr/sbin/crond -f
