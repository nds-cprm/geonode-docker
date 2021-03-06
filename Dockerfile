FROM python:3.8.3-buster
LABEL GeoNode development team

RUN mkdir -p /usr/src/{app,geonode}

# Enable postgresql-client-11.2
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# This section is borrowed from the official Django image but adds GDAL and others
RUN apt-get update && apt-get install -y \
        gcc zip gettext geoip-bin cron \
        postgresql-client-11 libpq-dev \
        sqlite3 spatialite-bin libsqlite3-mod-spatialite \
        python3-gdal python3-psycopg2 python3-ldap \
        python3-pil python3-lxml python3-pylibmc \
        python3-dev libgdal-dev \
        libxml2 libxml2-dev libxslt1-dev zlib1g-dev libjpeg-dev \
        libmemcached-dev libsasl2-dev \
        libldap2-dev libsasl2-dev \
        uwsgi uwsgi-plugin-python3 \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# add bower and grunt command
COPY . /usr/src/app/
WORKDIR /usr/src/app

COPY monitoring-cron /etc/cron.d/monitoring-cron
RUN chmod 0644 /etc/cron.d/monitoring-cron
RUN crontab /etc/cron.d/monitoring-cron
RUN touch /var/log/cron.log
RUN service cron start

COPY wait-for-databases.sh /usr/bin/wait-for-databases
RUN chmod +x /usr/bin/wait-for-databases
RUN chmod +x /usr/src/app/tasks.py \
    && chmod +x /usr/src/app/entrypoint.sh

# Prepraing dependencies
RUN apt-get update && apt-get install -y devscripts build-essential debhelper pkg-kde-tools sharutils
RUN git clone https://salsa.debian.org/debian-gis-team/proj.git /tmp/proj
RUN cd /tmp/proj && debuild -i -us -uc -b && dpkg -i ../*.deb

# Install pip packages
RUN pip install pip --upgrade
RUN pip install --upgrade --no-cache-dir --src /usr/src -r requirements.txt \
    && pip install pygdal==$(gdal-config --version).* \
    && pip install flower==0.9.4

# Install "geonode-contribs" apps
RUN cd /usr/src; git clone https://github.com/GeoNode/geonode-contribs.git -b master
# Install logstash and centralized dashboard dependencies
RUN cd /usr/src/geonode-contribs/geonode-logstash; pip install --upgrade -e . \
	cd /usr/src/geonode-contribs/ldap; pip install --upgrade -e .

EXPOSE 8000

ENTRYPOINT service cron restart && /usr/src/app/entrypoint.sh
CMD ["uwsgi", "--ini", "/usr/src/app/uwsgi.ini"]
