### Testing with Oracle XE Database
Contains a test installation script using a _lightweight_ version of the Oracle DB called [Oracle XE (Xpress Edition)](https://www.oracle.com/database/technologies/appdev/xe.html). Although there are newer versions of Oracle XE, the `11g` versions is much more compact in size and is used by the installation script for this purpose.

### Installation
In order to use the provided installer each person and/or organization using the test suite must accept the [OTN License Agreement for Oracle Database Express Edition](https://www.oracle.com/downloads/licenses/database-11g-express-license.html). __The following environmental variables must be set in order to run `install.sh`:__

- `ORA_REPO_VER` - The tagged `repo` version of the `install.sh` script to run
- `ORA_REPO_USER` - The user that will be granted acccess to the `XE` database

#### Windows
The installation script is not intended for Windows users. However, the [installation instructions provided by Oracle](https://www.oracle.com/database/technologies/appdev/xe/quickstart.html) are fairly simple using their provided installer. The following command can be executed to grant the current OS user access to the newly installed Oracle XE database (password will be the same as the username):

```sql
(echo CREATE USER %USERNAME% IDENTIFIED BY %USERNAME%; & echo GRANT CONNECT, RESOURCE TO %USERNAME%; & echo GRANT EXECUTE ON SYS.DBMS_LOCK TO %USERNAME%;) | sqlplus / AS SYSDBA
```

#### Linux
The resources that reside in the `oracle` repository are intended to host the test installation files for installing Oracle XE on Linux with a pre-installed C++ compiler (e.g. Xenial). Using the provided resources you are agreeing to the [OTN License Agreement for Oracle Database Express Edition](https://www.oracle.com/downloads/licenses/database-11g-express-license.html).

- `install.sh` - Installs Oracle XE
- `oracle-xe-###.rpm.zip.XXX` - The RPM installation files separated by consecutive parts for accessibility/file size purposes
- `grant.sh` - Grants database permissions to the current OS user (calls `grant.sql`) and outputs the current DB users
- `grant.sql` - Grants database permissions to a specified user (username is passed as first argument, password will be the same as the username)

Once the `install.sh` is ran Oracle XE should be accessible using the following (`$USER` will translate to the current OS user):

- __Host:__ `localhost:1521`
- __Database:__ `XE`
- __Username:__ `$USER`
- __Password:__ `$USER`

For the __SYSDBA__ role access:

- __Host:__ `localhost:1521`
- __Database:__ `XE`
- __Username:__ `system`
- __Password:__ `$USER`

#### Troubleshooting
In some older versions of Oracle XE you may run into an __ORA-12505__ when connecting to the DB due to `listener.ora` missing `SID_DESC` for __XE__. To resolve this issue ensure that `listener.ora` (under the Oracle XE install directory) contains something similar to the following:

```sql
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
       (SID_NAME = XE)
       (ORACLE_HOME = C:\oraclexe\app\oracle\product\11.2.0\server)
     )
    (SID_DESC =
      (SID_NAME = PLSExtProc)
      (ORACLE_HOME = C:\oraclexe\app\oracle\product\11.2.0\server)
      (PROGRAM = extproc)
    )
    (SID_DESC =
      (SID_NAME = CLRExtProc)
      (ORACLE_HOME = C:\oraclexe\app\oracle\product\11.2.0\server)
      (PROGRAM = extproc)
    )
  )
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1))
      (ADDRESS = (PROTOCOL = TCP)(HOST = 127.0.0.1)(PORT = 1521))
    )
  )
DEFAULT_SERVICE_LISTENER = (XE)
```

__Once the above changes are made the `OracleXETNSListener` Windows service must be restarted for the changes to take effect.__ The following comand should return the resolved changes made to the `listener.ora` using the TNSNAMES adapter:

```bash
TNSPING XE
```


### Node.js + Travis-CI<sub id="ci"></sub>
[`travis-ci`](https://travis-ci.com/) integration will automatically install Oracle XE localy before CI testing using the following  `.travis.yml` snippet below. Special `env` values are automatically set for `oracledb` path resolution set when auto executing the provided [install.sh](https://raw.githubusercontent.com/ugate/repo/master/oracle/install.sh). __Ensure `ORA_REPO_VER` is set to the desired install script version (tagged release in the repo).__

```yaml
sudo: required
# linux dist that includes C++ compiler needed for native node modules
dist: xenial
# paths required by the oracledb module
env:
  -  ORA_REPO_VER=v1.0.0 ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe ORACLE_SID=XE OCI_LIB_DIR=/u01/app/oracle/product/11.2.0/xe/lib LD_LIBRARY_PATH=/u01/app/oracle/product/11.2.0/xe/lib
before_install:
  - wget https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/install.sh
  - wget https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/grant.sh
  - wget https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/grant.sql
  - bash ./install.sh
  - bash ./grant.sh
```
