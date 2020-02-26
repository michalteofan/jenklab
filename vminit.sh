#!/bin/bash

EXPECTED_ARGS=5

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` <DBROOTPASSWD> <DBNAME> <DBUSER> <DBPASSWORD> <SQLFILE>"
  exit 1
fi

DBROOTPASSWD=$1
DBNAME=$2
DBUSER=$3
DBPASSWORD=$4
SQLFILE=$5

timestamp()
{
 date "+%Y-%m-%d--%H-%M-%S"
}

LOGFILE=/var/cloudlog/$(timestamp)-init.log
LOGDIR=/var/cloudlog

mkdir -p $LOGDIR
echo > $LOGFILE
sed -i 's/10.10.22.4/10.110.22.4/g' /etc/yum.repos.d/r7ppc64le.repo

echo "$(timestamp) ---------- Starting DB Install ----------" >> $LOGFILE
yum -y install mariadb mariadb-server
touch /var/log/mariadb/mariadb.log
chown mysql.mysql /var/log/mariadb/mariadb.log
systemctl enable mariadb.service
systemctl start mariadb.service
mysqladmin -u root password $DBROOTPASSWD
echo "$(timestamp) ---------- Finished DB Install ----------" >> $LOGFILE

echo "$(timestamp) --------------- Creating DB -------------" >> $LOGFILE
cat << EOF | mysql -u root --password=$DBROOTPASSWD
CREATE DATABASE $DBNAME;
GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSER'@'%'
IDENTIFIED BY '$DBPASSWORD';
FLUSH PRIVILEGES;
EXIT
EOF
mysql -u root --password=$DBROOTPASSWD -e "show databases;" >> $LOGFILE
echo "$(timestamp) --------------- DB Created -------------" >> $LOGFILE
