ARG IMAGE_VERSION=9.0.106-jdk11-temurin-jammy
ARG JAVA_HOME=/usr/local/openjdk-11
FROM tomcat:$IMAGE_VERSION
LABEL GeoNode Development Team

ARG GEOSERVER_VERSION=2.27.1
ARG GEOSERVER_CORS_ENABLED=False
ARG GEOSERVER_CORS_ALLOWED_ORIGINS=*
ARG GEOSERVER_CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG GEOSERVER_CORS_ALLOWED_HEADERS=*
#
# Set GeoServer version and data directory
#
ENV GEOSERVER_VERSION=${GEOSERVER_VERSION}
ENV GEOSERVER_DATA_DIR="/geoserver_data/data"
ENV GEOSERVER_CORS_ENABLED=$GEOSERVER_CORS_ENABLED
ENV GEOSERVER_CORS_ALLOWED_ORIGINS=$GEOSERVER_CORS_ALLOWED_ORIGINS
ENV GEOSERVER_CORS_ALLOWED_METHODS=$GEOSERVER_CORS_ALLOWED_METHODS
ENV GEOSERVER_CORS_ALLOWED_HEADERS=$GEOSERVER_CORS_ALLOWED_HEADERS

#
# Download and install GeoServer
#
RUN apt-get update -y && apt-get install curl wget unzip -y
RUN cd /usr/local/tomcat/webapps \
    && wget --no-check-certificate --progress=bar:force:noscroll https://artifacts.geonode.org/geoserver/${GEOSERVER_VERSION}/geoserver.war -O geoserver.war \
    && unzip -q geoserver.war -d geoserver \
    && rm geoserver.war \
    && mkdir -p $GEOSERVER_DATA_DIR

VOLUME $GEOSERVER_DATA_DIR

# copy the script and perform the run of scripts from entrypoint.sh
RUN mkdir -p /usr/local/tomcat/tmp
WORKDIR /usr/local/tomcat/tmp
COPY set_geoserver_auth.sh \
     entrypoint.sh \
     tasks.py \
     multidump.sh \
     multidump-alt.sh \
     /usr/local/tomcat/tmp/

COPY ./templates /templates

RUN chmod +x \
        /usr/local/tomcat/tmp/set_geoserver_auth.sh \
        /usr/local/tomcat/tmp/entrypoint.sh

RUN apt-get install -y procps less && \
    apt-get install -y python3 python3-pip python3-dev

RUN pip install j2cli invoke==2.2.0 requests==2.31.0

ENV JAVA_OPTS="-Djava.awt.headless=true -Dgwc.context.suffix=gwc -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/var/log/jvm.log -XX:MaxPermSize=512m -XX:PermSize=256m -Xms512m -Xmx2048m -XX:+UseConcMarkSweepGC -XX:ParallelGCThreads=4 -Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=false -DGS-SHAPEFILE-CHARSET=UTF-8 -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://geoserver:8080/geoserver/pdf -Xbootclasspath/a:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/marlin-0.9.3.jar -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine"

CMD ["/usr/local/tomcat/tmp/entrypoint.sh"]
