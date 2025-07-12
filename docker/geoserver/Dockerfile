ARG IMAGE_VERSION=9.0.106-jdk11-temurin-jammy
ARG JAVA_HOME=/usr/local/openjdk-11
FROM tomcat:$IMAGE_VERSION

ARG GEOSERVER_VERSION=2.27.1
ARG GEONODE_LOG_DIR=/var/log/geonode
ARG GEOSERVER_CORS_ENABLED=False
ARG GEOSERVER_CORS_ALLOWED_ORIGINS=*
ARG GEOSERVER_CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG GEOSERVER_CORS_ALLOWED_HEADERS=*

# Some label best practices
# https://www.docker.com/blog/docker-best-practices-using-tags-and-labels-to-manage-docker-image-sprawl/
LABEL org.opencontainers.image.title="GeoNode's Geoserver image" \
    org.opencontainers.image.version=${GEOSERVER_VERSION} \
    org.opencontainers.image.vendor="GeoNode Development Team"

#
# Set GeoServer version and data directory
#
ENV GEOSERVER_VERSION=${GEOSERVER_VERSION} \
    GEOSERVER_DATA_DIR="/geoserver_data/data" \
    GEONODE_LOG_DIR=${GEONODE_LOG_DIR} \
    GEOSERVER_CORS_ENABLED=$GEOSERVER_CORS_ENABLED \
    GEOSERVER_CORS_ALLOWED_ORIGINS=$GEOSERVER_CORS_ALLOWED_ORIGINS \
    GEOSERVER_CORS_ALLOWED_METHODS=$GEOSERVER_CORS_ALLOWED_METHODS \
    GEOSERVER_CORS_ALLOWED_HEADERS=$GEOSERVER_CORS_ALLOWED_HEADERS \
    FORCE_REINIT=false \
    INVOKE_LOG_STDOUT=true \
    CATALINA_OPTS="-Djava.awt.headless=true -Dgwc.context.suffix=gwc -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=${GEONODE_LOG_DIR}/jvm.log -XX:MaxPermSize=512m -XX:PermSize=256m -Xms512m -Xmx2048m -XX:+UseConcMarkSweepGC -XX:ParallelGCThreads=4 -Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=false -DGS-SHAPEFILE-CHARSET=UTF-8 -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://geoserver:8080/geoserver/pdf -Xbootclasspath/a:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/marlin-0.9.3.jar -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine"

#
# Install required packages (no need to use curl and wget)
#
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        curl \
        # wget \
        unzip \
        procps \
        less \
        python3-minimal \
        python3-pip && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir j2cli invoke==2.2.0 requests==2.31.0


#
# Download and install GeoServer
#
WORKDIR /usr/local/tomcat/webapps

RUN curl --fail --silent --show-error --location --output geoserver.war \
        https://artifacts.geonode.org/geoserver/${GEOSERVER_VERSION}/geoserver.war && \
    unzip -q geoserver.war -d geoserver && \
    rm geoserver.war 

# copy the script and perform the run of scripts from entrypoint.sh
WORKDIR /usr/local/tomcat/tmp

COPY set_geoserver_auth.sh entrypoint.sh tasks.py multidump.sh multidump-alt.sh \
     /usr/local/tomcat/tmp/

COPY ./templates /templates

# create the data and logs directory and set permissions
RUN mkdir -p ${GEOSERVER_DATA_DIR} ${GEONODE_LOG_DIR} ${CATALINA_HOME}/conf/Catalina/localhost && \
    chmod +x set_geoserver_auth.sh entrypoint.sh && \
    cp ${CATALINA_HOME}/conf/catalina.properties ${CATALINA_HOME}/conf/catalina.properties.orig && \
    cp ${CATALINA_HOME}/webapps/geoserver/WEB-INF/web.xml ${CATALINA_HOME}/webapps/geoserver/WEB-INF/web.xml.orig && \
    chmod -R g=u \
        ${GEOSERVER_DATA_DIR} \
        ${GEONODE_LOG_DIR} \
        ${CATALINA_HOME}/conf/Catalina/localhost \
        ${CATALINA_HOME}/conf/catalina.properties \
        ${CATALINA_HOME}/webapps/geoserver/WEB-INF/web.xml

VOLUME ${GEOSERVER_DATA_DIR}

ENTRYPOINT [ "/usr/local/tomcat/tmp/entrypoint.sh" ]

CMD [ "catalina.sh", "run"]
