ARG IMAGE_VERSION=9.0.123-jdk17-temurin-jammy
FROM docker.io/library/tomcat:$IMAGE_VERSION

ARG GEOSERVER_VERSION=2.28.6
#
# Set GeoServer version and data directory
#
ENV GEOSERVER_VERSION=${GEOSERVER_VERSION}
ENV GEOSERVER_DATA_DIR="/geoserver_data/data"

# Pacotes sem versão fixa: o apt da imagem base só mantém as versões da própria release
# hadolint ignore=DL3008
RUN apt-get update -y \
   && apt-get -y install --no-install-recommends curl wget unzip procps less gettext-base \
   && rm -rf /var/lib/apt/lists/*

#
# Download and install GeoServer
#
RUN wget --no-check-certificate --progress=bar:force:noscroll https://artifacts.geonode.org/geoserver/${GEOSERVER_VERSION}/geoserver.war -O /usr/local/tomcat/webapps/geoserver.war \
    && unzip -q /usr/local/tomcat/webapps/geoserver.war -d /usr/local/tomcat/webapps/geoserver \
    && rm /usr/local/tomcat/webapps/geoserver.war \
    && mkdir -p $GEOSERVER_DATA_DIR

#
# Extensões do GeoServer (mesma versão do war; GEOSERVER_VERSION precisa ser uma versão exata):
#  - excel: saída WFS em Excel (xls/xlsx)
#  - geopkg-output: saída WFS/WPS em GeoPackage
# GEOSERVER_EXTENSIONS="" (build arg) instala só o war.
#
ARG GEOSERVER_EXTENSIONS="excel geopkg-output"
RUN for extension in ${GEOSERVER_EXTENSIONS}; do \
        wget --no-check-certificate --progress=bar:force:noscroll -O /tmp/${extension}.zip \
            "https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions/geoserver-${GEOSERVER_VERSION}-${extension}-plugin.zip/download" \
        && unzip -q -o -j /tmp/${extension}.zip '*.jar' -d /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/ \
        && rm /tmp/${extension}.zip || exit 1; \
    done

# Fontes usadas nos estilos (SLD): simbologia geológica do SGB/CPRM e Material Symbols
COPY ./fonts/ /usr/share/fonts/truetype/

#
# Download datadir zip
# 
ENV GEOSERVER_SHARE_DIR="/usr/local/share/geoserver"
RUN mkdir -p $GEOSERVER_SHARE_DIR $GEOSERVER_SHARE_DIR/templates
RUN wget --no-check-certificate --progress=bar:force:noscroll \
    https://artifacts.geonode.org/geoserver/$GEOSERVER_VERSION/geonode-geoserver-ext-web-app-data.zip \
    -O $GEOSERVER_SHARE_DIR/geoserver-data-skeleton.zip


COPY ./templates $GEOSERVER_SHARE_DIR/templates
COPY ./files/applicationContext.xml /usr/local/tomcat/webapps/geoserver/WEB-INF/classes/applicationContext.xml

# CORS: o filtro do Tomcat (files/cors-filter.xml) é inserido sempre no web.xml no build, e não no
# entrypoint, para o webapp não ser alterado em runtime (sem root / somente leitura). O liga/desliga
# (GEOSERVER_CORS_ENABLED) e os valores (GEOSERVER_CORS_ALLOWED_*) continuam em runtime: o Tomcat
# resolve os ${...} do web.xml a partir do ambiente com o EnvironmentPropertySource (CATALINA_OPTS
# abaixo), e o entrypoint restringe as origens à origem pública quando o CORS está desligado.
COPY ./files/cors-filter.xml /tmp/cors-filter.xml
# Inserido logo após o mapeamento do "Set Character Encoding", no ponto onde o próprio GeoServer traz
# o exemplo de CORS comentado: precisa vir antes do Spring Security (filterChainProxy), senão
# respostas do login/autenticação saem sem passar pelo CORS. O build falha se a âncora não existir.
RUN W=$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml \
    && grep -q "Uncomment following filter-mapping to enable CORS" $W \
    && sed -i "/Uncomment following filter-mapping to enable CORS/e cat /tmp/cors-filter.xml" $W \
    && grep -q DockerGeoServerCorsFilter $W \
    && rm -f /tmp/cors-filter.xml
ENV CATALINA_OPTS="-Dorg.apache.tomcat.util.digester.PROPERTY_SOURCE=org.apache.tomcat.util.digester.EnvironmentPropertySource"

# umask do Tomcat (catalina.sh, padrão 0027): 0002 para os arquivos que o GeoServer cria em runtime
# (data dir, GWC, logs) nascerem com escrita do grupo 0 (g=u), funcionando com qualquer UID do grupo 0.
# O SecurityListener, que exigiria umask >= 0007, está desabilitado no server.xml da imagem base.
ENV UMASK=0002

# Tomcat: não varrer o Bouncy Castle (bcprov) no scan de jars do startup. Feito no build, e não no
# entrypoint, para o conf/ não ser alterado em runtime (sem root / somente leitura). O grep falha o
# build se uma nova versão da imagem base mudar a linha e a substituição deixar de casar.
RUN sed -i -e 's/xom-\*\.jar/xom-\*\.jar,bcprov\*\.jar/' /usr/local/tomcat/conf/catalina.properties \
    && grep -q 'bcprov\*\.jar' /usr/local/tomcat/conf/catalina.properties

# Diretório de descritores de contexto do host (conf/Catalina/localhost): o Tomcat tenta criá-lo no
# startup se não existir, o que falha sem root ou com filesystem somente leitura (SEVERE
# "Unable to create directory for deployment"). Criado vazio no build, com grupo 0 e g=u.
RUN mkdir -p $CATALINA_HOME/conf/Catalina/localhost \
    && chgrp -R 0 $CATALINA_HOME/conf/Catalina \
    && chmod -R g=u $CATALINA_HOME/conf/Catalina

# Só scripts .sh no diretório: --chmod=755 vale para todos (e para subdiretórios, se surgirem).
COPY --chmod=755 ./scripts/ /usr/local/bin/

# Data dir e pontos de montagem dos volumes compartilhados com o GeoNode (statics, backup_restore,
# data) graváveis por qualquer UID do grupo 0 (rootless/OpenShift, UID arbitrário): num volume novo,
# o primeiro container que o monta define dono e permissões pelo copy-up deste diretório. Precisa
# vir antes do VOLUME, porque alterações posteriores no caminho do volume são descartadas.
RUN mkdir -p /mnt/volumes/statics /backup_restore /data &&\
    chgrp -R 0 $GEOSERVER_DATA_DIR /mnt/volumes/statics /backup_restore /data &&\
    chmod -R g=u $GEOSERVER_DATA_DIR /mnt/volumes/statics /backup_restore /data

VOLUME $GEOSERVER_DATA_DIR

# Access log do Tomcat em stdout (docker logs), em vez de um arquivo em $CATALINA_BASE/logs, que cresce
# sem limite de tamanho (o Tomcat só faz rotação diária). Sem rotação nem buffer: o arquivo é /dev/stdout.
# O grep falha o build se a imagem base mudar a linha do AccessLogValve.
RUN sed -i 's#AccessLogValve" directory="logs"#AccessLogValve" directory="/dev"#' $CATALINA_HOME/conf/server.xml \
    && sed -i 's#prefix="localhost_access_log" suffix=".txt"#prefix="stdout" suffix="" rotatable="false" buffered="false"#' $CATALINA_HOME/conf/server.xml \
    && grep -q 'AccessLogValve" directory="/dev"' $CATALINA_HOME/conf/server.xml \
    && grep -q 'prefix="stdout" suffix="" rotatable="false" buffered="false"' $CATALINA_HOME/conf/server.xml

ENV JAVA_OPTS="-Djava.awt.headless=true -Dgwc.context.suffix=gwc -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/tmp/jvm.log -Xms2048m -Xmx2048m -XX:ParallelGCThreads=4 -Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=false -DGS-SHAPEFILE-CHARSET=UTF-8 -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://geoserver:8080/geoserver/pdf"

# Repete o ARG do FROM para usá-lo no rótulo da base
ARG IMAGE_VERSION
# Rótulos OCI. No fim do arquivo, para que VERSION/REVISION/CREATED (que mudam a cada build) não
# invalidem o cache das camadas anteriores.
ARG VERSION=dev
ARG REVISION=unknown
ARG CREATED=unknown
LABEL org.opencontainers.image.title="OpenGeoSGB GeoServer" \
      org.opencontainers.image.description="GeoServer (Tomcat) com as extensões do SGB/CPRM para o GeoNode" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.authors="NDS CPRM" \
      org.opencontainers.image.vendor="Serviço Geológico do Brasil (SGB/CPRM)" \
      org.opencontainers.image.url="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.source="https://github.com/nds-cprm/geonode-docker" \
      org.opencontainers.image.documentation="https://github.com/nds-cprm/geonode-docker#readme" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.base.name="docker.io/library/tomcat:${IMAGE_VERSION}"

CMD ["/usr/local/bin/entrypoint.sh"]
