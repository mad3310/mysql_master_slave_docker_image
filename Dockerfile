FROM letv:centos6
MAINTAINER Qiang Gao <gaoqiang3@le.com>


# install kernel modules for keepalived
#RUN yum install kernel-2.6.32-926.504.30.3.letv.el6 -y

# install yum source
RUN rm -rf /etc/yum.repos.d/CentOS-Debuginfo.repo
RUN rm -rf /etc/yum.repos.d/CentOS-Media.repo
RUN rm -rf /etc/yum.repos.d/CentOS-Vault.repo
ADD ./init/letv-pkgs.repo /etc/yum.repos.d/letv-pkgs.repo
ADD ./init/add.repo /etc/yum.repos.d/add.repo
RUN chmod 755 /etc/yum.repos.d/letv-pkgs.repo
RUN chmod 755 /etc/yum.repos.d/add.repo
RUN yum clean all

# install yum
#RUN yum install -y perl-DBD-MySQL perl-DBI perl-IO-Socket-SSL.noarch socat nc libev  perl-DBD-MySQL perl-DBI numactl pwgen
RUN yum install pwgen -y
RUN yum install vim wget mail -y
RUN /usr/bin/wget --no-check-certificate  http://s3.lecloud.com/matrix/plugins/MySQL/percona-server-5.6.33-1.el6.x86_64.rpm
RUN yum localinstall percona-server-5.6.33-1.el6.x86_64.rpm -y

# install pt tools
RUN /usr/bin/wget --no-check-certificate https://10.154.29.92:443/v1/AUTH_gaoqiang3/oss/PXC56/percona-xtrabackup-24-2.4.3-1.el6.x86_64.rpm
RUN yum localinstall percona-xtrabackup-24-2.4.3-1.el6.x86_64.rpm -y
RUN /usr/bin/wget --no-check-certificate https://10.154.29.92:443/v1/AUTH_gaoqiang3/oss/PXC56/percona-toolkit-2.2.19-1.noarch.rpm
RUN yum localinstall percona-toolkit-2.2.19-1.noarch.rpm -y
RUN rm -rf percona-xtrabackup-24-2.4.3-1.el6.x86_64.rpm
RUN rm -rf percona-toolkit-2.2.19-1.noarch.rpm


# Add MySQL configuration
RUN mkdir -p /opt/letv/mysql/etc
COPY ./init/my.cnf /opt/letv/mysql/etc/my.cnf
COPY ./init/my.cnf /etc/my.cnf
RUN chmod 644 /etc/my.cnf

# Add MySQL scripts
# COPY import_sql.sh /import_sql.sh
RUN mkdir -p /usr/local/init
COPY ./init/mysql_docker_init.sh /usr/local/init/mysql_docker_init.sh
RUN chmod 755 /usr/local/init/mysql_docker_init.sh

# Add keepalived scripts
RUN yum install keepalived -y
COPY ./init/keepalived_init.sh /usr/local/init/keepalived_init.sh
RUN chmod 755 /usr/local/init/keepalived_init.sh

ENV MONITOR_USER=monitor \
    MYSQL_PASS=**Random** \
    ON_CREATE_MONITOR_DB=**False** \
    REPLICATION_MASTER=**False** \
    REPLICATION_SLAVE=**False** \
    REPLICATION_USER=rep \
    REPLICATION_PASS=rep

EXPOSE 3306 4567 4568 4569 2181 2888 3888
ENTRYPOINT /usr/local/init/mysql_docker_init.sh && /usr/local/init/keepalived_init.sh && /bin/bash
