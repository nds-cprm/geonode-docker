#!/bin/bash

auth_conf_source="$1"
auth_conf_target="$2"
# Arquivo temporário para o sed: em /tmp (gravável por qualquer UID e com o filesystem somente
# leitura), e não no diretório de trabalho (/usr/local/tomcat, root 755), onde a criação falhava
# sem root e a configuração do GeoNode deixava de ser aplicada em silêncio.
temp_file=$(mktemp "${TMPDIR:-/tmp}/set_geoserver_auth.XXXXXX") || {
    echo "set_geoserver_auth: could not create temporary file" >&2
    exit 1
}
trap 'rm -f "$temp_file"' EXIT

# Tags cujos valores são segredos: nunca imprimir o valor
secret_tags=" authApiKey cliendId clientSecret "
show_value() {
    case "$secret_tags" in
        *" $1 "*) echo "(value hidden)";;
        *) echo "'$2'";;
    esac
}

# Mesmo $HOME do entrypoint (ver entrypoint.sh): /root como root, HOME=/tmp recomendado na execução
if [ ! -w "${HOME:-/nonexistent}" ]; then
    HOME=/tmp
fi
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi
source "$HOME/.override_env"

test -z "$auth_conf_source" && echo "You must specify a source file" && exit 1
test -z "$auth_conf_target" && echo "You must specify a target conf directory" && exit 1

test ! -f "$auth_conf_source" && echo "Source $auth_conf_source does not exist or is not a file" && exit 1
test ! -d "$auth_conf_target" && echo "Target directory $auth_conf_target does not exist or is not a directory" && exit 1

# for debugging
# Comentado: imprime segredos (OAuth2 e senha do banco). Hoje a saída do script vai para
# /dev/null no entrypoint, mas vazaria se o script fosse executado manualmente ou se o
# redirecionamento fosse removido.
# echo -e "OAUTH2_API_KEY=$OAUTH2_API_KEY\n"
# echo -e "OAUTH2_CLIENT_ID=$OAUTH2_CLIENT_ID\n"
# echo -e "OAUTH2_CLIENT_SECRET=$OAUTH2_CLIENT_SECRET\n"
# echo -e "GEOSERVER_LOCATION=$GEOSERVER_LOCATION\n"
# echo -e "GEONODE_LOCATION=$GEONODE_LOCATION\n"
# echo -e "GEONODE_GEODATABASE=$GEONODE_GEODATABASE\n"
# echo -e "GEONODE_GEODATABASE_USER=$GEONODE_GEODATABASE_USER\n"
# echo -e "GEONODE_GEODATABASE_PASSWORD=$GEONODE_GEODATABASE_PASSWORD\n"
# echo -e "auth_conf_source=$auth_conf_source\n"
# echo -e "auth_conf_target=$auth_conf_target\n"

# Elegance is the key -> adding an empty last line for Mr. “sed” to pick up
echo " " >> "$auth_conf_source"

# Comentado: o XML contém segredos (ex.: clientSecret do OAuth2)
# cat "$auth_conf_source"

# Sem aspas de propósito: cada argumento passa por separação de palavras, como sempre foi
# shellcheck disable=SC2206
tagname=( ${@:3:7} )

# for debugging
for i in "${tagname[@]}"
do
   echo "tagname=<$i>"
done

echo "DEBUG: Starting... [Ok]\n"

# Escape a string for safe use in sed's REGEX (pattern) side, given @ delimiter
escape_regex() {
    printf '%s' "$1" | sed -e 's/[][\\.^$*+?(){}|@/-]/\\&/g'
}

# Escape a string for safe use in sed's REPLACEMENT side, given @ delimiter
escape_replacement() {
    printf '%s' "$1" | sed -e 's/[\\&@/]/\\&/g'
}

for i in "${tagname[@]}"
do
    echo "DEBUG: Working on '$auth_conf_source' for tagname <$i>"
    tagvalue=`grep "<$i>.*<.$i>" "$auth_conf_source" | sed -e "s/^.*<$i/<$i/" | cut -f2 -d">" | cut -f1 -d"<"`
    echo "DEBUG: Found the current value for the element <$i> - $(show_value "$i" "$tagvalue")"

    case $i in
        authApiKey)
            newvalue="$OAUTH2_API_KEY";;
        cliendId)
            newvalue="$OAUTH2_CLIENT_ID";;
        clientSecret)
            newvalue="$OAUTH2_CLIENT_SECRET";;
        proxyBaseUrl | redirectUri | userAuthorizationUri | logoutUri )
            newvalue=`printf '%s' "$tagvalue" | sed -re "s@^(https?://[^/]+)@${GEOSERVER_LOCATION%/}@"`;;
        baseUrl | accessTokenUri | checkTokenEndpointUrl )
            newvalue=`printf '%s' "$tagvalue" | sed -re "s@^(https?://[^/]+)@${GEONODE_LOCATION%/}@"`;;
        *) echo "an unknown variable has been found"; continue;;
    esac

    echo "DEBUG: Found the new value for the element <$i> - $(show_value "$i" "$newvalue")"

    # Match the whole element (empty or not); only the tag name is interpolated,
    # so the user-controlled content goes through the escapers.
    new_esc=`escape_replacement "$newvalue"`
    if ! sed -E "s@(<$i>)[^<]*(</$i>)@\1${new_esc}\2@g" "$auth_conf_source" > "$temp_file" \
        || ! cp "$temp_file" "$auth_conf_source"; then
        echo "set_geoserver_auth: failed to update <$i> in $auth_conf_source" >&2
        exit 1
    fi
done
# Writing our changes back to the original file ($auth_conf_source)
# no longer needed
# mv $temp_file $auth_conf_source

echo "DEBUG: Finished... [Ok]"
# Comentado: o XML contém segredos (ex.: clientSecret do OAuth2)
# cat "$auth_conf_source"
