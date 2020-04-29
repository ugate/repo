# MSSQL Installation
The scripts provided in this directory can be used to install [MSSQL]((https://www.microsoft.com/en-us/sql-server) using `bash`.

## [`install.sh`](install.sh)
The following actions will be performed when running `install.sh`:

1. Any existing MSSQL installations will be removed
1. A fresh installation of MSSQL will be performed using the version set in the env vars
1. A database will be created using the currently logged in username or the username set in the env vars as the database name (unless `MSSQL_UID=sa`, in which case the script will end)
1. The current user will be created within MSSQL. __The password will be set to the current OS username followed by `_M33SQL`.__
1. The current user will be granted all access to the newly created database that uses the username as the database name

The following environmental variables can be set to control the installation:

1. `MSSQL_VER` (required) - The version of MSSQL that will be installed (e.g. _2019_)
1. `MSSQL_UID` (optional, defaults to the currently logged in username) - The _username_ that will be used when creating the database name and MSSQL user
1. `MSSQL_PWD` (optional, defaults to a blank value) - The _password_ that will be set on the MSSQL user
1. `MSSQL_DB` (required, defaults to the value from __MSSQL_UID__) - The name of the _database_ to create that the __MSSQL_UID__ will be granted all access to

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
ODBC drivers are automatically installed when MSSQL is installed. 