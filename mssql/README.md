# MSSQL Installation
The scripts provided in this directory can be used to install [MSSQL](https://www.microsoft.com/en-us/sql-server) using `bash`.

## [`install.sh`](install.sh)
The following should be executed prior to running `install.sh`:

```sh
# required for mssql-tools (uses ODBC)
sudo apt-get install unixodbc unixodbc-dev
```

The following actions will be performed when running `install.sh`:

1. Any existing MSSQL installations will be removed.
1. A fresh installation of MSSQL will be performed using the environmental variables: `MSSQL_VER` and `MSSQL_SA_PWD`.
1. A database will be created using the environmental variable: `MSSSQL_UID`. When `MSSQL_UID=sa`, the script will end. When `MSSQL_DB=master`, the attempt to create the database will be skipped.
1. The current user will be created within MSSQL using the password outlined environmental variable: `MSSQL_PWD`.
1. The current user will be become the owner of the database defined by `MSSQL_DB` unless `MSSQL_DB=master`, in which case the current user will be granted all access to `master`.

The following environmental variables can be set to control the installation:

1. `MSSQL_VER` (required) - The version of MSSQL that will be installed (e.g. _2019_)
1. `MSSQL_SA_PWD` (required) - The password for the MSSQL administrative account (__sa__ account)
1. `MSSQL_UID` (optional, defaults to the current OS user account) - The _username_ that will be used when creating the MSSQL user
1. `MSSQL_PWD` (optional, defaults to the value from __MSSQL_UID__ followed by ___M33QL__) - The _password_ that will be set on the MSSQL user
1. `MSSQL_DB` (optional, defaults to the value from __MSSQL_UID__) - The name of the _database_ to create that the __MSSQL_UID__ will be granted all access to ()

### Usage
A simple inline script can be used to download and execute the installation scripts:

```sh
# set the environmental variable that determines the _tagged_ release version of the installation scripts
export REPO_VER=<THIS_REPO_TAG_VER_HERE>
export MSSQL_VER=<MSSQL_VER_HERE>

# download the installation script
wget -O install-mssql.sh https://raw.githubusercontent.com/ugate/repo/$REPO_VER/MSSQL/install.sh
# execute the installation script
bash ./install-mssql.sh
# remove the installation script (may be required when working within a repository directory)
rm -rf install-mssql.sh
```

## ODBC
ODBC drivers are automatically installed when MSSQL is installed. In order to add a data source using the `install.sh` script, simply set the following environmental variables prior to execution:

1. `MSSQL_ODBC_DATASOURCE` (required when setting an ODBC data source) - The name to use for the MSSQL ODBC data source

The data source will be to appened to `odbc.ini` using the following values:

1. `Driver` - Extracted from the installed MSSQL ODBC driver
1. `Description` - _MSSQL Connector/ODBC_
1. `Server` - _127.0.0.1_
1. `Database` - The value from __MSSQL_DB__
1. `UID` - The value from __MSSQL_UID__
1. `PWD` - The value from __MSSQL_PWD__