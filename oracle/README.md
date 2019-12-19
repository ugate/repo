### Testing with Oracle XE Database
Testing is conducted under a _lightweight_ version of the Oracle DB called [Oracle XE (Xpress Edition)](https://www.oracle.com/database/technologies/appdev/xe.html). Although there are newer versions of Oracle XE, the `11g` versions is much more compact in size and is used by the installation script for this purpose.

### Installation
In order to use the provided installer each person using the test suite must accept the [OTN License Agreement for Oracle Database Express Edition](https://www.oracle.com/downloads/licenses/database-11g-express-license.html).

#### Windows
The installation script is not intended for Windows users. However, the installation instructions provided by Oracle are fairly simple using their provided installer.

#### Linux
The resources that reside in the `oracle` repository are intended to host the test installation files for installing Oracle XE on Linux with a pre-installed C++ compiler (e.g. Xenial). Using the provided resources you are agreeing to the [OTN License Agreement for Oracle Database Express Edition](https://www.oracle.com/downloads/licenses/database-11g-express-license.html).

- `install.sh` - Installs Oracle XE
- `oracle-xe-###.rpm.zip.XXX` - The RPM installation files separated by consecutive parts for accessibility/file size purposes

Once the `install.sh` is ran Oracle XE should be accessible using the following:

- __Host:__ `localhost:1521`
- __Database:__ `XE`
- __Username:__ `travis`
- __Password:__ `travis`

For the __SYSDBA__ role access:

- __Host:__ `localhost:1521`
- __Database:__ `XE`
- __Username:__ `system`
- __Password:__ `travis`

#### Troubleshooting
In some older versions of Oracle XE you may run into an __ORA-12505__ when connecting to the DB due to `listener.ora` missing `SID_DESC` for __XE__. To resolve this issue ensure that `listener.ora` (under the Oracle XE install directory) contains something similar to the following:

```tns
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

__Once the above changes are made the `OracleXETNSListener` Windows service.__ The following comand should return the resolved changes made to the `listener.ora` using the TNSNAMES adapter:

```cmd
TNSPING XE
```


### Node.js + Travis-CI
[`travis-ci`](https://travis-ci.com/) integration will automatically install Oracle XE localy before CI testing using the following  `.travis.yml` snippet below. Special `env` values are automatically set for `oracledb` path resolution set when auto executing the provided [install.sh](https://raw.githubusercontent.com/ugate/repo/master/oracle/install.sh).

```yaml
sudo: required
# linux dist that includes C++ compiler needed for native node modules
dist: xenial
# paths required by the oracledb module
env:
  - ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe ORACLE_SID=XE OCI_LIB_DIR=/u01/app/oracle/product/11.2.0/xe/lib LD_LIBRARY_PATH=/u01/app/oracle/product/11.2.0/xe/lib
before_install:
  - wget https://raw.githubusercontent.com/ugate/repo/master/oracle/install.sh
  - bash ./install.sh
```