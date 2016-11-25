#/bin/bash

# keepalived param
#KP_ROUTER_ID=mysql_master_slave
#PRIORITY=100
#WEIGHT=3
#VIRTUUAL_ROUTER_ID=51
#VIP='192.168.1.102'


IPADD=`ifconfig pbond0|grep 'inet addr'|sed 's/^.*addr://g'|awk '{print $1}'`
MASK=`ifconfig pbond0|grep 'inet addr'|sed 's/^.*Mask://g'|awk '{print $1}' `

echo "=> set keepalived.conf"
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
   router_id  ${KP_ROUTER_ID}
}
vrrp_instance VI_1 {
    state BACKUP
    interface pbond0
    virtual_router_id ${VIRTUUAL_ROUTER_ID}
    priority ${PRIORITY}
    advert_int 1
    nopreempt
    authentication {
        auth_type PASS
        auth_pass 123123
    }
virtual_ipaddress {
    ${VIP}
    }
}
virtual_server ${VIP} 3316 {
    delay_loop 6
    lb_algo wrr
    lb_kind DR
    nat_mask ${MASK}
    persistence_timeout 50
    protocol TCP
 real_server ${IPADD} 3306 {
    weight ${WEIGHT}
    notify_down /usr/local/bin/stop_keepalived.sh
    TCP_CHECK {
        connect_timeout 10
        nb_get_retry 3
        connect_port 3306
        }
    }
}
EOF

cat /etc/keepalived/keepalived.conf

echo "=> set keepalived fail script"
cat > /usr/local/bin/stop_keepalived.sh << EOF
#!/bin/bash
/etc/init.d/keepalived stop
echo  "${KP_ROUTER_ID} keepalived is stop" | mail -s "${KP_ROUTER_ID} keepalived is stop" gaoqiang3@le.com
echo `date "+%Y:%m:%d %H:%M:%S"`"----keepalived is stop" >> /var/log/keepalived.log
EOF

echo "=> chmod keepalived fail script "
chmod 755 /usr/local/bin/stop_keepalived.sh

echo "=> start keepalived"
/etc/init.d/keepalived start

echo "=>  check keepalived status"
LOOP_LIMIT=60                                                                                                                                                                                                      
for (( i=0 ; ; i++ )); do                                                                                                                                                                                          
    if [ ${i} -eq ${LOOP_LIMIT} ]; then                                                                                                                                                                            
        echo "Time out. keepalived set is error"                                                                                                                                                              
        exit 1                                                                                                                                                                                                     
    fi                                                                                                                                                                                                             
    echo "=> Waiting for confirmation of keepalived service startup, trying ${i}/${LOOP_LIMIT} ..."                                                                                                                     
    sleep 1                                                                                                                                                                                                        
    KP_STATUS=`/etc/init.d/keepalived status|grep running|wc -l` 
#    IP_STATUS=`/sbin/ip addr|grep "${VIP}"|wc -l`
    if [[ ${KP_STATUS} -eq 1 ]] ;
    then
	echo "keepalived success!!" && break	
    fi
done  


