#!/bin/bash
set -e

# ------------------- PostgreSQL -------------------

if [[ -z "${POSTGRESQL_MAJOR}" ]]; then
  echo "[ERROR]: Environmental variable POSTGRESQL_MAJOR is required when installing PostgreSQL"
  exit 1
fi

echo "Uninstalling previous versions of PostgreSQL..."
{
  # uninstall any existing postgresql versions
  sudo apt-get --purge remove postgresql\*
} || {
  echo "No PostgreSQL uninstall required"
}

PGSQL_VER="$POSTGRESQL_MAJOR"

echo "Installing PostgreSQL $PGSQL_VER"

# install postgresql
sudo apt-get install postgresql-$POSTGRESQL_MAJOR

# capture the contents of pg_hba.conf
HBA_PTH=`sudo su - postgres -c "psql -t -P format=unaligned -c \"show hba_file\""`

# install auto creates postgres user (default install: --auth-local peer --auth-host scram-sha-256)
# use the current unix user as the postgresql superuser unless it is already set or is postgres
P_UID=`[[ -n "$POSTGRESQL_UID" ]] && echo $POSTGRESQL_UID || echo "$(whoami)"`
P_PWD=`[[ -n "$POSTGRESQL_PWD" ]] && echo $POSTGRESQL_PWD || echo $P_UID`
P_MTD=`[[ -n "$POSTGRESQL_AUTH_METHOD" ]] && echo $POSTGRESQL_AUTH_METHOD || echo "md5"`
if [[ "${P_UID}" != "postgres" && "${P_MTD}" != "peer" ]]; then
  echo "Creating PostgreSQL user/role $P_UID (grant all on ${P_UID} DB)"
  # using postgres cli, create default DB for user
  sudo su - postgres -c "createdb ${P_UID}"
  # permission denied using the following:
  #sudo -u postgres psql -c "CREATE ROLE ${P_UID} WITH LOGIN SUPERUSER"
  #sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO ${P_UID}"
  sudo su - postgres -c "psql -c \"CREATE ROLE ${P_UID} WITH LOGIN SUPERUSER PASSWORD '{$P_PWD}'\""
  sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${P_UID} TO ${P_UID}\""

  # allow password auth for local access
  sudo sed "s/local[[:space:]]*all[[:space:]]*all[[:space:]]*peer/local   all             ${P_UID}             127.0.0.1\/32          ${P_MTD}\nlocal   all             ${P_UID}             ::1\/128               ${P_MTD}/gi" $HBA_PTH
  #echo "local   all             ${P_UID}             127.0.0.1/32       ${P_MTD}" | sudo tee -a $HBA_PTH
  #echo "local   all             ${P_UID}             ::1/128            ${P_MTD}" | sudo tee -a $HBA_PTH

  # reload the altered pg_hba.conf
  sudo su - postgres -c "psql -c \"SELECT pg_reload_conf()\""
fi

echo "PostgreSQL auth-emthod set to: ${P_MTD}"

# print the contents of pg_hba.conf
sudo cat $HBA_PTH

# test connection
sudo su - postgres -c "psql -d \"postgresql://${P_UID}:${P_PWD}@localhost/${P_UID}\" -c \"SELECT now()\""

echo "Installed PostgreSQL $PGSQL_VER (accessible via sueruser: ${P_UID}, auth-method: ${P_MTD}, database: ${P_UID})"