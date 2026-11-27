ARG NGINX_VERSION=1.31.10
# Imagem rootless: roda como usuário nginx (uid 101) e escuta em 8080 (HTTP) / 8443 (HTTPS)
FROM docker.io/nginx/nginx-unprivileged:${NGINX_VERSION}-alpine

USER root

# Pacotes sem versão fixa: o apk da imagem base (alpine) só mantém as versões da própria release
# hadolint ignore=DL3018
RUN apk add --no-cache openssl inotify-tools vim

WORKDIR /etc/nginx/

RUN mkdir -p /etc/nginx/html &&\
    touch /etc/nginx/html/index.html

COPY nginx.conf.envsubst nginx.https.available.conf.envsubst ./
COPY geonode.conf.envsubst ./sites-enabled/

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

# O entrypoint gera a configuração em /tmp/nginx (ver docker-entrypoint.sh), e não no /etc/nginx,
# para o container poder rodar com o filesystem somente leitura. O link mantém o caminho padrão do
# nginx.conf, usado pelo CMD e pelo "nginx -t"/"nginx -s reload" do autoreload.
# Depois do chown/chmod -R, para eles não seguirem o link (pendente no build).
RUN ln -sf /tmp/nginx/nginx.conf /etc/nginx/nginx.conf

# uid 101 com grupo primário 0: os diretórios graváveis da imagem são grupo 0 com g=u, e o volume de
# certificados pode ser criado por outro container (letsencrypt) com grupo 0. No OpenShift o UID é
# substituído por um aleatório e o grupo 0 se mantém.
USER 101:0

EXPOSE 8080 8443

# Repete o ARG do FROM para usá-lo no rótulo da base
ARG NGINX_VERSION
# Rótulos OCI. No fim do arquivo, para que VERSION/REVISION/CREATED (que mudam a cada build) não
# invalidem o cache das camadas anteriores.
ARG VERSION=dev
ARG REVISION=unknown
ARG CREATED=unknown
LABEL org.opencontainers.image.title="OpenGeoSGB nginx" \
      org.opencontainers.image.description="Proxy reverso (nginx rootless) do GeoNode do Serviço Geológico do Brasil (SGB/CPRM)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.authors="NDS CPRM" \
      org.opencontainers.image.vendor="Serviço Geológico do Brasil (SGB/CPRM)" \
      org.opencontainers.image.url="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.source="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.documentation="https://github.com/nds-cprm/geonode-docker#readme" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.base.name="docker.io/nginx/nginx-unprivileged:${NGINX_VERSION}-alpine"


ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
