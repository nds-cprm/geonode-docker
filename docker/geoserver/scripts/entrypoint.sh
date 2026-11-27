#!/bin/bash
# Expansões sem aspas herdadas do GeoNode (TAGNAME, $@, find): quotar mudaria os argumentos posicionais
# passados ao set_geoserver_auth.sh. Corrija com teste do stack inteiro, e não só no lint.
# shellcheck disable=SC2068,SC2145,SC2048,SC2044,SC2046
set -e

# Arquivos criados pelo entrypoint e pelos scripts chamados daqui com escrita do grupo 0 (g=u), para
# funcionar com qualquer UID do grupo 0. O Tomcat usa o mesmo valor (ENV UMASK no Dockerfile).
umask 0002

# Estado do entrypoint (.override_env) em $HOME: como root, /root; recomendado definir HOME=/tmp
# na execução. Se $HOME não for gravável (ex.: UID sem entrada no /etc/passwd, em que o runtime
# define HOME=/ ou o WORKDIR), usa /tmp. Exportado para os scripts chamados daqui.
if [ ! -w "${HOME:-/nonexistent}" ]; then
    HOME=/tmp
fi
export HOME
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi


INVOKE_LOG_STDOUT=${INVOKE_LOG_STDOUT:-TRUE}
invoke () {
    if [ $INVOKE_LOG_STDOUT = 'true' ] || [ $INVOKE_LOG_STDOUT = 'True' ]
    then
        /usr/local/bin/invoke $@
    else
        /usr/local/bin/invoke $@ > /usr/src/geonode/invoke.log 2>&1
    fi
    echo "$@ tasks done"
}


# create/populate the datadir
mkdir -p $GEOSERVER_DATA_DIR

if [ ! -f "${GEOSERVER_DATA_DIR}/global.xml" ]; then
    echo "${GEOSERVER_DATA_DIR}/global.xml not found."

    # needing a tmp extraction because the zip contains /data/ as root    
    echo "Extracting default data skeleton archive to temp dir..."
    # Extração dentro do próprio data dir (mesmo filesystem), e não em /tmp: com /tmp em tmpfs, o mv
    # entre filesystems copia também os xattrs, incluindo o rótulo SELinux privado deste container
    # (categorias MCS), e os outros containers que montam o volume (django/celery) não conseguiam ler.
    TMP_EXTRACT="$GEOSERVER_DATA_DIR/.skeleton_unzip"
    mkdir -p "$TMP_EXTRACT"
    unzip -q "$GEOSERVER_SHARE_DIR/geoserver-data-skeleton.zip" -d "$TMP_EXTRACT"
    echo "Moving default data skeleton archive directly to volume..."
    # .[!.]* em vez de .*: evita "." e "..", que aqui é o próprio diretório de extração
    mv -v "$TMP_EXTRACT"/data/* "$TMP_EXTRACT"/data/.[!.]* "$GEOSERVER_DATA_DIR/" || true
    rm -rf "$TMP_EXTRACT"
    # O zip do skeleton guarda permissões 644/755 (o unzip as restaura, sem respeitar o umask):
    # g=u no conteúdo para o grupo 0 poder alterá-lo com qualquer UID. A raiz do volume fica de fora:
    # ela vem do copy-up da imagem (já 775) e pode pertencer a outro UID, que não pode ser alterado.
    find "$GEOSERVER_DATA_DIR" -mindepth 1 -exec chmod g=u {} +

    echo "Extraction complete."
else
    echo "Existing GeoServer data configuration detected. Skipping extraction."
fi

# control the values of LB settings if present
if [ -n "$GEONODE_LB_HOST_IP" ];
then
    echo "GEONODE_LB_HOST_IP is defined and not empty with the value '$GEONODE_LB_HOST_IP' "
    echo export GEONODE_LB_HOST_IP=${GEONODE_LB_HOST_IP} >> "$HOME/.override_env"
else
    echo "GEONODE_LB_HOST_IP is either not defined or empty setting the value to 'django' "
    echo export GEONODE_LB_HOST_IP=django >> "$HOME/.override_env"
    export GEONODE_LB_HOST_IP=django
fi

if [ -n "$GEONODE_LB_PORT" ];
then
    echo "GEONODE_LB_HOST_IP is defined and not empty with the value '$GEONODE_LB_PORT' "
    echo export GEONODE_LB_PORT=${GEONODE_LB_PORT} >> "$HOME/.override_env"
else
    echo "GEONODE_LB_PORT is either not defined or empty setting the value to '8000' "
    echo export GEONODE_LB_PORT=8000 >> "$HOME/.override_env"
    export GEONODE_LB_PORT=8000
fi

if [ -n "$GEOSERVER_LB_HOST_IP" ];
then
    echo "GEOSERVER_LB_HOST_IP is defined and not empty with the value '$GEOSERVER_LB_HOST_IP' "
    echo export GEOSERVER_LB_HOST_IP=${GEOSERVER_LB_HOST_IP} >> "$HOME/.override_env"
else
    echo "GEOSERVER_LB_HOST_IP is either not defined or empty setting the value to 'geoserver' "
    echo export GEOSERVER_LB_HOST_IP=geoserver >> "$HOME/.override_env"
    export GEOSERVER_LB_HOST_IP=geoserver
fi

if [ -n "$GEOSERVER_LB_PORT" ];
then
    echo "GEOSERVER_LB_PORT is defined and not empty with the value '$GEOSERVER_LB_PORT' "
    echo export GEOSERVER_LB_PORT=${GEOSERVER_LB_PORT} >> "$HOME/.override_env"
else
    echo "GEOSERVER_LB_PORT is either not defined or empty setting the value to '8000' "
    echo export GEOSERVER_LB_PORT=8080 >> "$HOME/.override_env"
    export GEOSERVER_LB_PORT=8080
fi

# If DATABASE_HOST is not set in the environment, use the default value
if [ -n "$DATABASE_HOST" ];
then
    echo "DATABASE_HOST is defined and not empty with the value '$DATABASE_HOST' "
    echo export DATABASE_HOST=${DATABASE_HOST} >> "$HOME/.override_env"
else
    echo "DATABASE_HOST is either not defined or empty setting the value to 'db' "
    echo export DATABASE_HOST=db >> "$HOME/.override_env"
    export DATABASE_HOST=db
fi

# If DATABASE_PORT is not set in the environment, use the default value
if [ -n "$DATABASE_PORT" ];
then
    echo "DATABASE_PORT is defined and not empty with the value '$DATABASE_PORT' "
    echo export DATABASE_HOST=${DATABASE_PORT} >> "$HOME/.override_env"
else
    echo "DATABASE_PORT is either not defined or empty setting the value to '5432' "
    echo export DATABASE_PORT=5432 >> "$HOME/.override_env"
    export DATABASE_PORT=5432
fi

# If GEONODE_GEODATABASE_USER is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE" ];
then
    echo "GEONODE_GEODATABASE is defined and not empty with the value '$GEONODE_GEODATABASE' "
    echo export GEONODE_GEODATABASE=${GEONODE_GEODATABASE} >> "$HOME/.override_env"
else
    echo "GEONODE_GEODATABASE is either not defined or empty setting the value '${COMPOSE_PROJECT_NAME}_data' "
    echo export GEONODE_GEODATABASE=${COMPOSE_PROJECT_NAME}_data >> "$HOME/.override_env"
    export GEONODE_GEODATABASE=${COMPOSE_PROJECT_NAME}_data
fi

# If GEONODE_GEODATABASE_USER is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE_USER" ];
then
    echo "GEONODE_GEODATABASE_USER is defined and not empty with the value '$GEONODE_GEODATABASE_USER' "
    echo export GEONODE_GEODATABASE_USER=${GEONODE_GEODATABASE_USER} >> "$HOME/.override_env"
else
    echo "GEONODE_GEODATABASE_USER is either not defined or empty setting the value '$GEONODE_GEODATABASE' "
    echo export GEONODE_GEODATABASE_USER=${GEONODE_GEODATABASE} >> "$HOME/.override_env"
    export GEONODE_GEODATABASE_USER=${GEONODE_GEODATABASE}
fi

# If GEONODE_GEODATABASE_USER is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE_PASSWORD" ];
then
    echo "GEONODE_GEODATABASE_PASSWORD is defined and not empty (value hidden)"
    echo export GEONODE_GEODATABASE_PASSWORD=${GEONODE_GEODATABASE_PASSWORD} >> "$HOME/.override_env"
else
    echo "GEONODE_GEODATABASE_PASSWORD is either not defined or empty, setting a default value (value hidden)"
    echo export GEONODE_GEODATABASE_PASSWORD=${GEONODE_GEODATABASE} >> "$HOME/.override_env"
    export GEONODE_GEODATABASE_PASSWORD=${GEONODE_GEODATABASE}
fi

# If GEONODE_GEODATABASE_SCHEMA is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE_SCHEMA" ];
then
    echo "GEONODE_GEODATABASE_SCHEMA is defined and not empty with the value '$GEONODE_GEODATABASE_SCHEMA' "
    echo export GEONODE_GEODATABASE_SCHEMA=${GEONODE_GEODATABASE_SCHEMA} >> "$HOME/.override_env"
else
    echo "GEONODE_GEODATABASE_SCHEMA is either not defined or empty setting the value to 'public'"
    echo export GEONODE_GEODATABASE_SCHEMA=public >> "$HOME/.override_env"
    export GEONODE_GEODATABASE_SCHEMA=public
fi

if [ ! -z "${GEOSERVER_JAVA_OPTS}" ]
then
    echo "GEOSERVER_JAVA_OPTS is filled so I replace the value of '$JAVA_OPTS' with '$GEOSERVER_JAVA_OPTS'"
    export JAVA_OPTS=${GEOSERVER_JAVA_OPTS}
fi

# control the value of NGINX_BASE_URL variable
if [ -z `echo ${NGINX_BASE_URL} | sed 's/http:\/\/\([^:]*\).*/\1/'` ]
then
    echo "NGINX_BASE_URL is empty so I'll use the default Geoserver base url"
    echo "Setting GEOSERVER_LOCATION='${SITEURL}'"
    echo export GEOSERVER_LOCATION=${SITEURL} >> "$HOME/.override_env"
else
    echo "NGINX_BASE_URL is filled so GEOSERVER_LOCATION='${NGINX_BASE_URL}'"
    echo "Setting GEOSERVER_LOCATION='${NGINX_BASE_URL}'"
    echo export GEOSERVER_LOCATION=${NGINX_BASE_URL} >> "$HOME/.override_env"
fi

if [ -n "$SUBSTITUTION_URL" ];
then
    echo "SUBSTITUTION_URL is defined and not empty with the value '$SUBSTITUTION_URL'"
    echo "Setting GEONODE_LOCATION='${SUBSTITUTION_URL}' "
    echo export GEONODE_LOCATION=${SUBSTITUTION_URL} >> "$HOME/.override_env"
else
    echo "SUBSTITUTION_URL is either not defined or empty so I'll use the default GeoNode location "
    echo "Setting GEONODE_LOCATION='http://${GEONODE_LB_HOST_IP}:${GEONODE_LB_PORT}' "
    echo export GEONODE_LOCATION=http://${GEONODE_LB_HOST_IP}:${GEONODE_LB_PORT} >> "$HOME/.override_env"
fi

# set basic tagname
TAGNAME=( "baseUrl" "authApiKey" )

if ! [ -f ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ]
then
    echo "Configuration file '$GEOSERVER_DATA_DIR'/security/auth/geonodeAuthProvider/config.xml is not available so it is gone to skip "
else
    # backup geonodeAuthProvider config.xml
    cp ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml.orig
    # run the setting script for geonodeAuthProvider
    /usr/local/bin/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/ ${TAGNAME[@]} > /dev/null
fi

# backup geonode REST role service config.xml
cp "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml.orig"
# run the setting script for geonode REST role service
/usr/local/bin/set_geoserver_auth.sh "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/" ${TAGNAME[@]} > /dev/null

# set oauth2 filter tagname
TAGNAME=( "cliendId" "clientSecret" "accessTokenUri" "userAuthorizationUri" "redirectUri" "checkTokenEndpointUrl" "logoutUri" )

# backup geonode-oauth2 config.xml
cp ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml.orig
# run the setting script for geonode-oauth2
/usr/local/bin/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/ "${TAGNAME[@]}" > /dev/null

# set global tagname
TAGNAME=( "proxyBaseUrl" )

# backup global.xml
cp ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/global.xml.orig
# run the setting script for global configuration
/usr/local/bin/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/ ${TAGNAME[@]} > /dev/null

# Log do GeoServer em stdout (docker logs): liga o "Log to StdOut" da página "Global" da interface web
# (<stdOutLogging> do logging.xml) a cada boot. O perfil de log continua configurável na interface, e o
# GeoServer continua gravando também o logs/geoserver.log do data dir.
# sed para um arquivo temporário e cp por cima, como no set_geoserver_auth.sh: preserva o arquivo
# original (dono, permissões e rótulo SELinux do volume).
LOGGING_XML="${GEOSERVER_DATA_DIR}/logging.xml"
if [ -f "$LOGGING_XML" ] && grep -q "<stdOutLogging>false</stdOutLogging>" "$LOGGING_XML"; then
    logging_tmp=$(mktemp "${TMPDIR:-/tmp}/logging.xml.XXXXXX")
    sed 's#<stdOutLogging>false</stdOutLogging>#<stdOutLogging>true</stdOutLogging>#' "$LOGGING_XML" > "$logging_tmp" \
        && cp "$logging_tmp" "$LOGGING_XML" \
        && echo "GeoServer logging: stdOutLogging enabled in $LOGGING_XML"
    rm -f "$logging_tmp"
fi

# exclude wrong dependencies: feito no build (Dockerfile), para não alterar o conf/ do Tomcat em
# runtime (falhava sem root e com filesystem somente leitura, e duplicava a entrada a cada restart)

# templating for this docker image we should also do it for other configuration files in /usr/local/tomcat/tmp

declare -a geoserver_datadir_template_dirs=("geofence")

for template in ${geoserver_datadir_template_dirs[*]}; do
    if [ "$template" == "geofence" ]; then
        cp -vR $GEOSERVER_SHARE_DIR/templates/$template/* ${GEOSERVER_DATA_DIR}/geofence

        for f in $(find ${GEOSERVER_DATA_DIR}/geofence/ -type f -name "*.envsubst"); do
            echo -e "Evaluating template\n\tSource: $f\n\tDest: ${f%.envsubst}"
            envsubst < "$f" > "${f%.envsubst}"        
            rm -vf "$f"
        done
    fi
done

# configure CORS: o filtro está sempre no web.xml (inserido no build, Dockerfile e files/cors-filter.xml),
# sem sed em runtime (falhava sem root e com filesystem somente leitura). Com o CORS desligado e sem
# GEOSERVER_CORS_ALLOWED_ORIGINS definido, só a origem pública do GeoServer é permitida: requisições da
# mesma origem seguem funcionando e as de outros domínios são recusadas (403). Não pode ficar vazio:
# o ${VAR:-*} do filtro trataria o valor vazio como ausente e liberaria todas as origens.
if [ "${GEOSERVER_CORS_ENABLED}" != "true" ] && [ "${GEOSERVER_CORS_ENABLED}" != "True" ] && [ -z "${GEOSERVER_CORS_ALLOWED_ORIGINS}" ]; then
    public_url="${GEOSERVER_PUBLIC_LOCATION:-${SITEURL}}"
    public_origin=$(printf '%s' "$public_url" | sed -nE 's#^(https?://[^/]+).*#\1#p')
    export GEOSERVER_CORS_ALLOWED_ORIGINS="${public_origin:-http://cors-disabled.invalid}"
    echo "CORS disabled: allowing only the origin '${GEOSERVER_CORS_ALLOWED_ORIGINS}'"
fi

# Proxies confiáveis para o X-Forwarded-For (RemoteIpFilter do GeoServer), separados por vírgula. Sem
# a variável, o GeoServer só confia no loopback e trata o proxy reverso (nginx) como o cliente.
#
# Se não foi definida, usa as sub-redes IPv4 ligadas diretamente às interfaces do container (as redes do
# compose, onde estão as réplicas do nginx), lidas de /proc/net/route (a imagem não tem o comando "ip"),
# mais o loopback, que é o padrão do GeoServer e deixaria de valer. Os outros containers dessas redes
# também passam a ser confiáveis, e as sub-redes incluem o gateway: quem chega pela porta 8080 publicada
# pelo gateway (o próprio host e, conforme o motor, clientes externos) pode forjar o próprio IP. Fora do
# desenvolvimento, não publique a 8080.
#
# Se foi definida, aceita IPs, CIDRs e nomes de host. O GeoServer só aceita IPs e CIDRs, então os nomes
# são resolvidos aqui, uma vez no boot, para todos os endereços (getent); um nome que não resolver em
# GEOSERVER_TRUSTED_PROXIES_WAIT segundos (padrão 60) é deixado de fora, com um aviso. A resolução só
# vale até o GeoServer reiniciar: um proxy recriado com outro IP, ou uma réplica nova, fica de fora.
if [ -z "${GEOSERVER_TRUSTED_PROXIES}" ]; then
    # Rotas sem gateway e com destino diferente de 0.0.0.0, fora do lo: endereço e máscara em hexadecimal,
    # na ordem de bytes do kernel (little-endian em amd64 e arm64)
    detected_subnets=$(awk '
        function hex(s,   i, v) { v = 0; for (i = 1; i <= length(s); i++) v = v * 16 + index("0123456789ABCDEF", toupper(substr(s, i, 1))) - 1; return v }
        NR > 1 && $1 != "lo" && $2 != "00000000" && $3 == "00000000" {
            d = $2; m = hex($8); bits = 0
            while (m > 0) { bits += m % 2; m = int(m / 2) }
            printf "%d.%d.%d.%d/%d\n", hex(substr(d, 7, 2)), hex(substr(d, 5, 2)), hex(substr(d, 3, 2)), hex(substr(d, 1, 2)), bits
        }' /proc/net/route 2>/dev/null | sort -u | paste -sd, -)
    export GEOSERVER_TRUSTED_PROXIES="127.0.0.0/8,::1/128${detected_subnets:+,$detected_subnets}"
    echo "GEOSERVER_TRUSTED_PROXIES not set, trusting the container networks: ${GEOSERVER_TRUSTED_PROXIES}"
else
    GEOSERVER_TRUSTED_PROXIES_WAIT="${GEOSERVER_TRUSTED_PROXIES_WAIT:-60}"
    trusted_proxies=""
    for entry in ${GEOSERVER_TRUSTED_PROXIES//,/ }; do
        # IPv4 ou IPv6, com ou sem máscara, entra como está
        if printf '%s' "$entry" | grep -Eq '^([0-9]{1,3}(\.[0-9]{1,3}){3}|[0-9A-Fa-f]*:[0-9A-Fa-f:.]*)(/[0-9]{1,3})?$'; then
            trusted_proxies="${trusted_proxies:+$trusted_proxies,}$entry"
            continue
        fi
        addresses=""
        waited=0
        while :; do
            addresses=$(getent ahosts "$entry" 2>/dev/null | awk '{print $1}' | sort -u | paste -sd, -) || true
            if [ -n "$addresses" ] || [ "$waited" -ge "$GEOSERVER_TRUSTED_PROXIES_WAIT" ]; then
                break
            fi
            sleep 2
            waited=$((waited + 2))
        done
        if [ -n "$addresses" ]; then
            echo "GEOSERVER_TRUSTED_PROXIES: ${entry} -> ${addresses}"
            trusted_proxies="${trusted_proxies:+$trusted_proxies,}$addresses"
        else
            echo "WARNING: GEOSERVER_TRUSTED_PROXIES: could not resolve '${entry}' after ${waited}s, ignoring it" >&2
        fi
    done
    # Nada válido na lista: fica só o loopback, o padrão do GeoServer
    export GEOSERVER_TRUSTED_PROXIES="${trusted_proxies:-127.0.0.0/8,::1/128}"
    echo "GEOSERVER_TRUSTED_PROXIES: ${GEOSERVER_TRUSTED_PROXIES}"
fi

if [ "${FORCE_REINIT}" = "true" ] || [ "${FORCE_REINIT}" = "True" ] || [ ! -e "${GEOSERVER_DATA_DIR}/geoserver_init.lock" ]; then
    # Run async configuration, it needs GeoServer to be up and running
    nohup /usr/local/bin/configure_geoserver.sh &
fi

# start tomcat
exec env JAVA_OPTS="${JAVA_OPTS}" catalina.sh run
