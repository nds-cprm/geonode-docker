ARG NGINX_VERSION=1.31.7
# Imagem rootless: roda como usuário nginx (uid 101) e escuta em 8080 (HTTP) / 8443 (HTTPS)
FROM docker.io/nginx/nginx-unprivileged:${NGINX_VERSION}-alpine

USER root

RUN apk add --no-cache openssl inotify-tools vim

WORKDIR /etc/nginx/

RUN mkdir -p /etc/nginx/html &&\
    touch /etc/nginx/html/index.html

ADD nginx.conf.envsubst nginx.https.available.conf.envsubst ./
ADD geonode.conf.envsubst ./sites-enabled/

COPY --chmod=755 docker-autoreload.sh docker-entrypoint.sh /

# Diretórios escritos em runtime pelo entrypoint precisam pertencer ao usuário nginx.
# g=u permite rodar com UID arbitrário do grupo root (ex.: OpenShift).
RUN mkdir -p \
        /geonode-certificates/disabled \
        /geonode-certificates/staging \
        /geonode-certificates/production \
        /geonode-certificates/autoissued && \
    chown -R nginx:root /etc/nginx /geonode-certificates && \
    chmod -R g=u /etc/nginx /geonode-certificates

# uid 101 com grupo primário 0: os diretórios graváveis da imagem são grupo 0 com g=u, e o volume de
# certificados pode ser criado por outro container (letsencrypt) com grupo 0. No OpenShift o UID é
# substituído por um aleatório e o grupo 0 se mantém.
USER 101:0

EXPOSE 8080 8443

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
