#!/bin/bash

##################################
######base environment set######## 
##################################

function checkvar(){
  if [ ! $2 ]; then
    echo ERROR: need  $1
    exit 1
  fi
}

IFACE=${IFACE:-pbond0}

checkvar IP $IP
checkvar NETMASK $NETMASK
checkvar GATEWAY $GATEWAY

#hosts
umount /etc/hosts
cat > /etc/hosts <<EOF
127.0.0.1 localhost
$IP     `hostname`
EOF
echo 'set host successfully'

#network
cat > /etc/sysconfig/network-scripts/ifcfg-$IFACE << EOF
DEVICE=$IFACE
ONBOOT=yes
BOOTPROTO=static
IPADDR=$IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
EOF
ifconfig $IFACE $IP/16
echo 'set network successfully'

#route
gateway=`echo $IP | cut -d. -f1,2`.0.1
route add default gw $gateway
route del -net 0.0.0.0 netmask 0.0.0.0 dev eth0


##################################
#####mysql environment set######## 
##################################

set -m
set -e

#public param
VOLUME_HOME="/srv/mcluster"
CONF_FILE="/opt/letv/mysql/etc/my.cnf"
LOG="/var/log/mysql.log"
INSTALL_DIR="/opt/letv/mysql"

# public set param
ON_CREATE_MONITOR_DB='monitor'
MONITOR_USER='monitor'

export PATH=.:/opt/letv/mysql/bin:$PATH;
echo $PATH

# master set param
#REPLICATION_MASTER='true'
#REPLICATION_USER='rep'
#REPLICATION_PASS='rep'

# slave set param
#REPLICATION_SLAVE='true'
#MASTER_PORT_3306_TCP_ADDR='10.185.81.103'
#MASTER_PORT_3306_TCP_PORT='3306'
#MASTER_ENV_REPLICATION_USER='rep'
#MASTER_ENV_REPLICATION_PASS='rep'

# replication method : default or gtid
#REPLICA_METHOD=default

# Set permission of config file
chmod 644 ${CONF_FILE}

StartMySQL ()
{
    /etc/init.d/mysql start > /dev/null 2>&1 &
    # Time out in 1 minute
    LOOP_LIMIT=60
    for (( i=0 ; ; i++ )); do
        if [ ${i} -eq ${LOOP_LIMIT} ]; then
            echo "Time out. Error log is shown as below:"
            tail -n100 ${LOG}
            exit 1
        fi
        echo "=> Waiting for confirmation of MySQL service startup, trying ${i}/${LOOP_LIMIT} ..."
        sleep 1
        mysql -uroot -e "status" > /dev/null 2>&1 && break
    done
}

CreateMySQLUser()
{
    echo "=> Creating MySQL monitor user ${MONITOR_USER} "
    mysql -uroot -e "CREATE USER '${MONITOR_USER}'@'%' IDENTIFIED BY '${MONITOR_PASSWORD}'"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON ${ON_CREATE_MONITOR_DB}.* TO ${MONITOR_USER}@'%' WITH GRANT OPTION"
    echo "=> Done!"
    echo "========================================================================"
    echo "You can now connect to this MySQL Server using:"
    echo ""
    echo "    mysql -u$MONITOR_USER -p$PASS -h<host> -P<port>"
    echo ""
    echo "Please remember to change the above password as soon as possible!"
    echo "MySQL user 'root' has no password but only allows local connections"
    echo "========================================================================"
}

CreateDumpuser()
{
     mysql -uroot -e "GRANT SELECT, LOCK TABLES , EVENT ON *.* TO 'dumpuser'@'`echo $IP | cut -d. -f1,2`.%.%'  IDENTIFIED BY '${MONITOR_PASSWORD}';" 
}

DropDumpuser()
{
     mysql -uroot -e "drop user 'dumpuser'@'`echo $IP | cut -d. -f1,2`.%.%';"
}

OnCreateDB()
{
    if [ "$ON_CREATE_MONITOR_DB" = "**False**" ]; then
        unset ON_CREATE_MONITOR_DB
    else
        echo "Creating MySQL database ${ON_CREATE_MONITOR_DB}"
        mysql -uroot -e "CREATE DATABASE IF NOT EXISTS ${ON_CREATE_MONITOR_DB};"
        echo "Database created!"
    fi
}

DumpData_default()
{
    if [ ! -f /srv/mcluster/dump_db_full.sql ]; then
        echo "=> dump master data"
        mysqldump --opt --single-transaction --master-data=1 --all-databases --set-gtid-purged=off --host=${MASTER_PORT_3306_TCP_ADDR} --port=3306 --user=dumpuser --password=${MONITOR_PASSWORD} >/srv/mcluster/dump_db_full.sql
    fi
}

DumpData_gtid()
{
    if [ ! -f /srv/mcluster/dump_db_full.sql ]; then
        echo "=> dump master data"
        mysqldump --all-databases --single-transaction --triggers --routines --events --host=${MASTER_PORT_3306_TCP_ADDR} --port=3306 --user=dumpuser --password=${MONITOR_PASSWORD} >/srv/mcluster/dump_db_full.sql
    fi
}

ImportSql()
{
    if [ ! -f /var/lib/mysql/is_initdb ]; then                                                                                                                                                                 
         echo "=> Initializing slave DB with"                                                                                                                                                                    
         echo '=> Importing SQL file /srv/mcluster/dump_db_full.sql'
         mysql -uroot < /srv/mcluster/dump_db_full.sql
         touch /var/lib/mysql/is_initdb                                                                                                                                                                          
    fi 
}

# Main
if [ "${REPLICATION_MASTER}" == "**False**" ]; then
    unset REPLICATION_MASTER
fi

if [ "${REPLICATION_SLAVE}" == "**False**" ]; then
    unset REPLICATION_SLAVE
fi

# Initialize empty data volume and create MySQL user
if [[ ! -d ${VOLUME_HOME}/mysql ]]; then
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME/mysql"
    echo "=> Installing MySQL ..."
    # mysql5.6
    #${INSTALL_DIR}/scripts/mysql_install_db --basedir=${INSTALL_DIR} --user=mysql --datadir=${VOLUME_HOME}/mysql || exit 1
    # mysql5.7
    mkdir -p ${VOLUME_HOME}/mysql
    chown -R mysql:mysql ${VOLUME_HOME}/mysql
echo "${INSTALL_DIR}/bin/mysqld --initialize-insecure --basedir=${INSTALL_DIR} --user=mysql --basedir=${INSTALL_DIR} --datadir=${VOLUME_HOME}/mysql "
    ${INSTALL_DIR}/bin/mysqld --initialize-insecure --basedir=${INSTALL_DIR} --user=mysql --basedir=${INSTALL_DIR} --datadir=${VOLUME_HOME}/mysql || exit 1
    touch /var/lib/mysql/.EMPTY_DB
    echo "=> Done!"
else
    echo "=> Using an existing volume of MySQL"
fi

# Set MySQL REPLICATION - MASTER
if [ -n "${REPLICATION_MASTER}" ]; then
    echo "=> Configuring MySQL replication as master (1/2) ..."
    if [ ! -f /replication_set.1 ]; then
        RAND="$(date +%s | rev | cut -c 1-2)$(echo ${RANDOM})"
        echo "=> Writting configuration file '${CONF_FILE}' with server-id=${RAND}"
        sed -i "s/^#server-id.*/server-id = ${RAND}/" ${CONF_FILE}
        sed -i "s/^#log-bin.*/log-bin = mysql-bin/" ${CONF_FILE}
        if [[ "${REPLICA_METHOD}" = 'gtid' ]]; then
            sed -i "s/^#gtid-mode.*/gtid-mode = on/" ${CONF_FILE}
            sed -i "s/^#enforce-gtid-consistency.*/enforce-gtid-consistency=true/" ${CONF_FILE}
            sed -i "s/^#log-slave-updates.*/log-slave-updates=true/" ${CONF_FILE}
        fi
        touch /replication_set.1
    else
        echo "=> MySQL replication master already configured, skip"
    fi
fi

# Set MySQL REPLICATION - SLAVE
if [ -n "${REPLICATION_SLAVE}" ]; then
    echo "=> Configuring MySQL replication as slave (1/2) ..."
    if [ -n "${MASTER_PORT_3306_TCP_ADDR}" ] && [ -n "${MASTER_PORT_3306_TCP_PORT}" ]; then
        if [ ! -f /replication_set.1 ]; then
            RAND="$(date +%s | rev | cut -c 1-2)$(echo ${RANDOM})"
            echo "=> Writting configuration file '${CONF_FILE}' with server-id=${RAND}"
            sed -i "s/^#server-id.*/server-id = ${RAND}/" ${CONF_FILE}
            sed -i "s/^#log-bin.*/log-bin = mysql-bin/" ${CONF_FILE}
            if [[ "${REPLICA_METHOD}" = 'gtid' ]]; then
                sed -i "s/^#gtid-mode.*/gtid-mode = on/" ${CONF_FILE}
                sed -i "s/^#enforce-gtid-consistency.*/enforce-gtid-consistency=true/" ${CONF_FILE}
                sed -i "s/^#log-slave-updates.*/log-slave-updates=true/" ${CONF_FILE}
            fi
            touch /replication_set.1
        else
            echo "=> MySQL replication slave already configured, skip"
        fi
    else
        echo "=> Cannot configure slave, please link it to another MySQL container with alias as 'mysql'"
        exit 1
    fi
fi


echo "=> Starting MySQL ..."
StartMySQL

# Create admin user and pre create database
if [ -f /var/lib/mysql/.EMPTY_DB ]; then
    echo "=> Creating admin user ..."
    OnCreateDB
    CreateMySQLUser
    rm /var/lib/mysql/.EMPTY_DB
fi

# Set MySQL REPLICATION - MASTER
if [ -n "${REPLICATION_MASTER}" ]; then
    echo "=> Configuring MySQL replication as master (2/2) ..."
    if [ ! -f /replication_set.2 ]; then
        echo "=> Creating user ${REPLICATION_USER}:${REPLICATION_PASS}"
        mysql -uroot -e "CREATE USER '${REPLICATION_USER}'@'%' IDENTIFIED BY '${REPLICATION_PASS}'"
        mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* TO '${REPLICATION_USER}'@'%'"
        #CreateDumpuser
        mysql -uroot -e "reset master"
        echo "=> Done!"
        touch /replication_set.2
    else
        echo "=> MySQL replication master already configured, skip"
    fi
fi

# Set MySQL REPLICATION - SLAVE
if [ -n "${REPLICATION_SLAVE}" ]; then
    echo "=> Configuring MySQL replication as slave (2/2) ..."
    if [ -n "${MASTER_PORT_3306_TCP_ADDR}" ] && [ -n "${MASTER_PORT_3306_TCP_PORT}" ]; then
        if [ ! -f /replication_set.2 ]; then
            # dump master data
            #if [[ "${REPLICA_METHOD}" = 'default' ]]; then
            #    DumpData_default                                                                                                                                                                                       
            #fi
            #if [[ "${REPLICA_METHOD}" = 'gtid' ]]; then
            #    DumpData_gtid
            #fi
            # reset master
            mysql -uroot -e 'reset master'
            # Import master data
            #ImportSql
            echo "=> Setting master connection info on slave"
            if [[ "${REPLICA_METHOD}" = 'default' ]]; then
                mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='${MASTER_PORT_3306_TCP_ADDR}',MASTER_USER='${MASTER_ENV_REPLICATION_USER}',MASTER_PASSWORD='${MASTER_ENV_REPLICATION_PASS}',MASTER_PORT=${MASTER_PORT_3306_TCP_PORT}, MASTER_CONNECT_RETRY=30"
            fi
            if [[ "${REPLICA_METHOD}" = 'gtid' ]]; then
                mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='${MASTER_PORT_3306_TCP_ADDR}',MASTER_USER='${MASTER_ENV_REPLICATION_USER}',MASTER_PASSWORD='${MASTER_ENV_REPLICATION_PASS}',MASTER_PORT=${MASTER_PORT_3306_TCP_PORT}, MASTER_AUTO_POSITION = 1"
            fi
            mysql -uroot -e "set global read_only=on"
            mysql -uroot -e "start slave"
            echo "=> Done!"
            touch /replication_set.2
        else
            echo "=> MySQL replication slave already configured, skip"
        fi
    else
        echo "=> Cannot configure slave, please link it to another MySQL container with alias as 'mysql'"
        exit 1
    fi
fi

source /etc/profile
#fg
