#!/bin/sh -e

export ORA_VER="11.2.0"
export ORA_VER_EXP="$ORA_VER-1.0"

echo "Installer $ORA_REPO_VER"
echo "Installing Oracle XE version $ORA_VER"

wget -nv https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip.aa
wget -nv https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip.ab
wget -nv https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip.ac
wget -nv https://raw.githubusercontent.com/ugate/repo/$ORA_REPO_VER/oracle/oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip.ad
cat oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip.* > oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip

export ORACLE_FILE="oracle-xe-$ORA_VER_EXP.x86_64.rpm.zip"
export ORACLE_HOME="/u01/app/oracle/product/$ORA_VER/xe"
export ORACLE_SID=XE

# hostname needs to be present in hosts or oracle installation will fail
ping -c1 $(hostname) || echo 127.0.0.1 $(hostname) | sudo tee -a /etc/hosts

ORACLE_RPM="$(basename $ORACLE_FILE .zip)"

cd "$(dirname "$(readlink -f "$0")")"

dpkg -s bc libaio1 rpm unzip > /dev/null 2>&1 ||
  ( sudo apt-get -qq update && sudo apt-get --no-install-recommends -qq install bc libaio1 rpm unzip )

df -B1 /dev/shm | awk 'END { if ($1 != "shmfs" && $1 != "tmpfs" || $2 < 2147483648) exit 1 }' ||
  ( sudo rm -r /dev/shm && sudo mkdir /dev/shm && sudo mount -t tmpfs shmfs -o size=2G /dev/shm )

test -f /sbin/chkconfig ||
  ( echo '#!/bin/sh' | sudo tee /sbin/chkconfig > /dev/null && sudo chmod u+x /sbin/chkconfig )

test -d /var/lock/subsys || sudo mkdir /var/lock/subsys

unzip -j "$(basename $ORACLE_FILE)" "*/$ORACLE_RPM"
sudo rpm --install --nodeps --nopre "$ORACLE_RPM"

echo 'OS_AUTHENT_PREFIX=""' | sudo tee -a "$ORACLE_HOME/config/scripts/init.ora" > /dev/null
sudo usermod -aG dba $USER

( echo ; echo ; echo travis ; echo travis ; echo n ) | sudo AWK='/usr/bin/awk' /etc/init.d/oracle-xe configure

# cleanup install files
rm -rf oracle-xe-$ORA_VER_EXP.x86_64.rpm*