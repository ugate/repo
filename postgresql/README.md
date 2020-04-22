# PostgreSQL Installation
The scripts provided in this directory can be used to install [PostgreSQL](https://www.postgresql.org) using `bash`.

## [`install.sh`](install.sh)
The following actions will be performed when running `install.sh`:

1. Any existing PostgreSQL installations will be removed
1. A fresh installation of PostgreSQL will be performed using the version set in the env vars
1. A database will be created using the currently logged in username or the username set in the env vars as the database name (unless `POSTGRESQL_UID=postgres` or `POSTGRESQL_AUTH_METHOD=peer`, in which case the script will end)
1. The current user will be created as a [SUPERUSER](https://www.postgresql.org/docs/current/app-createuser.html) within PostgreSQL. __The password will be the same as the username.__
1. The current user will be granted all access to the newly created database that uses the username as the database name

The following environmental variables can be set to control the installation:

1. `POSTGRESQL_MAJOR` (required) - The _major_ version of PostgreSQL that will be installed
1. `POSTGRESQL_UID` (optional, defaults to the currently logged in username) - The _username_ that will be used when creating the database name and PostgreSQL user (ignored when __POSTGRESQL_AUTH_METHOD__ is __peer__)
1. `POSTGRESQL_PWD` (optional, defaults to the value in __POSTGRESQL_UID__) - The _password_ that will be set on the PostgreSQL user (ignored when __POSTGRESQL_AUTH_METHOD__ is __peer__)
1. `POSTGRESQL_AUTH_METHOD` (optional, defaults to _md5_) - The [_auth-method_](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html) used for the newly created user.

> __NOTE:__ When `POSTGRESQL_UID=postgres` or `POSTGRESQL_AUTH_METHOD=peer`, no database or user is created by the installation script and the [pg_hba.conf](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html) will remain unaltered.

### Usage
A simple inline script can be used to download and execute the installation scripts:

```sh
# set the environmental variable that determines the _tagged_ release version of the installation scripts
export REPO_VER=v1.2.0
export POSTGRESQL_MAJOR=<POSTGRESQL_VER_HERE>

# download the installation script
wget -O install-postgresql.sh https://raw.githubusercontent.com/ugate/repo/$REPO_VER/postgresql/install.sh
# execute the installation script
bash ./install-postgresql.sh
# remove the installation script (may be required when working within a repository directory)
rm -rf install-postgresql.sh
```

## [`install-odbc.sh`](install-odbc.sh)
There should be a compatible/prexisting PostgreSQL version/installation __before__ running the ODBC installation script. __[The PostgreSQL ODBC drivers](https://odbc.postgresql.org/) are typically prebundled/installed when PostgreSQL is installed.__ The following actions will be performed when running `install-odbc.sh`:

1. The preinstalled PostgreSQL ODBC driver version will be captured for use in setting up the ODBC data source (uses the _UNICODE_ driver/connector)
1. A temporary data source file is generated using parameters set in the env vars
1. The generated data source file is appended to `/etc/odbc.ini` and the temporary data source file is removed
1. The connection is established and tested using an `isql` command (the script will fail with a non-zero exit code when a connection cannot be established)

The following environmental variables can be set to control the ODBC installation:

1. `ODBCINST` (optional, defaults to _/etc/odbcinst.ini_) - The path to the [_odbcinst.ini_ file](http://www.unixodbc.org/odbcinst.html)
1. `POSTGRESQL_ODBC_DATASOURCE` (required) - The name to use for the PostgreSQL ODBC data source
1. `POSTGRESQL_ODBC_SERVER` (optional, defaults to a blank value) - The [_Server_ ODBC connection parameter](https://odbc.postgresql.org/) that will be used
1. `POSTGRESQL_ODBC_PORT` (optional, defaults to a blank value) - The [_Port_ ODBC connection parameter](https://odbc.postgresql.org/) that will be used
1. `POSTGRESQL_ODBC_DATABASE` (optional, defaults to a blank value) - The [_Database_ ODBC connection parameter](https://odbc.postgresql.org/) that will be used
1. `POSTGRESQL_ODBC_UID` (optional, defaults to the currently logged in OS username) - The [_UID_ ODBC connection parameter](https://odbc.postgresql.org/) that will be used
1. `POSTGRESQL_ODBC_PWD` (optional, defaults to a blank value) - The [_PWD_ ODBC connection parameter](https://odbc.postgresql.org/) that will be used

### Usage
A simple inline script can be used to download and execute the ODBC installation scripts:

```sh
# set the environmental variable that determines the _tagged_ release version of the installation scripts
export REPO_VER=v1.3.0

# ensure unixODBC is installed
sudo apt-get install unixodbc unixodbc-dev
# download the ODBC installation script
wget -O install-postgresql-odbc.sh https://raw.githubusercontent.com/ugate/repo/$REPO_VER/postgresql/install-odbc.sh
# execute the ODBC installation script
bash ./install-postgresql-odbc.sh
# remove the installation script (may be required when working within a repository directory)
rm -rf install-postgresql-odbc.sh
# print out the ODBC paths
odbcinst -j
# print out the installed ODBC drivers
odbcinst -q -d
# print out the installed ODBC data sources
odbcinst -q -s
```