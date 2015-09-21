FROM sameersbn/openfire:3.9.3-4
MAINTAINER paolo.mainardi@sparkfabrik.com

RUN apt-get update \
 && apt-get install -y mysql-client \
 && rm -rf /var/lib/apt/lists/*

ENV MYSQL_HOST=mysql \
    MYSQL_USER=db_user \
    MYSQL_PASS=db_pass \
    MYSQL_DATABASE=db_of \
    MYSQL_PORT=3306 \
    MYSQL_APP_DATABASE=db_app \
    OPENFIRE_MAX_MEM=128 \
    DEBUG=0

# Openfire configurations.
COPY conf /data/etc

# Add openfire plugins from igniterealtime.
WORKDIR /usr/share/openfire/plugins
ADD http://www.igniterealtime.org/projects/openfire/plugins/dbaccess.jar /usr/share/openfire/plugins/dbaccess.jar
ADD http://www.igniterealtime.org/projects/openfire/plugins/presence.jar /usr/share/openfire/plugins/presence.jar
ADD http://www.igniterealtime.org/projects/openfire/plugins/search.jar /usr/share/openfire/plugins/search.jar
RUN unzip dbaccess.jar -d /usr/share/openfire/plugins/dbaccess && \
    unzip presence.jar -d /usr/share/openfire/plugins/presence && \
    unzip search.jar -d /usr/share/openfire/plugins/search

COPY scripts/entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

ENTRYPOINT ["/sbin/entrypoint.sh"]
