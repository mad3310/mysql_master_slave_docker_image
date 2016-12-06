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

