# mysql_master_slave

## Purpose
support perconal server 5.7 and GTID replica 


## Example
### Master
```Bash
docker run -i -t --rm --privileged -n --memory="4294967296" -h mysql_master -v /srv/mcluster -v /data/mcluster_data/mysql_master:/data/mcluster_data \
--env "IP=10.183.82.100" \
--env "HOSTNAME=mysql_master" \
--env "NETMASK=255.255.0.0" \
--env "GATEWAY=10.183.0.1" \
--env "REPLICATION_MASTER=true" \
--env "REPLICATION_USER=rep" \
--env "REPLICATION_PASS=rep" \
--env "MONITOR_PASSWORD=P12PWtSa" \
--env "REPLICA_METHOD=gtid" \
--env "KP_ROUTER_ID=mysql_master_slave" \
--env "PRIORITY=100" \
--env "WEIGHT=3" \
--env "VIRTUUAL_ROUTER_ID=59" \
--env "VIP=10.183.82.102" \
--name mysql_master dockerapp.et.letv.com/mcluster/letv_mysql_master_slave:0.0.2
```

### Slave
```Bash
docker run -i -t --rm --privileged -n --memory="4294967296" -h mysql_slave -v /srv/mcluster -v /data/mcluster_data/mysql_slave:/data/mcluster_data \
--env "IP=10.183.82.101" \
--env "HOSTNAME=mysql_slave" \
--env "NETMASK=255.255.0.0" \
--env "GATEWAY=10.183.0.1" \
--env "REPLICATION_SLAVE=true" \
--env "MASTER_PORT_3306_TCP_ADDR=10.183.82.100" \
--env "MASTER_PORT_3306_TCP_PORT=3306" \
--env "MASTER_ENV_REPLICATION_USER=rep" \
--env "MASTER_ENV_REPLICATION_PASS=rep" \
--env "MONITOR_PASSWORD=P12PWtSa" \
--env "REPLICA_METHOD=gtid" \
--env "KP_ROUTER_ID=mysql_master_slave" \
--env "PRIORITY=98" \
--env "WEIGHT=2" \
--env "VIRTUUAL_ROUTER_ID=59" \
--env "VIP=10.183.82.102" \
--name mysql_slave dockerapp.et.letv.com/mcluster/letv_mysql_master_slave:0.0.2
```

## Other
SPECS文件里定为perconal server 5.6定rpmbuild文件，perconal server 5.7的只需要修过版本号和cmake命令即可
```Bash
cmake  \
-DCMAKE_INSTALL_PREFIX=/opt/letv/mysql \
-DMYSQL_DATADIR=/srv/mcluster/mysql \
-DSYSCONFDIR=/opt/letv/mysql/etc \
-DMYSQL_UNIX_ADDR=/var/lib/mysql/mysql.sock \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DWITH_EDITLINE=bundled \
-DENABLED_LOCAL_INFILE=1 \
-DMYSQL_TCP_PORT=3306 \
-DWITH_BOOST=/var/lib/boost \
-DENABLE_DOWNLOADS=1
```