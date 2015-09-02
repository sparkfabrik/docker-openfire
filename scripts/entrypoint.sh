#!/bin/bash
set -e

until mysqladmin -h$MYSQL_HOST -u$MYSQL_USER -P$MYSQL_PORT -p$MYSQL_PASS ping &>/dev/null; do
  echo -n "."; sleep 0.2
done

# Mysql command.
MYSQL_CONN="mysql -h$MYSQL_HOST -u$MYSQL_USER -P$MYSQL_PORT -p$MYSQL_PASS"
$($MYSQL_CONN -e exit)

# Check if app database exists and that contain the users and users_relationship table.
$MYSQL_CONN -e "CREATE DATABASE IF NOT EXISTS $MYSQL_APP_DATABASE ;" 2>/dev/null
$($MYSQL_CONN $MYSQL_APP_DATABASE < /dump_db_app_temporary_tables.sql) 2>/dev/null
mysql_import_status=`echo $?`
if [ $mysql_import_status -ne 0 ]; then
  echo 'Cannot import the application temporary tables dump file.'
  exit 1
fi

# Create and import database.
$MYSQL_CONN -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE ;" 2>/dev/null
mysql_create_status=`echo $?`
if [ $mysql_create_status -ne 0 ]; then
  echo 'ERROR: Cannot create the database.'
  exit 1
fi

# Import the database
sed "s/#REPLACE#/$MYSQL_APP_DATABASE/g" /bi_elitedom_openfire.template.sql > /tmp/bi_elitedom_openfire.sql
$($MYSQL_CONN $MYSQL_DATABASE < /tmp/bi_elitedom_openfire.sql) 2>/dev/null
mysql_import_status=`echo $?`
if [ $mysql_import_status -ne 0 ]; then
  echo 'Cannot import the standard dump file.'
  exit 1
fi

# Reconfigure openfire.
sed -Ei "s/#OF_CONF_DB_HOST#/$MYSQL_HOST/" /data/etc/openfire.xml && \
sed -Ei "s/#OF_CONF_DB_HOST#/$MYSQL_PORT/" /data/etc/openfire.xml && \
sed -Ei "s/#OF_CONF_DB_USER_REPLACE#/$MYSQL_USER/" /data/etc/openfire.xml && \
sed -Ei "s/#OF_CONF_DB_PASS_REPLACE#/$MYSQL_PASS/" /data/etc/openfire.xml && \
sed -Ei "s/#OF_CONF_DB_PORT#/$MYSQL_PORT/" /data/etc/openfire.xml && \
sed -Ei "s/#OF_CONF_DB_NAME#/$MYSQL_DATABASE/" /data/etc/openfire.xml

# create openfire data dir
mkdir -p ${OPENFIRE_DATA_DIR}
chmod -R 0755 ${OPENFIRE_DATA_DIR}
chown -R ${OPENFIRE_USER}:${OPENFIRE_USER} ${OPENFIRE_DATA_DIR}

# create openfire log dir
mkdir -p ${OPENFIRE_LOG_DIR}
chmod -R 0755 ${OPENFIRE_LOG_DIR}
chown -R ${OPENFIRE_USER}:${OPENFIRE_USER} ${OPENFIRE_LOG_DIR}

# migrate old directory structure
if [ -d ${OPENFIRE_DATA_DIR}/openfire ]; then
  mv ${OPENFIRE_DATA_DIR}/openfire/etc ${OPENFIRE_DATA_DIR}/etc
  mv ${OPENFIRE_DATA_DIR}/openfire/lib ${OPENFIRE_DATA_DIR}/lib
  rm -rf ${OPENFIRE_DATA_DIR}/openfire
fi

# populate default openfire configuration if it does not exist
if [ ! -d ${OPENFIRE_DATA_DIR}/etc ]; then
  mv /etc/openfire ${OPENFIRE_DATA_DIR}/etc
fi
rm -rf /etc/openfire
ln -sf ${OPENFIRE_DATA_DIR}/etc /etc/openfire

if [ ! -d ${OPENFIRE_DATA_DIR}/lib ]; then
  mv /var/lib/openfire ${OPENFIRE_DATA_DIR}/lib
fi
rm -rf /var/lib/openfire
ln -sf ${OPENFIRE_DATA_DIR}/lib /var/lib/openfire

# create version file
CURRENT_VERSION=
[[ -f ${OPENFIRE_DATA_DIR}/VERSION ]] && CURRENT_VERSION=$(cat ${OPENFIRE_DATA_DIR}/VERSION)
if [[ ${OPENFIRE_VERSION} != ${CURRENT_VERSION} ]]; then
  echo -n "${OPENFIRE_VERSION}" | sudo -HEu ${OPENFIRE_USER} tee ${OPENFIRE_DATA_DIR}/VERSION >/dev/null
fi

# allow arguments to be passed to openfire launch
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
fi

# default behaviour is to launch openfire
if [[ -z ${1} ]]; then
  exec start-stop-daemon --start --chuid ${OPENFIRE_USER}:${OPENFIRE_USER} --exec /usr/bin/java -- \
    -server \
    -DopenfireHome=/usr/share/openfire \
    -Dopenfire.lib.dir=/usr/share/openfire/lib \
    -classpath /usr/share/openfire/lib/startup.jar \
    -jar /usr/share/openfire/lib/startup.jar ${EXTRA_ARGS}
else
  exec "$@"
fi

