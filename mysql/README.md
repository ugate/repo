# MySQL Installation
The scripts provided in this directory can be used to install [MySQL](https://www.mysql.com) using `bash`.

## [`install.sh`](install.sh)
The following actions will be performed when running `install.sh`:

1. Any existing MySQL installations will be removed
1. A fresh installation of MySQL will be performed using the version set in the env vars
1. A database will be created using the currently logged in username or the username set in the env vars as the database name (unless the current user is `mysql`, in which case the script will end)
1. The current user will be created with access at `localhost` within MySQL. __The password will be set to blank.__
1. The current user will be granted all access to the newly created database that uses the username as the database name

The following environmental variables can be set to control the installation:

1. `MYSQL_MAJOR` (required) - The _major_ version of MySQL that will be installed
1. `MYSQL_MINOR` (required) - The _minor_ version of MySQL that will be installed
1. `MYSQL_PATCH` (required) - The _patch_ version of MySQL that will be installed
1. `MYSQL_UID` (optional, defaults to the currently logged in username) - The username that will be used when creating the database name and MySQL user

### Usage
A simple inline script can be used to download and execute the installation scripts:

```sh
# set the environmental variable that determines the _tagged_ release version of the installation scripts
export REPO_VER=v1.2.0
export MYSQL_MAJOR=<MYSQL_MAJOR_VER_HERE>
export MYSQL_MINOR=<MYSQL_MINOR_VER_HERE>
export MYSQL_PATCH=<MYSQL_PATCH_VER_HERE>

# download the installation script
wget -O install-MySQL.sh https://raw.githubusercontent.com/ugate/repo/$REPO_VER/MySQL/install.sh
# execute the installation script
bash ./install-MySQL.sh
# remove the installation script (may be required when working within a repository directory)
rm -rf install-MySQL.sh
```

## [`install-odbc.sh`](install-odbc.sh)
There should be a compatible/prexisting MySQL version/installation __before__ running the ODBC installation script. The following actions will be performed when running `install-odbc.sh`:

1. The [MySQL ODBC driver/connector](https://dev.mysql.com/doc/connector-odbc/en/) will be downloaded and installed using the version set in the env vars
1. Uses the `myodbc-installer` to install the ODBC data source

The following environmental variables can be set to control the ODBC installation:

1. `ODBCINST` (optional, defaults to _/etc/odbcinst.ini_) - The path to the [_odbcinst.ini_ file](http://www.unixodbc.org/odbcinst.html)
1. `MYSQL_ODBC_MAJOR` (required) - The _major_ version of [MySQL ODBC driver/connector](https://dev.mysql.com/doc/connector-odbc/en/) that will be installed
1. `MYSQL_ODBC_MINOR` (required) - The _minor_ version of [MySQL ODBC driver/connector](https://dev.mysql.com/doc/connector-odbc/en/) that will be installed
1. `MYSQL_ODBC_PATCH` (required) - The _patch_ version of [MySQL ODBC driver/connector](https://dev.mysql.com/doc/connector-odbc/en/) that will be installed
1. `MYSQL_ODBC_SERVER` (optional, defaults to _127.0.0.1_) - The [_SERVER_ ODBC connection parameter](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-configuration-connection-parameters.html) that will be used
1. `MYSQL_ODBC_DATABASE` (optional, defaults to _mysql_) - The [_DATABASE_ ODBC connection parameter](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-configuration-connection-parameters.html) that will be used
1. `MYSQL_ODBC_UID` (optional, defaults to _root_) - The [_UID_ ODBC connection parameter](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-configuration-connection-parameters.html) that will be used
1. `MYSQL_ODBC_PWD` (optional, defaults to a blank value) - The [_PWD_ ODBC connection parameter](https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-configuration-connection-parameters.html) that will be used

### Usage
A simple inline script can be used to download and execute the ODBC installation scripts:

```sh
# set the environmental variable that determines the _tagged_ release version of the installation scripts
export REPO_VER=v1.2.0

# ensure unixODBC is installed
sudo apt-get install unixodbc unixodbc-dev
# ensure unixODBC is installed
sudo apt-get install unixodbc unixodbc-dev
# download the ODBC installation script
wget -O install-mysql-odbc.sh https://raw.githubusercontent.com/ugate/repo/$REPO_VER/mysql/install-odbc.sh
# execute the ODBC installation script
bash ./install-mysql-odbc.sh
# remove the installation script (may be required when working within a repository directory)
rm -rf install-mysql-odbc.sh
# print out the ODBC paths
odbcinst -j
# print out the installed ODBC drivers
odbcinst -q -d
# print out the installed ODBC data sources
odbcinst -q -s
```