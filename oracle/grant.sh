#!/bin/sh -e

echo "Granting Oracle XE access to: $USER"

# connect as OS user as SYSDBA and grant permissions for ORA_REPO_USER
"$ORACLE_HOME/bin/sqlplus" -L -S / AS SYSDBA @grant.sql $USER

# set database users
DB_USERS=`"$ORACLE_HOME/bin/sqlplus" -L -S / AS SYSDBA <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT USERNAME FROM dba_users;
EXIT;
EOF`
if [ -z "$DB_USERS" ]; then
  echo "No users returned from database"
  exit 0
else
  echo $DB_USERS
fi