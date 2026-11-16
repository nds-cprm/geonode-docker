ARG NGINX_VERSION=1.31.7
# Imagem rootless: roda como usuário nginx (uid 101) e escuta em 8080 (HTTP) / 8443 (HTTPS)
FROM nginxinc/nginx-unprivileged:${NGINX_VERSION}-alpine

USER root

RUN apk add --no-cache openssl inotify-tools vim

WORKDIR /etc/nginx/

RUN mkdir -p /etc/nginx/html &&\
    touch /etc/nginx/html/index.html

ADD nginx.conf.envsubst nginx.https.available.conf.envsubst ./
ADD geonode.conf.envsubst ./sites-enabled/

ADD docker-autoreload.sh docker-entrypoint.sh /
RUN chmod +x /docker-autoreload.sh /docker-entrypoint.sh

# Diretórios escritos em runtime pelo entrypoint precisam pertencer ao usuário nginx.
# g=u permite rodar com UID arbitrário do grupo root (ex.: OpenShift).
RUN mkdir -p \
        /geonode-certificates/disabled \
        /geonode-certificates/staging \
        /geonode-certificates/production \
        /geonode-certificates/autoissued && \
    chown -R nginx:root /etc/nginx /geonode-certificates && \
    chmod -R g=u /etc/nginx /geonode-certificates

USER nginx

EXPOSE 8080 8443

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
