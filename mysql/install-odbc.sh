#!/bin/bash
set -e

# ------------------- MySQL ODBC Drivers (Ubuntu) -------------------

if [[ -z "${ODBCINST}" ]]; then
  echo "Setting ODBCINST=/etc/odbcinst.ini"
  export ODBCINST=/etc/odbcinst.ini
fi

if [[ -z "${MYSQL_ODBC_MAJOR}" || -z "${MYSQL_ODBC_MINOR}" || -z "${MYSQL_ODBC_PATCH}" || -z "${MYSQL_ODBC_DATASOURCE}" ]]; then
  echo "[ERROR]: Environmental variables MYSQL_ODBC_MAJOR, MYSQL_ODBC_MINOR, MYSQL_ODBC_PATCH and MYSQL_ODBC_DATASOURCE are required when installing MySQL ODBC Drivers"
  exit 1
fi

MYSQL_ODBC_VER="$MYSQL_ODBC_MAJOR.$MYSQL_ODBC_MINOR.$MYSQL_ODBC_PATCH"

# Ubuntu version needs to match the distibution being used
MYSQL_UBUNTU_VER=`lsb_release -sr`
MYSQL_UBUNTU_VER=`echo $MYSQL_UBUNTU_VER | sed -e 's/^[[:space:]]*//'`


MYSQL_ODBC_NAME="mysql-connector-odbc-$MYSQL_ODBC_VER-linux-ubuntu$MYSQL_UBUNTU_VER-x86-64bit"

echo "Installing MySQL ODBC driver $MYSQL_ODBC_VER"

# get and extract the driver
wget -O mysql-odbc.tar.gz -nv https://dev.mysql.com/get/Downloads/Connector-ODBC/$MYSQL_ODBC_MAJOR.$MYSQL_ODBC_MINOR/$MYSQL_ODBC_NAME.tar.gz
tar -xvf mysql-odbc.tar.gz
# copy the driver libs
sudo cp $MYSQL_ODBC_NAME/lib/libmyodbc$MYSQL_ODBC_MAJOR* /usr/lib/x86_64-linux-gnu/odbc/

MYSQL_ODBC_DRIVER="/usr/lib/x86_64-linux-gnu/odbc/libmyodbc${MYSQL_ODBC_MAJOR}w.so"
MYSQL_ODBC_DRIVER_FOUND=`[[ (-f "$MYSQL_ODBC_DRIVER") ]] && echo "Found: $MYSQL_ODBC_DRIVER" || echo "Cannot find: $MYSQL_ODBC_DRIVER"`
echo $MYSQL_ODBC_DRIVER_FOUND

# install the driver
MYSQL_ODBC_DRIVER_NAME="MySQL ODBC ${MYSQL_ODBC_MAJOR} Driver"
sudo $MYSQL_ODBC_NAME/bin/myodbc-installer -a -d -n "${MYSQL_ODBC_DRIVER_NAME}" -t "DRIVER=$MYSQL_ODBC_DRIVER;"

printf "Installed MySQL ODBC driver:\n`odbcinst -q -d -n "${MYSQL_ODBC_DRIVER_NAME}"`\n"
printf "Installing MySQL ODBC Data Source for driver [${MYSQL_ODBC_DRIVER_NAME}]\n"

# install the data source
P_SVR=`[[ -n "$MYSQL_ODBC_SERVER" ]] && echo $MYSQL_ODBC_SERVER || echo "127.0.0.1"`
P_DBN=`[[ -n "$MYSQL_ODBC_DATABASE" ]] && echo $MYSQL_ODBC_DATABASE || echo "mysql"`
P_UID=`[[ -n "$MYSQL_ODBC_UID" ]] && echo $MYSQL_ODBC_UID || echo "root"`
P_PWD=`[[ -n "$MYSQL_ODBC_PWD" ]] && echo $MYSQL_ODBC_PWD || echo ""`
P_DSN="DRIVER=${MYSQL_ODBC_DRIVER_NAME};SERVER=${P_SVR};DATABASE=${P_DBN};UID=${P_UID};PWD=${P_PWD}"

sudo $MYSQL_ODBC_NAME/bin/myodbc-installer -s -a -c2 -n "${MYSQL_ODBC_DATASOURCE}" -t "${P_DSN}"

# cleanup
rm -fr $MYSQL_ODBC_NAME
rm -f mysql-odbc.tar.gz

printf "Installed MySQL ODBC Data Source ${MYSQL_ODBC_DATASOURCE} for driver [${MYSQL_ODBC_DRIVER_NAME}]:\n`odbcinst -q -s -n "${MYSQL_ODBC_DATASOURCE}"`\n"

# test connection
printf "quit\r" | isql -v "${MYSQL_ODBC_DATASOURCE}" "${P_UID}" "${P_PWD}"