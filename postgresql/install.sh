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

# install auto creates postgres user (default install: --auth-local peer --auth-host scram-sha-256)
# use the current unix user as the postgresql superuser unless it is already set or is postgres
P_UID=`[[ -n "$POSTGRESQL_UID" ]] && echo $POSTGRESQL_UID || echo "$(whoami)"`
P_PWD=`[[ -n "$POSTGRESQL_PWD" ]] && echo $POSTGRESQL_PWD || echo $P_UID`
if [[ "${P_UID}" != "postgres" ]]; then
  echo "Creating PostgreSQL user/role $P_UID (grant all on ${P_UID} DB)"
  # using postgres cli, create default DB for user
  sudo su - postgres -c "createdb ${P_UID}"
  # permission denied using the following:
  #sudo -u postgres psql -c "CREATE ROLE ${P_UID} WITH LOGIN SUPERUSER"
  #sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO ${P_UID}"
  sudo su - postgres -c "psql -c \"CREATE ROLE ${P_UID} WITH LOGIN SUPERUSER PASSWORD '{$P_PWD}'\""
  sudo su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${P_UID} TO ${P_UID}\""
fi

# print the contents of pg_hba.conf
HBA_PTH=`sudo su - postgres -c "psql -t -P format=unaligned -c \"show hba_file\""`
cat $HBA_PTH

echo "Installed PostgreSQL $PGSQL_VER (accessible via sueruser: ${P_UID}, database: ${P_UID})"