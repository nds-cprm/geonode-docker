#!/bin/sh

# Exit script in case of error
set -e

echo $"\n\n\n"
echo "-----------------------------------------------------"
echo "STARTING NGINX ENTRYPOINT ---------------------------"
date

# We make the config dir
mkdir -p "/geonode-certificates/$LETSENCRYPT_MODE"

# Configuração gerada a cada boot: fica em /tmp/nginx, e não no /etc/nginx, para o filesystem da
# imagem poder ser somente leitura (read_only + tmpfs em /tmp). O /etc/nginx/nginx.conf da imagem é
# um link para /tmp/nginx/nginx.conf, por isso "nginx", "nginx -t" e "nginx -s reload" não mudam.
RUNTIME_DIR=/tmp/nginx
mkdir -p "$RUNTIME_DIR/sites-enabled"

echo "Creating autoissued certificates for HTTP host"
if [ ! -f "/geonode-certificates/autoissued/privkey.pem" ] || [[ $(find /geonode-certificates/autoissued/privkey.pem -mtime +365 -print) ]]; then
        echo "Autoissued certificate does not exist or is too old, we generate one"
        mkdir -p "/geonode-certificates/autoissued/"
        openssl req -x509 -nodes -days 1825 -newkey rsa:2048 -keyout "/geonode-certificates/autoissued/privkey.pem" -out "/geonode-certificates/autoissued/fullchain.pem" -subj "/CN=${HTTPS_HOST:-$HTTP_HOST}" -addext "subjectAltName=DNS:${HTTPS_HOST:-$HTTP_HOST}"
else
        echo "Autoissued certificate already exists"
fi

echo "Creating symbolic link for HTTPS certificate"
# for some reason, the ln -f flag doesn't work below...
# TODO : not DRY (reuse same scripts as docker-autoreload.sh)
rm -f "$RUNTIME_DIR/certificate_symlink"
if [ -f "/geonode-certificates/$LETSENCRYPT_MODE/live/$HTTPS_HOST/fullchain.pem" ] && [ -f "/geonode-certificates/$LETSENCRYPT_MODE/live/$HTTPS_HOST/privkey.pem" ]; then
        echo "Certbot certificate exists, we symlink to the live cert"
        ln -sf "/geonode-certificates/$LETSENCRYPT_MODE/live/$HTTPS_HOST" "$RUNTIME_DIR/certificate_symlink"
else
        echo "Certbot certificate does not exist, we symlink to autoissued"
        ln -sf "/geonode-certificates/autoissued" "$RUNTIME_DIR/certificate_symlink"
fi

if [ -z "${HTTPS_HOST}" ]; then
        LISTEN_SCHEME="http"
        PUBLIC_NAME="${HTTP_HOST}"
        PUBLIC_PORT_DEFAULT="${HTTP_PORT}"
else
        LISTEN_SCHEME="https"
        PUBLIC_NAME="${HTTPS_HOST}"
        PUBLIC_PORT_DEFAULT="${HTTPS_PORT}"
fi

# Proxy externo (ex.: HAProxy em "mode http" terminando TLS): o esquema e a porta que o navegador
# vê diferem dos que o nginx escuta. PUBLIC_SCHEME/PUBLIC_PORT sobrescrevem os valores deduzidos
# de HTTPS_HOST e HTTP_PORT/HTTPS_PORT. Sem eles, o comportamento é o de antes.
HTTP_SCHEME="${PUBLIC_SCHEME:-$LISTEN_SCHEME}"
if [ -n "${PUBLIC_PORT}" ]; then
        PORT="${PUBLIC_PORT}"
elif [ -n "${PUBLIC_SCHEME}" ]; then
        PORT=$([ "${PUBLIC_SCHEME}" = "https" ] && echo 443 || echo 80)
else
        PORT="${PUBLIC_PORT_DEFAULT}"
fi
case "${HTTP_SCHEME}:${PORT}" in
        http:80|https:443|http:|https:) PUBLIC_HOST="${PUBLIC_NAME}" ;;
        *)                              PUBLIC_HOST="${PUBLIC_NAME}:${PORT}" ;;
esac
echo "Public URL: ${HTTP_SCHEME}://${PUBLIC_HOST}"

# Nomes extras aceitos além de HTTP_HOST/HTTPS_HOST (ex.: o nome ou IP interno que o proxy envia
# no Host, quando ele não preserva o Host original). Separados por espaço.
export NGINX_EXTRA_SERVER_NAMES="${NGINX_EXTRA_SERVER_NAMES:-}"

# IP real do cliente (módulo realip): o X-Forwarded-For (ex.: "option forwardfor" do HAProxy) só é
# aceito de PROXY_TRUSTED_ADDRESSES (IPs/CIDRs separados por espaço, vírgula ou ponto e vírgula).
# Sem a variável, $remote_addr é o IP da conexão.
: > "$RUNTIME_DIR/realip.conf"
if [ -n "${PROXY_TRUSTED_ADDRESSES}" ]; then
        for addr in $(echo "${PROXY_TRUSTED_ADDRESSES}" | tr ',;' '  '); do
                echo "set_real_ip_from ${addr};" >> "$RUNTIME_DIR/realip.conf"
        done
        printf 'real_ip_header %s;\nreal_ip_recursive on;\n' "${PROXY_REAL_IP_HEADER:-X-Forwarded-For}" >> "$RUNTIME_DIR/realip.conf"
        echo "Trusting client IP from ${PROXY_REAL_IP_HEADER:-X-Forwarded-For} sent by: ${PROXY_TRUSTED_ADDRESSES}"
fi

# Pasta dos assets do GeoNode (rota interna /_assets_internal/, X-Accel-Redirect); a mesma do Django,
# no volume statics. Com barra no fim, por causa do alias.
ASSETS_ROOT=${ASSETS_ROOT:-/mnt/volumes/statics/assets/}
export ASSETS_ROOT="${ASSETS_ROOT%/}/"

# Arquivo temporário de resposta por requisição (proxy_max_temp_file_size, no proxy_temp_path em disco)
export NGINX_PROXY_MAX_TEMP_FILE_SIZE=${NGINX_PROXY_MAX_TEMP_FILE_SIZE:-2048m}

# Downloads simultâneos por IP de cliente nas rotas de arquivo do Django (map no nginx.conf). Acima do
# limite, 429. Atrás de proxy externo, precisa de PROXY_TRUSTED_ADDRESSES: sem ele, todos os clientes
# aparecem com o IP do proxy e dividem o mesmo limite. 0 desliga.
NGINX_DOWNLOADS_PER_IP=${NGINX_DOWNLOADS_PER_IP:-8}
if [ "${NGINX_DOWNLOADS_PER_IP}" -gt 0 ] 2>/dev/null; then
        printf 'limit_conn downloads %s;\nlimit_conn_status 429;\nlimit_conn_log_level warn;\n' "${NGINX_DOWNLOADS_PER_IP}" > "$RUNTIME_DIR/download-limit.conf"
        echo "Limiting downloads to ${NGINX_DOWNLOADS_PER_IP} per client IP"
else
        : > "$RUNTIME_DIR/download-limit.conf"
        echo "Download limit per client IP disabled"
fi

export HTTP_VERSION=${HTTP_VERSION:-2}
export HTTP2_TOGGLE=$([ "$HTTP_VERSION" = "2" ] && echo "on" || echo "off")
export HTTP_SCHEME=${HTTP_SCHEME:-http}
export GEONODE_LB_HOST_IP=${GEONODE_LB_HOST_IP:-django}
export GEONODE_LB_PORT=${GEONODE_LB_PORT:-8000}
export GEOSERVER_LB_HOST_IP=${GEOSERVER_LB_HOST_IP:-geoserver}
export GEOSERVER_LB_PORT=${GEOSERVER_LB_PORT:-8080}
export PUBLIC_HOST=${PUBLIC_HOST}

# DNS usado pelo nginx para resolver os upstreams em runtime (diretiva "resolver").
# Se RESOLVER não for definido, usa o primeiro nameserver do /etc/resolv.conf do container:
# funciona com Docker (127.0.0.11) e Podman (aardvark-dns no gateway da rede, ex.: 10.89.x.1)
# sem depender da sub-rede atribuída. IPv6 precisa ir entre colchetes na diretiva do nginx.
if [ -z "${RESOLVER}" ]; then
        RESOLVER=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
        case "$RESOLVER" in
                *:*) RESOLVER="[$RESOLVER]" ;;
        esac
fi
export RESOLVER=${RESOLVER:-127.0.0.11}
echo "Using resolver: $RESOLVER"

defined_envs=$(printf '${%s} ' $(env | cut -d= -f1))

echo "Replacing environment variables"
envsubst "$defined_envs" < /etc/nginx/nginx.conf.envsubst > "$RUNTIME_DIR/nginx.conf"
envsubst "$defined_envs" < /etc/nginx/nginx.https.available.conf.envsubst > "$RUNTIME_DIR/nginx.https.available.conf"
envsubst "$defined_envs" < /etc/nginx/sites-enabled/geonode.conf.envsubst > "$RUNTIME_DIR/sites-enabled/geonode.conf"

echo "Enabling or not https configuration"
if [ -z "${HTTPS_HOST}" ]; then
        # rm antes: num restart, o arquivo pode ser o link do boot anterior (com HTTPS)
        rm -f "$RUNTIME_DIR/nginx.https.enabled.conf"
        echo "" > "$RUNTIME_DIR/nginx.https.enabled.conf"
else
        ln -sf "$RUNTIME_DIR/nginx.https.available.conf" "$RUNTIME_DIR/nginx.https.enabled.conf"
fi

echo "Loading nginx autoreloader"
sh /docker-autoreload.sh &

echo "-----------------------------------------------------"
echo "FINISHED NGINX ENTRYPOINT ---------------------------"
echo "-----------------------------------------------------"

# Run the CMD 
exec "$@"
