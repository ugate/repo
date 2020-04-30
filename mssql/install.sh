#!/bin/bash
set -e

# ------------------- MSSQL -------------------

if [[ -z "${MSSQL_VER}" || -z "${MSSQL_SA_PWD}" ]]; then
  echo "[ERROR]: Environmental variables MSSQL_VER and MSSQL_SA_PWD are required when installing MSSQL"
  exit 1
fi

echo "Uninstalling previous versions of MSSQL..."

# uninstall any existing MSSQL installations
command -v "sudo systemctl stop mssql-server --no-pager" >/dev/null 2>&1 || echo "No MSSQL service running"
command -v "sudo systemctl disable mssql-server" >/dev/null 2>&1 || echo "No MSSQL service to disable"
sudo systemctl daemon-reload
sudo systemctl reset-failed
command -v "sudo apt-get remove --purge mssql-server mssql-tools -y" >/dev/null 2>&1 || echo "No MSSQL uninstall required"
sudo apt-get autoremove -y
sudo apt-get autoclean

# Ubuntu version needs to match the distibution being used
MSSQL_UBUNTU_VER=`lsb_release -sr`
MSSQL_UBUNTU_VER=`echo $MSSQL_UBUNTU_VER | sed -e 's/^[[:space:]]*//'`

echo "Installing MSSQL $MSSQL_VER"

# import the public repository GPG keys
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

echo "Adding MSSQL repository"

# register SQL Server repository
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/${MSSQL_UBUNTU_VER}/mssql-server-${MSSQL_VER}.list)"

echo "Installing MSSQL mssql-server"

# install MSSQL
sudo apt-get update
sudo apt-get install -y mssql-server

# configure developer edition of MSSQL, accept EULA license agreement and set the "sa" user password
sudo MSSQL_PID=Developer ACCEPT_EULA=Y MSSQL_SA_PASSWORD="${MSSQL_SA_PWD}" /opt/mssql/bin/mssql-conf -n setup

echo "Installing MSSQL Tools"

# register microsoft repository
curl https://packages.microsoft.com/config/ubuntu/${MSSQL_UBUNTU_VER}/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list

# install MSSQL tools (uses unixODBC to connect)
sudo apt-get update 
sudo env ACCEPT_EULA=Y apt-get install mssql-tools unixodbc-dev

# sqlcmd/bcp accessibility
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
# sqlcmd/bcp accessibility (for interactive/non-login sessions)
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

sudo ls /opt/mssql-tools/bin/sqlcmd*
sudo ln -sfn /opt/mssql-tools/bin/sqlcmd /usr/bin/sqlcmd

# test connection using ODBC
sqlcmd -S localhost -U sa -P "${MSSQL_SA_PWD}" -Q "SELECT 1"

# setup the user permissions to the 
P_UID=`[[ -n "$MSSQL_UID" ]] && echo $MSSQL_UID || echo "$(whoami)"`
P_PWD=`[[ -n "$MSSQL_PWD" ]] && echo $MSSQL_PWD || printf "%s%s" $P_UID "_M33QL"`
P_DBN=`[[ -n "$MSSQL_DB" ]] && echo $MSSQL_DB || echo ""`
if [[ "${P_UID}" != "sa" ]]; then
  P_DBN=`[[ -n "$P_DBN" ]] && echo $P_DBN || echo $P_UID`
  echo "Creating MSSQL database: ${P_DBN}"
  sqlcmd -S localhost -U sa -P $MSSQL_SA_PWD -Q "CREATE DATABASE ${P_DBN}"
  echo "Creating MSSQL login $P_UID with password authentication"
  sqlcmd -S localhost -U sa -P $MSSQL_SA_PWD -Q "USE ${P_DBN}; CREATE LOGIN ${P_UID} WITH PASSWORD = '${P_PWD}';"
  echo "Creating MSSQL user for login $P_UID on schema dbo"
  sqlcmd -S localhost -U sa -P $MSSQL_SA_PWD -Q "USE ${P_DBN}; CREATE USER ${P_UID} FOR LOGIN ${P_UID} WITH DEFAULT_SCHEMA = dbo;"
  echo "Granting MSSQL user $P_UID all permissions on ${P_DBN}"
  sqlcmd -S localhost -U sa -P $MSSQL_SA_PWD -Q "USE ${P_DBN}; GRANT ALL TO ${P_UID};"
  echo "Testing MSSQL connection for user $P_UID"
  sqlcmd -S localhost -U "${P_UID}" -P "${P_PWD}" -Q "SELECT 1"
else
  P_DBN=master
fi

# check the status
systemctl status mssql-server --no-pager

echo "Installed MSSQL $MSSQL_VER (accessible via user: ${P_UID}, database: ${P_DBN})"

# ODBC data source setup
if [[ -n "$MSSQL_ODBC_DATASOURCE" ]]; then
  echo "Creating MSSQL ODBC data source for: ${MSSQL_ODBC_DATASOURCE}"
  # validate/capture driver name
  MSSQL_DRIVER=`odbcinst -q -d`
  printf "Looking for MSSQL driver in: \n${MSSQL_DRIVER}\n"
  MSSQL_DRIVER=`odbcinst -q -d | sed -nre 's/\[(.*(SQL[[:space:]]Server)?)\]/\1/pi'`

  if [[ -z "${MSSQL_DRIVER}" ]]; then
    echo "[ERROR]: Unable to find SQL Server driver name"
    exit 1
  fi

  printf "Installed MSSQL ODBC driver:\n`odbcinst -q -d -n "${MSSQL_DRIVER}"`\n"
  printf "Installing MSSQL ODBC Data Source for driver [${MSSQL_DRIVER}]\n"

  printf "\n[${MSSQL_ODBC_DATASOURCE}]\n" > mssql-ds.txt
  printf "Driver=${MSSQL_DRIVER}\n" >> mssql-ds.txt
  printf "Description=MSSQL Connector/ODBC\n" >> mssql-ds.txt
  printf "Server=127.0.0.1\n" >> mssql-ds.txt
  printf "Database=${P_DBN}\n" >> mssql-ds.txt
  printf "UID=${P_UID}\n" >> mssql-ds.txt
  printf "PWD=${P_PWD}\n" >> mssql-ds.txt

  # install data source
  #sudo odbcinst -i -s -l -f mssql-ds.txt
  cat mssql-ds.txt | sudo tee -a /etc/odbc.ini
  rm -f mssql-ds.txt

  printf "Installed MSSQL ODBC Data Source ${MSSQL_ODBC_DATASOURCE} for driver [${MSSQL_DRIVER}]:\n`odbcinst -q -s -n "${MSSQL_ODBC_DATASOURCE}"`\n"

  # test ODBC connection
  printf "quit\r" | isql -v "${MSSQL_ODBC_DATASOURCE}" "${P_UID}" "${P_PWD}"

fi
