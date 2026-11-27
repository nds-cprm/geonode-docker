#!/bin/sh
# O /bin/sh da imagem (alpine) é o ash do busybox, que aceita [[ ]] e ==
# shellcheck shell=busybox

# Exit script in case of error
set -e

# Linha de separação nos logs, mantida como está (não é POSIX, mas só imprime o banner)
# shellcheck disable=SC3004
echo $"\n\n\n"
echo "-----------------------------------------------------"
echo "STARTING LETSENCRYPT ENTRYPOINT ---------------------"
date

# We make the config dir
mkdir -p "/geonode-certificates/$LETSENCRYPT_MODE"

# Do not exit script in case of error
set +e

# Depois de cada emissão ou renovação, deixa certificados e chaves legíveis pelo grupo 0 (g=u): o
# certbot cria live/ e archive/ com 700 e o privkey.pem com 600, e o nginx pode rodar com outro UID
# do grupo 0 (ex.: UID aleatório do OpenShift).
# O diretório de configuração recebe g=u sem recursão, para o grupo atravessá-lo sem expor accounts/.
DEPLOY_HOOK="chmod g=u /geonode-certificates/$LETSENCRYPT_MODE && chmod -R g=u /geonode-certificates/$LETSENCRYPT_MODE/live /geonode-certificates/$LETSENCRYPT_MODE/archive"

# We run the command
if [ "$LETSENCRYPT_MODE" == "staging" ]; then
    printf "\nTrying to get STAGING certificate\n"
    certbot --config-dir "/geonode-certificates/$LETSENCRYPT_MODE" certonly --webroot -w "/geonode-certificates" -d "$HTTPS_HOST" -m "$ADMIN_EMAIL" --agree-tos --non-interactive --deploy-hook "$DEPLOY_HOOK" --test-cert
elif [ "$LETSENCRYPT_MODE" == "production" ]; then
    printf "\nTrying to get PRODUCTION certificate\n"
    certbot --config-dir "/geonode-certificates/$LETSENCRYPT_MODE" certonly --webroot -w "/geonode-certificates" -d "$HTTPS_HOST" -m "$ADMIN_EMAIL" --agree-tos --non-interactive --deploy-hook "$DEPLOY_HOOK" --server https://acme-v02.api.letsencrypt.org/directory
elif [ "$LETSENCRYPT_MODE" == "disabled" ]; then
    printf "\nNot trying to get certificate (because LETSENCRYPT_MODE variable is set to disabled) - and stop container\n"
    exit 0
else
    printf "\nNot trying to get certificate (simulating failure, because LETSENCRYPT_MODE variable was neither staging nor production\n"
    /bin/false
fi

# If the certbot comand failed, we will create a placeholder certificate
if [ ! $? -eq 0 ]; then
    # Exit script in case of error
    set -e

    printf "\nFailed to get the certificates !\n"

    printf "\nWaiting 30s to avoid hitting Letsencrypt rate limits before it's even possible to react\n"
    sleep 30

    exit 1
fi

printf "\nCertificate have been created/renewed successfully\n"

echo "-----------------------------------------------------"
echo "FINISHED LETSENCRYPT ENTRYPOINT ---------------------"
echo "-----------------------------------------------------"

# Run the CMD
exec "$@"
